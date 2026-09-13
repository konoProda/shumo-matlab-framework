function [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q3b( ...
        Pcur, Pfut, Lcur, PVcur, Lfut, PVfut, Pfix, sl, E_start, prm, use_bin)
%FUNC_BUILD_Q3B  装配"阶段 s 的两阶段 SAA-MILP"标准型（问题三第二版 / 问题四共用）
%
%   阶段 s 的视野 = 当天尚未执行时段（Tcur = 144 − sl 槽）+ 未来 nFut 个整日。
%   与问题二的差别只在"当天块变长"：当天块只有 Tcur 槽，未来日仍是 144 槽。
%
%   第一阶段（情景无关）——只决定当天尚未执行时段的正常购电承诺：
%       s = 0 ：A_{d,t}（即当天原始计划 P），目标里按 π^(ω)·A·Δt 计入计划成本
%       s > 0 ：A_{d,t} 与调整辅助量 Δ⁺/Δ⁻，结算按 π^(ω)·(P + 1.5Δ⁺ − 0.5Δ⁻)·Δt
%               其中 A − P = Δ⁺ − Δ⁻（裁决 B5），P 为当天 0:00 原计划（常数）
%   第二阶段（逐情景 ω）：当天的 G^L/G^ch/PV^ch/C/D/E/V/H/W 与未来日的同名变量 + 临时计划 GPF，
%       以及充放电互斥二元 U。
%
%   三项加固（建模侧订对批复，见 decisions_q4.md F8/F9）：
%     H-1 正常购电物理上界：A ≤ U_cur = max_ω L̄^{(ω)}_cur + P_max（当天四阶段冻结同一 U）；
%         未来日情景内计划 GPF ≤ L̄^{(ω)}_fut + P_max。替代原人工上界 1e5。
%         含义：正常购电最多用于"补负荷 + 最大充电功率"；W 仍保留以表示预测误差造成的已购未用。
%         价格为正时该上界恒不起作用（正价下 W 无利可图 ⇒ 最优解 W=0）。
%     H-2 调增/调减显式互斥：0 ≤ Δ⁺ ≤ M·z，0 ≤ Δ⁻ ≤ M·(1−z)，z∈{0,1}，M = U_cur（不用人工 Big-M）。
%         正价下原最优解本就取单边 ⇒ 不收紧最优值；负价下它使结算式严格等于 §19.3 的语义。
%         （问题三价格恒正，此项恒不起作用；问题四含负价情景，必须显式化。）
%
%   输入  Pcur   Tcur×K   当天各情景电价 元/kWh
%         Pfut   T×nFut×K 未来日各情景电价
%         Lcur/PVcur     Tcur×K   当天剩余时段的情景负荷 / 光伏 kW
%         Lfut/PVfut     T×nFut×K 未来日情景负荷 / 光伏
%         Pfix   T×1       当天 0:00 原计划（已锁定；s=0 时不参与）
%         sl     标量      当天已执行槽数（= 6×阶段小时数）
%         E_start 标量     阶段起点的真实储电量 kWh（裁决 C8）
%         prm    参数结构体
%         use_bin 逻辑     true = 含互斥二元（MILP）；false = 连续松弛（LP）
%   输出  intlinprog / linprog 标准型；aux 含分段索引与分流辅助量

T = prm.T;  dt = prm.dt;
Tcur = T - sl;
K = size(Lcur, 2);
nFut = size(Lfut, 2);
assert(sl >= 0 && sl < T && mod(sl, 6) == 0, '阶段偏移 sl 非法');
assert(size(Lcur,1) == Tcur && size(PVcur,1) == Tcur, '当天情景维度不符');
assert(size(Lfut,1) == T && size(PVfut,1) == T, '未来日情景维度不符');
assert(size(Lfut,3) == K && size(PVfut,3) == K, '未来日情景数与当天不一致');
assert(size(Pcur,1) == Tcur && size(Pcur,2) == K, '当天电价维度不符');
assert(size(Pfut,1) == T && size(Pfut,2) == nFut && size(Pfut,3) == K, '未来日电价维度不符');

nDay = 10;                                  % 当天块：GL GC PVC C D E V H W U
nFt  = 11;                                  % 未来日块：… + GPF（U 仍在末位）
% 偏移沿用问题二已验证的约定：GPF=9、U=10（服务 11 组的未来日块）。
% 当天块只有 10 组且没有 GPF，故其中 U 落在 offB.U−1 = 9——两块的 U 偏移不同，
% 分别用 offU_day 与 offB.U 取值，不可混用（混用会让 GPF 与 U 互换而静默出错）。
offB = struct('GL',0,'GC',1,'PVC',2,'C',3,'D',4,'E',5,'V',6,'H',7,'W',8,'GPF',9,'U',10);
offU_day = offB.U - 1;

hasAdj = sl > 0;                            % s=0 阶段没有调整（裁决：不设 Δ±，不留空变量）

%% 索引
aux = struct('T',T, 'Tcur',Tcur, 'K',K, 'nFut',nFut, 'sl',sl, ...
             'nDay',nDay, 'nFt',nFt, 'offB',offB, 'offU_day',offU_day, 'hasAdj',hasAdj);
% s=0 阶段没有调整，既不生成也不保留 Δ± 与 z（不留"占位但不用"的空变量：
% 空变量会白白增加 432 列与 144 个二元变量，拖慢最贵的 0:00 阶段）
aux.iA  = (1:Tcur).';
if hasAdj
    aux.iDP = Tcur + (1:Tcur).';
    aux.iDM = 2*Tcur + (1:Tcur).';
    aux.iZ  = 3*Tcur + (1:Tcur).';
    n0 = 4*Tcur;
else
    aux.iDP = zeros(0,1);  aux.iDM = zeros(0,1);  aux.iZ = zeros(0,1);
    n0 = Tcur;
end

% H-1 上界：当天（四阶段冻结同一 U）；未来日按情景各自定界
Lbar_cur = max(Lcur - PVcur, 0);   PVbar_cur = max(PVcur - Lcur, 0);
Lbar_fut = max(Lfut - PVfut, 0);   PVbar_fut = max(PVfut - Lfut, 0);
aux.U_cur = max(Lbar_cur, [], 2) + prm.P_max;
aux.Lbar_cur = Lbar_cur;  aux.PVbar_cur = PVbar_cur;
aux.Lbar_fut = Lbar_fut;  aux.PVbar_fut = PVbar_fut;

aux.blk = zeros(K, 1 + nFut);
c = n0;
for w = 1:K
    aux.blk(w,1) = c;  c = c + nDay*Tcur;
    for j = 1:nFut
        aux.blk(w,1+j) = c;  c = c + nFt*T;
    end
end
n = c;

%% 目标函数
f = zeros(n, 1);
if hasAdj
    % 当天尚未执行时段：结算 π(P + 1.5Δ⁺ − 0.5Δ⁻)Δt；其中 π·P·Δt 是常数项，求解时略去
    f(aux.iDP) = (1.5 / K) * sum(Pcur, 2) * dt;
    f(aux.iDM) = (-0.5 / K) * sum(Pcur, 2) * dt;
else
    % s=0：当天尚无调整，计划成本按情景电价计入（价格随机时该成本本身是情景相关的）
    f(aux.iA) = (1 / K) * sum(Pcur, 2) * dt;
end
for w = 1:K
    b0 = aux.blk(w,1);
    f(b0 + offB.H*Tcur + (1:Tcur).') = (prm.kappa_em / K) * Pcur(:,w) * dt;
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        f(bj + offB.GPF*T + (1:T).') = (1 / K) * Pfut(:,j,w) * dt;
        f(bj + offB.H  *T + (1:T).') = (prm.kappa_em / K) * Pfut(:,j,w) * dt;
    end
end

%% 上下界
lb = zeros(n, 1);   ub = inf(n, 1);
ub(aux.iA)  = aux.U_cur;                    % H-1
if hasAdj
    ub(aux.iDP) = aux.U_cur;                % 硬界；真正的单边性由 H-2 的 z 保证
    ub(aux.iDM) = aux.U_cur;
    ub(aux.iZ)  = 1;
end
for w = 1:K
    b0 = aux.blk(w,1);
    ub(b0 + offB.GL*Tcur+(1:Tcur).') = 1e5;
    ub(b0 + offB.GC*Tcur+(1:Tcur).') = 1e5;
    ub(b0 + offB.H *Tcur+(1:Tcur).') = 1e5;
    ub(b0 + offB.W *Tcur+(1:Tcur).') = 1e5;
    ub(b0 + offB.PVC*Tcur+(1:Tcur).') = PVbar_cur(:,w);
    ub(b0 + offB.V *Tcur+(1:Tcur).') = PVbar_cur(:,w);
    ub(b0 + offB.C *Tcur+(1:Tcur).') = prm.P_max;
    ub(b0 + offB.D *Tcur+(1:Tcur).') = prm.P_max;
    lb(b0 + offB.E *Tcur+(1:Tcur).') = prm.E_min;
    ub(b0 + offB.E *Tcur+(1:Tcur).') = prm.E_max;
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        ub(bj + offB.GL*T+(1:T).') = 1e5;
        ub(bj + offB.GC*T+(1:T).') = 1e5;
        ub(bj + offB.H *T+(1:T).') = 1e5;
        ub(bj + offB.W *T+(1:T).') = 1e5;
        ub(bj + offB.PVC*T+(1:T).') = PVbar_fut(:,j,w);
        ub(bj + offB.V *T+(1:T).') = PVbar_fut(:,j,w);
        ub(bj + offB.C *T+(1:T).') = prm.P_max;
        ub(bj + offB.D *T+(1:T).') = prm.P_max;
        lb(bj + offB.E *T+(1:T).') = prm.E_min;
        ub(bj + offB.E *T+(1:T).') = prm.E_max;
        ub(bj + offB.GPF*T+(1:T).') = Lbar_fut(:,j,w) + prm.P_max;   % H-1（未来日）
    end
end

%% 等式约束
% 行数按解析式预分配：RHS 为 0 的行不会被赋值，必须预分配，否则 beq 长不到应有长度
nRowEq = hasAdj*Tcur + K*(5*Tcur + nFut*5*T);
beq = zeros(nRowEq, 1);
I = zeros(0,1);  J = zeros(0,1);  S = zeros(0,1);
r0 = 0;

if hasAdj
    % ① 分解式 A − dP + dM = P_fix（即 A − P_fix = dP − dM）
    r  = r0 + (1:Tcur).';   r0 = r0 + Tcur;
    I=[I;r;r;r];  J=[J;aux.iA;aux.iDP;aux.iDM];
    S=[S;ones(Tcur,1);-ones(Tcur,1);ones(Tcur,1)];
    beq(r) = Pfix(sl+1:T);
end

for w = 1:K
    % ---- 当天尚未执行时段 ----
    b0 = aux.blk(w,1);
    g  = @(nm) b0 + offB.(nm)*Tcur + (1:Tcur).';
    r  = r0 + (1:Tcur).';   r0 = r0 + Tcur;                        % (1) 负荷平衡 GL+D+H = L̄
    I=[I;r;r;r];  J=[J;g('GL');g('D');g('H')];
    S=[S;ones(Tcur,1);ones(Tcur,1);ones(Tcur,1)];          beq(r) = Lbar_cur(:,w);
    r  = r0 + (1:Tcur).';   r0 = r0 + Tcur;                        % (2) 充电来源 PVC+GC−C = 0
    I=[I;r;r;r];  J=[J;g('PVC');g('GC');g('C')];
    S=[S;ones(Tcur,1);ones(Tcur,1);-ones(Tcur,1)];
    r  = r0 + (1:Tcur).';   r0 = r0 + Tcur;                        % (3) 光伏剩余 PVC+V = P̄V
    I=[I;r;r];  J=[J;g('PVC');g('V')];
    S=[S;ones(Tcur,1);ones(Tcur,1)];                       beq(r) = PVbar_cur(:,w);
    r  = r0 + (1:Tcur).';   r0 = r0 + Tcur;                        % (4) SOC 递推
    r2 = r(2:end);
    % −E_{t−1} 用"第 2..Tcur 槽的列号减 1"取到第 1..Tcur−1 槽。
    % 写成 gE(2:end) 长度同样对得上，但方程会退化成 E_t−E_t=0，静默作废储能递推。
    gE = g('E');
    I=[I;r;r2;r;r];  J=[J;gE;gE(2:end)-1;g('C');g('D')];
    S=[S;ones(Tcur,1);-ones(Tcur-1,1);-prm.eta_ch*dt*ones(Tcur,1);(dt/prm.eta_dis)*ones(Tcur,1)];
    beq(r(1)) = E_start;                                           % 阶段起点 = 真实储电量
    r  = r0 + (1:Tcur).';   r0 = r0 + Tcur;                        % (5) 计划守恒 GL+GC+W = A
    I=[I;r;r;r;r];  J=[J;g('GL');g('GC');g('W');aux.iA];
    S=[S;ones(Tcur,1);ones(Tcur,1);ones(Tcur,1);-ones(Tcur,1)];

    % ---- 未来日 ----
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        q  = @(nm) bj + offB.(nm)*T + (1:T).';
        r  = r0 + (1:T).';   r0 = r0 + T;
        I=[I;r;r;r];  J=[J;q('GL');q('D');q('H')];
        S=[S;ones(T,1);ones(T,1);ones(T,1)];               beq(r) = Lbar_fut(:,j,w);
        r  = r0 + (1:T).';   r0 = r0 + T;
        I=[I;r;r;r];  J=[J;q('PVC');q('GC');q('C')];
        S=[S;ones(T,1);ones(T,1);-ones(T,1)];
        r  = r0 + (1:T).';   r0 = r0 + T;
        I=[I;r;r];  J=[J;q('PVC');q('V')];
        S=[S;ones(T,1);ones(T,1)];                         beq(r) = PVbar_fut(:,j,w);
        r  = r0 + (1:T).';   r0 = r0 + T;
        r2 = r(2:end);
        qE = q('E');
        I=[I;r;r2;r;r];  J=[J;qE;qE(2:end)-1;q('C');q('D')];
        S=[S;ones(T,1);-ones(T-1,1);-prm.eta_ch*dt*ones(T,1);(dt/prm.eta_dis)*ones(T,1)];
        if j == 1
            I=[I;r(1)];  J=[J;aux.blk(w,1)+offB.E*Tcur+Tcur];  S=[S;-1];   % 接当天末槽
        else
            I=[I;r(1)];  J=[J;aux.blk(w,j)+offB.E*T+T];        S=[S;-1];   % blk(w,j) 即第 (j−1) 个未来日
        end
        r  = r0 + (1:T).';   r0 = r0 + T;
        I=[I;r;r;r;r];  J=[J;q('GL');q('GC');q('W');q('GPF')];
        S=[S;ones(T,1);ones(T,1);ones(T,1);-ones(T,1)];
    end
end
assert(r0 == nRowEq, '等式行数累计 %d 与解析式 %d 不符', r0, nRowEq);
assert(numel(I) == numel(J) && numel(J) == numel(S), 'I/J/S 长度不一致');
nzPerRow = accumarray(I, 1, [nRowEq 1]);
assert(all(nzPerRow > 0), '存在 %d 个全零等式行', nnz(nzPerRow == 0));
Aeq = sparse(I, J, S, nRowEq, n);

%% 不等式约束
nRowIn = K*(2*Tcur + nFut*2*T) + 2*Tcur*(hasAdj > 0);
b = zeros(nRowIn, 1);
I2 = zeros(0,1);  J2 = zeros(0,1);  S2 = zeros(0,1);  r2c = 0;
iU = zeros(0,1);
if use_bin
    for w = 1:K
        b0 = aux.blk(w,1);
        gC = b0 + offB.C*Tcur + (1:Tcur).';   gD = b0 + offB.D*Tcur + (1:Tcur).';
        gU = b0 + offU_day*Tcur + (1:Tcur).';                     % 当天块 U 在末位（第 10 组）
        rA = r2c + (1:Tcur).';  r2c = r2c + Tcur;
        rB = r2c + (1:Tcur).';  r2c = r2c + Tcur;
        I2=[I2;rA;rA;rB;rB];  J2=[J2;gC;gU;gD;gU];
        S2=[S2;ones(Tcur,1);-prm.P_max*ones(Tcur,1);ones(Tcur,1);prm.P_max*ones(Tcur,1)];
        b([rA;rB]) = [zeros(Tcur,1); prm.P_max*ones(Tcur,1)];
        iU = [iU; gU];
        for j = 1:nFut
            bj = aux.blk(w,1+j);
            gC2 = bj + offB.C*T + (1:T).';  gD2 = bj + offB.D*T + (1:T).';
            gU2 = bj + offB.U*T + (1:T).';
            rA = r2c + (1:T).';  r2c = r2c + T;
            rB = r2c + (1:T).';  r2c = r2c + T;
            I2=[I2;rA;rA;rB;rB];  J2=[J2;gC2;gU2;gD2;gU2];
            S2=[S2;ones(T,1);-prm.P_max*ones(T,1);ones(T,1);prm.P_max*ones(T,1)];
            b([rA;rB]) = [zeros(T,1); prm.P_max*ones(T,1)];
            iU = [iU; gU2];
        end
    end
    if hasAdj
        % H-2 调增/调减互斥：dP − U·z ≤ 0；dM + U·z ≤ U
        rA = r2c + (1:Tcur).';  r2c = r2c + Tcur;
        rB = r2c + (1:Tcur).';  r2c = r2c + Tcur;
        I2=[I2;rA;rA;rB;rB];  J2=[J2;aux.iDP;aux.iZ;aux.iDM;aux.iZ];
        S2=[S2;ones(Tcur,1);-aux.U_cur;ones(Tcur,1);aux.U_cur];
        b([rA;rB]) = [zeros(Tcur,1); aux.U_cur];
    end
    assert(r2c == nRowIn, '不等式行数累计 %d 与解析式 %d 不符', r2c, nRowIn);
    A = sparse(I2, J2, S2, nRowIn, n);
    intcon = [aux.iZ; iU];
    ub(intcon) = 1;
else
    A = sparse(nRowIn, n);
    intcon = zeros(0, 1);
end

aux.b = b;
aux.nRowEq = nRowEq;   aux.nRowIn = nRowIn;

end
