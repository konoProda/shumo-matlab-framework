function [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q2c(price_v, Lsc, PVsc, E_start, prm, use_bin)
%FUNC_BUILD_Q2C  装配问题二第三轮"7 日滚动 SAA 两阶段随机 MILP"标准型
%
%   第一阶段（情景无关）：当天计划购电 G^plan_{d,t} ≥ 0，对所有情景完全相同。
%   第二阶段（逐情景 ω）：当日与未来 R-1 天的物理变量，含
%       G^L, G^ch, PV^ch, C, D, E, V, H, W  （当日）
%       G^L, G^ch, PV^ch, C, D, E, V, H, W, G^plan,fut  （未来日，多一个临时计划变量）
%       u（充放电互斥，二值）
%   当日连接：  G^L + G^ch + W = G^plan_{d,t}
%   未来日连接：G^L + G^ch + W = G^plan,fut_{τ,t}
%   目标：      min  Σ_t π_t G^plan_{d,t} Δt                       ← 第一阶段，不除以 K
%                    + (1/K) Σ_ω [ Σ_t 5π_t H_{d,t} Δt
%                                  + Σ_{τ>d} Σ_t ( π_t G^plan,fut + 5π_t H ) Δt ]
%
%   情景物理约束（方案文档 §11）与问题一同构：负荷平衡、充电来源、光伏剩余、SOC 递推、
%   上下界、功率限制、充放电互斥；滚动起点 E^(ω)_{d,0} = E_start 对所有情景相同。
%
%   输入  price_v  T×1 电价（每天相同）元/kWh
%         Lsc      R×T×K 情景负荷 kW（第 3 维 = 情景；K=1 即确定性退化）
%         PVsc     R×T×K 情景光伏 kW
%         E_start  标量  当天 0:00 实际储电量 kWh
%         prm      参数结构体（T / dt / 效率 / 上下限 / P_max / kappa_em）
%         use_bin  逻辑  true = 含互斥二元变量（MILP）；false = 连续松弛（LP）
%   输出  intlinprog / linprog 标准型；aux 含分段索引、分流辅助量与情景数

T = prm.T;  dt = prm.dt;
R = size(Lsc, 1);  K = size(Lsc, 3);        % size 会丢尾随单例维，逐维取
assert(size(Lsc,2) == T && size(PVsc,1) == R && size(PVsc,2) == T && size(PVsc,3) == K, ...
       '情景数据维度不符：Lsc %s / PVsc %s / 期望 R=%d T=%d K=%d', ...
       mat2str(size(Lsc)), mat2str(size(PVsc)), R, T, K);
assert(K >= 1 && R >= 1, '情景数与视野天数须为正');

nDay = 10;          % 当日情景块：GL GC PVC C D E V H W U
nFut = 11;          % 未来日情景块：GL GC PVC C D E V H W GPF U
offB = struct('GL',0, 'GC',1, 'PVC',2, 'C',3, 'D',4, 'E',5, 'V',6, 'H',7, 'W',8, 'GPF',9, 'U',10);

n0   = T;                                    % 第一阶段列数
nPer = T * (nDay + max(R-1,0) * nFut);       % 每个情景的列数
n    = n0 + K * nPer;

%% 索引
aux = struct();
aux.T = T;  aux.R = R;  aux.K = K;
aux.iGP = (1:T).';
aux.blk = cell(K, max(R,1));                 % blk{w,j+1} = 该 (情景,日) 块的起始列偏移
aux.nDay = nDay;  aux.nFut = nFut;  aux.offB = offB;

c = n0;
for w = 1:K
    aux.blk{w,1} = c;   c = c + nDay*T;
    for j = 2:R
        aux.blk{w,j} = c;   c = c + nFut*T;
    end
end
assert(c == n, '列数分配与总列数不一致');

blkidx = @(w, j, name) aux.blk{w,j} + offB.(name)*T + (1:T).';
isFut  = @(j) j >= 2;                        % j=1 → 当天（用第一阶段）；j>=2 → 未来日

%% 情景分流辅助量（由该情景的负荷/光伏直接确定）
aux.PVL  = zeros(R, T, K);   aux.Lbar = zeros(R, T, K);   aux.PVbar = zeros(R, T, K);
for w = 1:K
    Lw = Lsc(:,:,w);  Pw = PVsc(:,:,w);
    aux.PVL(:,:,w)   = min(Pw, Lw);
    aux.Lbar(:,:,w)  = max(Lw - Pw, 0);
    aux.PVbar(:,:,w) = max(Pw - Lw, 0);
end

%% 目标函数
f = zeros(n, 1);
f(aux.iGP) = price_v(:) * dt;                                  % 第一阶段：完整计费
for w = 1:K
    f(blkidx(w,1,'H')) = (prm.kappa_em / K) * price_v(:) * dt;
    for j = 2:R
        f(blkidx(w,j,'GPF')) = (1 / K) * price_v(:) * dt;
        f(blkidx(w,j,'H'))   = (prm.kappa_em / K) * price_v(:) * dt;
    end
end

%% 上下界
lb = zeros(n, 1);
ub = inf(n, 1);
ub(aux.iGP) = 1e5;
for w = 1:K
    PVb = squeeze(aux.PVbar(:,:,w)).';        % T×R（列 j = 第 j 日）
    for j = 1:R
        ub(blkidx(w,j,'GL'))  = 1e5;
        ub(blkidx(w,j,'GC'))  = 1e5;
        ub(blkidx(w,j,'H'))   = 1e5;
        ub(blkidx(w,j,'W'))   = 1e5;
        ub(blkidx(w,j,'PVC')) = PVb(:, j);
        ub(blkidx(w,j,'V'))   = PVb(:, j);
        ub(blkidx(w,j,'C'))   = prm.P_max;
        ub(blkidx(w,j,'D'))   = prm.P_max;
        lb(blkidx(w,j,'E'))   = prm.E_min;
        ub(blkidx(w,j,'E'))   = prm.E_max;
        if isFut(j); ub(blkidx(w,j,'GPF')) = 1e5; end
    end
end

%% 等式约束：每个 (情景,日) 5 组（负荷平衡 / 充电来源 / 光伏剩余 / SOC 递推 / 计划连接）
nRowEq = K * R * 5 * T;
beq = zeros(nRowEq, 1);
I = zeros(0,1);  J = zeros(0,1);  S = zeros(0,1);
r0 = 0;

for w = 1:K
    for j = 1:R
        Lbar = aux.Lbar(:, :, w).';    Lb = Lbar(:, j);      % T×1
        PVb  = aux.PVbar(:,:, w).';    Pv = PVb(:, j);
        b0 = aux.blk{w,j};
        g  = @(name) b0 + offB.(name)*T + (1:T).';

        % (1) 负荷平衡 GL + D + H = Lbar
        r = r0 + (1:T).';  r0 = r0 + T;
        I = [I; r; r; r];  J = [J; g('GL'); g('D'); g('H')];
        S = [S; ones(T,1); ones(T,1); ones(T,1)];
        beq(r) = Lb;

        % (2) 充电来源 PVC + GC - C = 0
        r = r0 + (1:T).';  r0 = r0 + T;
        I = [I; r; r; r];  J = [J; g('PVC'); g('GC'); g('C')];
        S = [S; ones(T,1); ones(T,1); -ones(T,1)];

        % (3) 光伏剩余 PVC + V = PVbar
        r = r0 + (1:T).';  r0 = r0 + T;
        I = [I; r; r];  J = [J; g('PVC'); g('V')];
        S = [S; ones(T,1); ones(T,1)];
        beq(r) = Pv;

        % (4) SOC 递推：E_t - E_{t-1} - eta_c*dt*C_t + (dt/eta_d)*D_t = 0
        %     首槽的 E_0 取当日起点（j=1 为实际 SOC；j>=2 为同一情景前一日的末槽）
        r  = r0 + (1:T).';  r0 = r0 + T;
        r2 = r(2:end);
        gE = g('E');
        I = [I; r; r2; r; r];
        J = [J; gE; gE(2:end)-1; g('C'); g('D')];
        S = [S; ones(T,1); -ones(T-1,1); -prm.eta_ch*dt*ones(T,1); (dt/prm.eta_dis)*ones(T,1)];
        if j == 1
            beq(r(1)) = E_start;
        else
            I = [I; r(1)];  J = [J; aux.blk{w,j-1} + offB.E*T + T];  S = [S; -1];
        end

        % (5) 连接：GL + GC + W - GP = 0
        r = r0 + (1:T).';  r0 = r0 + T;
        I = [I; r; r; r; r];  J = [J; g('GL'); g('GC'); g('W')];
        S = [S; ones(T,1); ones(T,1); ones(T,1)];
        if isFut(j)
            J = [J; g('GPF')];
        else
            J = [J; aux.iGP];
        end
        S = [S; -ones(T,1)];
    end
end
assert(r0 == nRowEq, '等式行数分配不一致');
Aeq = sparse(I, J, S, nRowEq, n);

%% 不等式：充放电互斥（每个 (情景,日) 2T 行）
nRowA = K * R * 2 * T;
b = zeros(nRowA, 1);
if use_bin
    I2 = zeros(0,1);  J2 = zeros(0,1);  S2 = zeros(0,1);  r2 = 0;
    iU = zeros(K*R*T, 1);  k = 0;
    for w = 1:K
        for j = 1:R
            b0 = aux.blk{w,j};
            gC = b0 + offB.C*T + (1:T).';
            gD = b0 + offB.D*T + (1:T).';
            % 当天块只有 10 个变量（无临时计划变量），U 在末位；未来块 11 个，U 仍为末位
            if j == 1; offU = offB.U - 1; else; offU = offB.U; end
            gU = b0 + offU*T + (1:T).';
            rA = r2 + (1:T).';      r2 = r2 + T;
            rB = r2 + (1:T).';      r2 = r2 + T;
            I2 = [I2; rA; rA; rB; rB];                              %#ok<AGROW>
            J2 = [J2; gC; gU; gD; gU];                              %#ok<AGROW>
            S2 = [S2; ones(T,1); -prm.P_max*ones(T,1); ones(T,1); prm.P_max*ones(T,1)]; %#ok<AGROW>
            b(rB) = prm.P_max;
            k = k + 1;  iU((k-1)*T + (1:T)) = gU;
        end
    end
    A = sparse(I2, J2, S2, nRowA, n);
    intcon = iU;
    ub(intcon) = 1;
else
    A = sparse(nRowA, n);
    intcon = zeros(0, 1);
end

aux.b = b;

end
