% probe_q3b_stage.m —— Q3b 阶段 s 变长日程块的装配可行性探针
%
%   开工前唯一的真结构性风险：问题二的行星块假定"当天也是 144 槽"，而问题三阶段 s>0 时
%   当天只剩 Tcur = 144 − 6s 个未执行槽（未来日仍是整 144 槽）。本探针用小规模
%   （Tcur=36 / 未来 2 天 / K=2）把这个变长装配跑通并逐条自检，确认无阻碍。
%
%   同时验证：H-1 物理上界、H-2 调增/调减互斥在**正价与负价**两种情形下都成立。
%
%   用法：matlab -batch "run('scripts/probe_q3b_stage.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
rng(7,'twister');

%% 规模设定（小规模：只验结构，不验性能）
T = prm.T;  sl = 108;  Tcur = T - sl;          % 18:00 阶段：当天剩 36 槽
nFut = 2;  K = 2;

%% 造情景数据（合理量级）
mk = @(n,k) struct('L', 3000 + 1500*rand(n,k), 'PV', 5000*rand(n,k));
cur = mk(Tcur, K);
fut = mk(nFut*T, K);                            % 拉平，后面按天切
Lsc_cur = cur.L;  PVsc_cur = cur.PV;
Lsc_fut = reshape(fut.L, [T, nFut, K]);         % nFut 天 × T 槽 × K
PVsc_fut = reshape(fut.PV, [T, nFut, K]);

%% 原计划 P（已锁定）与物理上界 U
P_fix = 2000*ones(T,1);
P_fix(1:sl) = 3000;                             % 已执行段的计划（仅用于常数项，不参与决策）
U_cur = max(max(cur.L - min(cur.L.*0+cur.PV, cur.L), [], 2));   % 占位，下面重算
Lbar_cur = max(cur.L - cur.PV, 0);              % Tcur×K
Lbar_fut = max(Lsc_fut - PVsc_fut, 0);          % T×nFut×K
U_cur = max(Lbar_cur, [], 2) + prm.P_max;       % Tcur×1（当天冻结的上界）

fprintf('规模：Tcur=%d  未来 %d 天  K=%d\n', Tcur, nFut, K);
fprintf('当天上界 U：最小 %.0f  最大 %.0f kW\n\n', min(U_cur), max(U_cur));

%% 两种价格情形各跑一次
for case_id = 1:2
    if case_id == 1
        pi_cur = ones(Tcur,1) * 0.7;  pi_fut = ones(T,1) * 0.7;      % 正价
        tag = '正价';
    else
        pi_cur = ones(Tcur,1) * 0.7;  pi_fut = ones(T,1) * 0.7;
        pi_cur(1:6) = -0.5;                                          % 负价（前 6 槽）
        tag = '负价（前 6 槽 −0.5）';
    end

    [x, Z, aux, exitflag, gap] = build_and_solve(pi_cur, pi_fut, Lsc_cur, PVsc_cur, ...
                                   Lsc_fut, PVsc_fut, P_fix, U_cur, sl, K, nFut, prm);

    % ---------------- 逐条自检 ----------------
    Tcur_ = Tcur;
    A  = x(aux.iA);  dP = x(aux.iDP);  dM = x(aux.iDM);  z = x(aux.iZ);
    chk = struct();
    chk.exitflag = exitflag;  chk.gap = gap;
    % ① 调增/调减分解式
    chk.dPdm = max(abs((A - P_fix(sl+1:end)) - (dP - dM)));
    % ② 互斥：dP·dM = 0 且不超过 M·z / M(1−z)
    chk.mutex   = max(dP .* dM);
    chk.mutexLU = max(max(dP - U_cur.*z), max(dM - U_cur.*(1-z)));
    % ③ z 的整数性
    chk.zint = max(abs(z - round(z)));
    % ④ 上界
    chk.Aub = max(A - U_cur);
    % ⑤ 逐情景物理
    vEq = 0; vIn = 0; vSOC = 0; vCD = 0; vLink = 0;
    for w = 1:K
        b0 = aux.blk(w,1);
        g = @(nm) b0 + aux.offB.(nm)*Tcur_ + (1:Tcur_).';
        GL = x(g('GL')); GC = x(g('GC')); PVC = x(g('PVC'));
        Cv = x(g('C'));  Dv = x(g('D'));  Ev = x(g('E'));
        Vv = x(g('V'));  Hv = x(g('H'));  Wv = x(g('W'));
        vLink = max(vLink, max(abs(GL + GC + Wv - A)));
        vEq   = max(vEq,   max(abs(GL + Dv + Hv - Lbar_cur(:,w))));
        vEq   = max(vEq,   max(abs(PVC + GC - Cv)));
        vEq   = max(vEq,   max(abs(PVC + Vv - max(PVsc_cur(:,w)-Lsc_cur(:,w),0))));
        vCD   = max(vCD,   max(Cv .* Dv));
        % SOC 递推（首槽用 E_start）
        e0 = prm.E_init;
        r = abs(Ev(1) - e0 - prm.eta_ch*prm.dt*Cv(1) + prm.dt/prm.eta_dis*Dv(1));
        if r > vSOC
            fprintf('    [校验] 情景%d 当天首槽 SOC 残差 %.4e：E1=%.1f C1=%.3f D1=%.3f\n', ...
                    w, r, Ev(1), Cv(1), Dv(1));
        end
        r = max(r, max(abs(Ev(2:end) - Ev(1:end-1) - prm.eta_ch*prm.dt*Cv(2:end) + ...
                        prm.dt/prm.eta_dis*Dv(2:end))));
        vSOC = max(vSOC, r);
        % 未来日
        for j = 1:nFut
            bj = aux.blk(w, 1+j);
            q = @(nm) bj + aux.offB.(nm)*T + (1:T).';
            GL2 = x(q('GL')); GC2 = x(q('GC')); PVC2 = x(q('PVC'));
            C2 = x(q('C')); D2 = x(q('D')); E2 = x(q('E')); V2 = x(q('V'));
            H2 = x(q('H')); W2 = x(q('W')); GPF = x(q('GPF'));
            vLink = max(vLink, max(abs(GL2 + GC2 + W2 - GPF)));
            vEq = max(vEq, max(abs(GL2 + D2 + H2 - Lbar_fut(:,j,w))));
            vEq = max(vEq, max(abs(PVC2 + GC2 - C2)));
            vEq = max(vEq, max(abs(PVC2 + V2 - max(PVsc_fut(:,j,w)-Lsc_fut(:,j,w),0))));
            vCD = max(vCD, max(C2 .* D2));
            prev = (j==1) * Ev(end) + (j>1) * 0;      % j=1 接当天末槽
            if j > 1; prev = x(aux.blk(w,j) + aux.offB.E*T + T); end
            rj = abs(E2(1) - prev - prm.eta_ch*prm.dt*C2(1) + prm.dt/prm.eta_dis*D2(1));
            if rj > vSOC
                fprintf('    [校验] 情景%d 未来第%d日 首槽 SOC 残差 %.4e：E(1)=%.1f prev=%.1f C=%.3f D=%.3f\n', ...
                        w, j, rj, E2(1), prev, C2(1), D2(1));
            end
            vSOC = max(vSOC, rj);
            vSOC = max(vSOC, max(abs(E2(2:end) - E2(1:end-1) - prm.eta_ch*prm.dt*C2(2:end) + ...
                            prm.dt/prm.eta_dis*D2(2:end))));
        end
    end
    chk.eq = vEq;  chk.SOC = vSOC;  chk.CD = vCD;  chk.link = vLink;

    fprintf('【%s】exitflag=%d  间隙=%.3e  目标 Z=%.4f\n', tag, chk.exitflag, chk.gap, Z);
    fprintf('  分解式残差 %.2e | 互斥 dP·dM %.2e | 互斥上界违反 %.2e | z 整数性 %.2e | A 越界 %.2e\n', ...
            chk.dPdm, chk.mutex, max(chk.mutexLU,0), chk.zint, max(chk.Aub,0));
    fprintf('  等式残差 %.2e | SOC 残差 %.2e | 充放互斥 %.2e | 计划守恒 %.2e\n', ...
            chk.eq, chk.SOC, chk.CD, chk.link);

    allok = chk.exitflag==1 && max([chk.dPdm chk.mutex max(chk.mutexLU,0) chk.zint ...
            max(chk.Aub,0) chk.eq chk.SOC chk.CD chk.link]) < 1e-7;
    fprintf('  → %s\n\n', ternary(allok, '✅ 全部通过', '❌ 有项未通过，需排查'));
end

fprintf('PROBE_Q3B_STAGE_DONE\n');

% ================================================================= 局部函数
function [x, Z, aux, exitflag, gap] = build_and_solve(pi_cur, pi_fut, Lsc_cur, PVsc_cur, ...
                                  Lsc_fut, PVsc_fut, P_fix, U_cur, sl, K, nFut, prm)
T = prm.T;  dt = prm.dt;  Tcur = T - sl;

% 分流辅助量
Lbar_cur = max(Lsc_cur - PVsc_cur, 0);
PVbar_cur = max(PVsc_cur - Lsc_cur, 0);
Lbar_fut = max(Lsc_fut - PVsc_fut, 0);
PVbar_fut = max(PVsc_fut - Lsc_fut, 0);

aux = struct();  aux.T = T;  aux.Tcur = Tcur;  aux.K = K;  aux.nFut = nFut;
aux.iA  = (1:Tcur).';
aux.iDP = Tcur + (1:Tcur).';
aux.iDM = 2*Tcur + (1:Tcur).';
aux.iZ  = 3*Tcur + (1:Tcur).';
n0 = 4*Tcur;

nDay = 10;  nFt = 11;
aux.offB = struct('GL',0,'GC',1,'PVC',2,'C',3,'D',4,'E',5,'V',6,'H',7,'W',8,'U',9,'GPF',10);
aux.blk = zeros(K, 1+nFut);
c = n0;
for w = 1:K
    aux.blk(w,1) = c;  c = c + nDay*Tcur;
    for j = 1:nFut
        aux.blk(w,1+j) = c;  c = c + nFt*T;
    end
end
n = c;

%% 目标：结算项（去常数 πP）+ 紧急购电 + 未来延续
f = zeros(n,1);
f(aux.iDP) = 1.5 * pi_cur * dt;
f(aux.iDM) = -0.5 * pi_cur * dt;
for w = 1:K
    b0 = aux.blk(w,1);
    f(b0 + aux.offB.H*Tcur + (1:Tcur).') = (prm.kappa_em/K) * pi_cur * dt;
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        f(bj + aux.offB.GPF*T + (1:T).') = (1/K) * pi_fut * dt;
        f(bj + aux.offB.H*T   + (1:T).') = (prm.kappa_em/K) * pi_fut * dt;
    end
end

%% 上下界（H-1 在此生效）
lb = zeros(n,1);  ub = inf(n,1);
ub(aux.iA)  = U_cur;
ub(aux.iDP) = 1e4;                       % 硬界，真正的界由 z 互斥给出
ub(aux.iDM) = 1e4;
ub(aux.iZ)  = 1;
for w = 1:K
    b0 = aux.blk(w,1);
    ub(b0 + aux.offB.GL*Tcur+(1:Tcur).') = 1e5;
    ub(b0 + aux.offB.GC*Tcur+(1:Tcur).') = 1e5;
    ub(b0 + aux.offB.H*Tcur +(1:Tcur).') = 1e5;
    ub(b0 + aux.offB.W*Tcur +(1:Tcur).') = 1e5;
    ub(b0 + aux.offB.PVC*Tcur+(1:Tcur).') = PVbar_cur(:,w);
    ub(b0 + aux.offB.V*Tcur +(1:Tcur).') = PVbar_cur(:,w);
    ub(b0 + aux.offB.C*Tcur +(1:Tcur).') = prm.P_max;
    ub(b0 + aux.offB.D*Tcur +(1:Tcur).') = prm.P_max;
    lb(b0 + aux.offB.E*Tcur +(1:Tcur).') = prm.E_min;
    ub(b0 + aux.offB.E*Tcur +(1:Tcur).') = prm.E_max;
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        ub(bj + aux.offB.GL*T+(1:T).') = 1e5;
        ub(bj + aux.offB.GC*T+(1:T).') = 1e5;
        ub(bj + aux.offB.H*T +(1:T).') = 1e5;
        ub(bj + aux.offB.W*T +(1:T).') = 1e5;
        ub(bj + aux.offB.PVC*T+(1:T).') = PVbar_fut(:,j,w);
        ub(bj + aux.offB.V*T +(1:T).') = PVbar_fut(:,j,w);
        ub(bj + aux.offB.C*T +(1:T).') = prm.P_max;
        ub(bj + aux.offB.D*T +(1:T).') = prm.P_max;
        lb(bj + aux.offB.E*T +(1:T).') = prm.E_min;
        ub(bj + aux.offB.E*T +(1:T).') = prm.E_max;
        ub(bj + aux.offB.GPF*T+(1:T).') = max(Lbar_fut(:,j,w),0) + prm.P_max;   % H-1 未来日界
    end
end

%% 等式
I=[]; J=[]; S=[];  r0=0;
% 行数按解析式预分配：分解式 Tcur + 每情景(当天 5 组×Tcur + 未来 nFut×5 组×T)
% （RHS 为 0 的行不会被赋值，故必须预分配，否则 beq 长不到应有的长度）
nRowEq = Tcur + K*(5*Tcur + nFut*5*T);
beq = zeros(nRowEq, 1);
% ① 分解式 A − dP + dM = P_fix（即 A − P_fix = dP − dM）
r = r0 + (1:Tcur).';  r0 = r0 + Tcur;
I=[I;r;r;r];  J=[J;aux.iA;aux.iDP;aux.iDM];  S=[S;ones(Tcur,1);-ones(Tcur,1);ones(Tcur,1)];
beq(r) = P_fix(sl+1:end);
% 逐情景
for w = 1:K
    % ---- 当天剩余段 ----
    b0 = aux.blk(w,1);
    g = @(nm) b0 + aux.offB.(nm)*Tcur + (1:Tcur).';
    r = r0 + (1:Tcur).';  r0 = r0 + Tcur;                       % 负荷平衡
    I=[I;r;r;r]; J=[J;g('GL');g('D');g('H')]; S=[S;ones(Tcur,1);ones(Tcur,1);ones(Tcur,1)];
    beq(r,1) = Lbar_cur(:,w);
    r = r0 + (1:Tcur).';  r0 = r0 + Tcur;                       % 充电来源
    I=[I;r;r;r]; J=[J;g('PVC');g('GC');g('C')]; S=[S;ones(Tcur,1);ones(Tcur,1);-ones(Tcur,1)];
    r = r0 + (1:Tcur).';  r0 = r0 + Tcur;                       % 光伏剩余
    I=[I;r;r]; J=[J;g('PVC');g('V')]; S=[S;ones(Tcur,1);ones(Tcur,1)];
    beq(r,1) = PVbar_cur(:,w);
    r = r0 + (1:Tcur).';  r0 = r0 + Tcur;                       % SOC 递推
    r2 = r(2:end);
    % E 列；−E_{t−1} 用"第 2..Tcur 槽的列号减 1"取到第 1..Tcur−1 槽
    % （写成 gE(2:end) 长度同样对得上，但会让方程退化成 E_t−E_t=0，静默作废储能递推）
    gE = g('E');
    I=[I;r;r2;r;r]; J=[J;gE;gE(2:end)-1;g('C');g('D')];
    S=[S;ones(Tcur,1);-ones(Tcur-1,1);-prm.eta_ch*dt*ones(Tcur,1);(dt/prm.eta_dis)*ones(Tcur,1)];
    beq(r(1),1) = prm.E_init;                                   % 阶段起点 = 真实储电量
    r = r0 + (1:Tcur).';  r0 = r0 + Tcur;                       % 计划守恒
    I=[I;r;r;r;r]; J=[J;g('GL');g('GC');g('W');aux.iA]; S=[S;ones(Tcur,1);ones(Tcur,1);ones(Tcur,1);-ones(Tcur,1)];
    % ---- 未来日 ----
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        q = @(nm) bj + aux.offB.(nm)*T + (1:T).';
        r = r0 + (1:T).';  r0 = r0 + T;
        I=[I;r;r;r]; J=[J;q('GL');q('D');q('H')]; S=[S;ones(T,1);ones(T,1);ones(T,1)];
        beq(r,1) = Lbar_fut(:,j,w);
        r = r0 + (1:T).';  r0 = r0 + T;
        I=[I;r;r;r]; J=[J;q('PVC');q('GC');q('C')]; S=[S;ones(T,1);ones(T,1);-ones(T,1)];
        r = r0 + (1:T).';  r0 = r0 + T;
        I=[I;r;r]; J=[J;q('PVC');q('V')]; S=[S;ones(T,1);ones(T,1)];
        beq(r,1) = PVbar_fut(:,j,w);
        r = r0 + (1:T).';  r0 = r0 + T;
        r2 = r(2:end);
        qE = q('E');
        I=[I;r;r2;r;r]; J=[J;qE;qE(2:end)-1;q('C');q('D')];
        S=[S;ones(T,1);-ones(T-1,1);-prm.eta_ch*dt*ones(T,1);(dt/prm.eta_dis)*ones(T,1)];
        if j == 1
            I=[I;r(1)]; J=[J;aux.blk(w,1)+aux.offB.E*Tcur+Tcur]; S=[S;-1];   % 接当天末槽
        else
            I=[I;r(1)]; J=[J;aux.blk(w,j)+aux.offB.E*T+T]; S=[S;-1];         % blk(w,j) 即第 (j−1) 个未来日
        end
        r = r0 + (1:T).';  r0 = r0 + T;
        I=[I;r;r;r;r]; J=[J;q('GL');q('GC');q('W');q('GPF')];
        S=[S;ones(T,1);ones(T,1);ones(T,1);-ones(T,1)];
    end
end
fprintf('  [装配自检] numel(I)=%d numel(J)=%d numel(S)=%d  nRowEq=%d（实际累计 %d）\n', ...
        numel(I), numel(J), numel(S), nRowEq, r0);
assert(numel(I) == numel(J) && numel(J) == numel(S), ...
       'I/J/S 长度不一致：%d/%d/%d', numel(I), numel(J), numel(S));
assert(r0 == nRowEq, '等式行数累计 %d 与解析式 %d 不符', r0, nRowEq);
% 非零元数本就不等于行数（每行 2~5 个系数）；真正该查的是"没有全零行"
nzPerRow = accumarray(I, 1, [nRowEq 1]);
assert(all(nzPerRow > 0), '存在 %d 个全零等式行', nnz(nzPerRow == 0));
Aeq = sparse(I, J, S, nRowEq, n);

%% 不等式：充放电互斥 + H-2 调增/调减互斥
I2=[]; J2=[]; S2=[]; b2=[]; r2=0;
for w = 1:K
    b0 = aux.blk(w,1);
    % C ≤ P_max·u ；D ≤ P_max(1−u)
    gC = b0 + aux.offB.C*Tcur + (1:Tcur).';
    gD = b0 + aux.offB.D*Tcur + (1:Tcur).';
    gU = b0 + aux.offB.U*Tcur + (1:Tcur).';
    rA = r2 + (1:Tcur).';  r2 = r2 + Tcur;
    rB = r2 + (1:Tcur).';  r2 = r2 + Tcur;
    I2=[I2;rA;rA;rB;rB]; J2=[J2;gC;gU;gD;gU];
    S2=[S2;ones(Tcur,1);-prm.P_max*ones(Tcur,1);ones(Tcur,1);prm.P_max*ones(Tcur,1)];
    b2=[b2;zeros(Tcur,1);prm.P_max*ones(Tcur,1)];      % b 的块数 = 行块数（每槽 2 行）
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        gC2 = bj + aux.offB.C*T + (1:T).';  gD2 = bj + aux.offB.D*T + (1:T).';
        gU2 = bj + aux.offB.U*T + (1:T).';
        rA = r2 + (1:T).';  r2 = r2 + T;
        rB = r2 + (1:T).';  r2 = r2 + T;
        I2=[I2;rA;rA;rB;rB]; J2=[J2;gC2;gU2;gD2;gU2];
        S2=[S2;ones(T,1);-prm.P_max*ones(T,1);ones(T,1);prm.P_max*ones(T,1)];
        b2=[b2;zeros(T,1);prm.P_max*ones(T,1)];
    end
end
% H-2：dP ≤ U·z, dM ≤ U·(1−z)
rA = r2 + (1:Tcur).';  r2 = r2 + Tcur;
rB = r2 + (1:Tcur).';  r2 = r2 + Tcur;
I2=[I2;rA;rA;rB;rB]; J2=[J2;aux.iDP;aux.iZ;aux.iDM;aux.iZ];
S2=[S2;ones(Tcur,1);-U_cur;ones(Tcur,1);U_cur];
b2=[b2;zeros(Tcur,1);U_cur];
assert(numel(b2) == r2, '不等式 b 长度 %d 与行数 %d 不符', numel(b2), r2);
Aineq = sparse(I2, J2, S2, r2, n);  bineq = b2;

intcon = [aux.iZ; zeros(0,1)];
for w = 1:K
    b0 = aux.blk(w,1);
    intcon = [intcon; b0 + aux.offB.U*Tcur + (1:Tcur).'];
    for j = 1:nFut
        intcon = [intcon; aux.blk(w,1+j) + aux.offB.U*T + (1:T).'];
    end
end
ub(intcon) = 1;

% ---------- 显式可行点诊断：不可行时用它逐行定位是哪一类约束被破坏 ----------
xc = zeros(n,1);
xc(aux.iA) = min(P_fix(sl+1:end), U_cur);
for w = 1:K
    b0 = aux.blk(w,1);
    % 当天剩余段：GL = min(A, L̄)，其余走 H 兜底；C = D = 0 ⇒ E 恒为 E_init
    GLa = min(xc(aux.iA), Lbar_cur(:,w));
    xc(b0 + aux.offB.GL*Tcur + (1:Tcur).') = GLa;
    xc(b0 + aux.offB.H *Tcur + (1:Tcur).') = Lbar_cur(:,w) - GLa;
    xc(b0 + aux.offB.W *Tcur + (1:Tcur).') = xc(aux.iA) - GLa;
    xc(b0 + aux.offB.V *Tcur + (1:Tcur).') = PVbar_cur(:,w);
    xc(b0 + aux.offB.E *Tcur + (1:Tcur).') = prm.E_init;
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        Ug = max(Lbar_fut(:,j,w),0) + prm.P_max;
        gpf = min(Ug, Lbar_fut(:,j,w));
        gl2 = min(gpf, Lbar_fut(:,j,w));
        xc(bj + aux.offB.GPF*T + (1:T).') = gpf;
        xc(bj + aux.offB.GL *T + (1:T).') = gl2;
        xc(bj + aux.offB.H  *T + (1:T).') = Lbar_fut(:,j,w) - gl2;
        xc(bj + aux.offB.W  *T + (1:T).') = gpf - gl2;
        xc(bj + aux.offB.V  *T + (1:T).') = PVbar_fut(:,j,w);
        xc(bj + aux.offB.E  *T + (1:T).') = prm.E_init;
    end
end
vEqC = Aeq*xc - beq;   vInC = Aineq*xc - bineq;
fprintf('  [可行点诊断] 等式最大违反 %.3e  不等式最大违反 %.3e\n', ...
        max(abs(vEqC)), max(max(vInC),0));
if max(abs(vEqC)) > 1e-8
    [~,iw] = max(abs(vEqC));  fprintf('    最差等式行 #%d（残差 %.4e）\n', iw, vEqC(iw));
end
if max(vInC) > 1e-8
    bad = find(vInC > 1e-8);
    fprintf('    违反的不等式行数 %d，前 5 个：#%s\n', numel(bad), mat2str(bad(1:min(5,end)).'));
end

optL = optimoptions('linprog','Display','off');
optM = optimoptions('intlinprog','Display','off','RelativeGapTolerance',1e-8, ...
                    'AbsoluteGapTolerance',1e-8,'MaxTime',120);
[x0,~,ef0] = linprog(f, Aineq, bineq, Aeq, beq, lb, ub, optL);
assert(ef0 == 1, 'LP 松弛未收敛 exitflag=%d', ef0);
[x, Z, exitflag, oM] = intlinprog(f, intcon, Aineq, bineq, Aeq, beq, lb, ub, x0, optM);
gap = oM.absolutegap;
end

function s = ternary(c,a,b)
if c; s=a; else; s=b; end
end
