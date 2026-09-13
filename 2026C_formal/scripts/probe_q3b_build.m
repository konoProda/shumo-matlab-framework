% probe_q3b_build.m —— func_build_q3b 的多阶段小规模验证
%
%   对 sl ∈ {0,36,72,108}（四个阶段）各装配一次小规模模型（未来 2 天、K=2），
%   做三类检验：① 装配尺寸与解析式一致；② 显式可行点零违反；
%   ③ 求解后逐情景复核全部物理约束与加固项（H-1 上界、H-2 互斥、SOC 递推）。
%
%   用法：matlab -batch "run('scripts/probe_q3b_build.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
rng(11, 'twister');

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;  nFut = 2;  K = 2;
allok = true;

for sl = [0, 36, 72, 108]
    Tcur = T - sl;
    % 造情景（量级贴近实际：负荷 2~5 MW，光伏 0~6 MW）
    Lcur  = 2500 + 2000*rand(Tcur, K);      PVcur = 6000*rand(Tcur, K);
    Lfut  = reshape(2500 + 2000*rand(T*nFut, K), [T nFut K]);
    PVfut = reshape(6000*rand(T*nFut, K),        [T nFut K]);
    Pfut  = reshape(0.4 + 0.9*rand(T*nFut, K),  [T nFut K]);
    Pcur  = reshape(0.4 + 0.9*rand(Tcur*K, 1), [Tcur K]);
    Pfix  = 2200*ones(T,1);
    % 负价情形：把第 3 个情景的前 6 槽设为负，检验 H-2
    if K >= 3; Pcur(1:6, 3) = -0.5; end

    [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q3b( ...
        Pcur, Pfut, Lcur, PVcur, Lfut, PVfut, Pfix, sl, prm.E_init, prm, true);

    % ---- ① 尺寸核对 ----
    nExp   = (1 + 3*(sl>0))*Tcur + K*(aux.nDay*Tcur + nFut*aux.nFt*T);   % s=0 不生成 Δ±/z
    eqExp  = (sl>0)*Tcur + K*(5*Tcur + nFut*5*T);
    inExp  = K*(2*Tcur + nFut*2*T) + 2*Tcur*(sl>0);
    sz = numel(f)==nExp && size(Aeq,1)==eqExp && size(A,1)==inExp;
    fprintf('sl=%3d (Tcur=%3d)  变量 %6d/%6d  等式行 %5d/%5d  不等式行 %5d/%5d  二元 %4d  %s\n', ...
        sl, Tcur, numel(f), nExp, size(Aeq,1), eqExp, size(A,1), inExp, numel(intcon), ...
        ternary(sz, '✓', '✗'));

    % ---- ② 显式可行点 ----
    xc = zeros(numel(f),1);
    xc(aux.iA) = min(Pfix(sl+1:T), aux.U_cur);
    if sl > 0
        xc(aux.iDP) = max(xc(aux.iA) - Pfix(sl+1:T), 0);
        xc(aux.iDM) = max(Pfix(sl+1:T) - xc(aux.iA), 0);
        xc(aux.iZ)  = double(xc(aux.iDP) > 0);
    end
    for w = 1:K
        b0 = aux.blk(w,1);
        gl = min(xc(aux.iA), aux.Lbar_cur(:,w));
        xc = put(xc, b0 + aux.offB.GL*Tcur  + (1:Tcur).', gl);
        xc = put(xc, b0 + aux.offB.H*Tcur   + (1:Tcur).', aux.Lbar_cur(:,w) - gl);
        xc = put(xc, b0 + aux.offB.W*Tcur   + (1:Tcur).', xc(aux.iA) - gl);
        xc = put(xc, b0 + aux.offB.PVC*Tcur + (1:Tcur).', zeros(Tcur,1));
        xc = put(xc, b0 + aux.offB.V*Tcur   + (1:Tcur).', aux.PVbar_cur(:,w));
        xc = put(xc, b0 + aux.offB.E*Tcur   + (1:Tcur).', prm.E_init*ones(Tcur,1));
        for j = 1:nFut
            bj = aux.blk(w,1+j);
            gpf = min(aux.Lbar_fut(:,j,w) + prm.P_max, aux.Lbar_fut(:,j,w));
            gl2 = min(gpf, aux.Lbar_fut(:,j,w));
            xc = put(xc, bj + aux.offB.GPF*T + (1:T).', gpf);
            xc = put(xc, bj + aux.offB.GL*T  + (1:T).', gl2);
            xc = put(xc, bj + aux.offB.H*T   + (1:T).', aux.Lbar_fut(:,j,w) - gl2);
            xc = put(xc, bj + aux.offB.W*T   + (1:T).', gpf - gl2);
            xc = put(xc, bj + aux.offB.V*T   + (1:T).', aux.PVbar_fut(:,j,w));
            xc = put(xc, bj + aux.offB.E*T   + (1:T).', prm.E_init*ones(T,1));
        end
    end
    vEqC = max(abs(Aeq*xc - beq));   vInC = max(max(A*xc - b), 0);
    fprintf('        可行点违反：等式 %.2e  不等式 %.2e\n', vEqC, vInC);

    % ---- ③ 求解并复核 ----
    optL = optimoptions('linprog','Display','off');
    optM = optimoptions('intlinprog','Display','off','MaxTime',120, ...
                        'RelativeGapTolerance',1e-8,'AbsoluteGapTolerance',1e-8);
    [x0,~,ef0] = linprog(f, A, b, Aeq, beq, lb, ub, optL);
    assert(ef0 == 1, 'sl=%d 的 LP 松弛未收敛 exitflag=%d', sl, ef0);
    [x, Z, ef, oM] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, x0, optM);
    assert(ef == 1 || ef == 2, 'sl=%d 的 MILP 未正常返回 exitflag=%d', sl, ef);

    v = verify_solution(x, aux, prm, Lcur, PVcur, Lfut, PVfut, Pfix);
    okk = sz && vEqC < 1e-8 && vInC < 1e-8 && v.all < 1e-7 && (ef==1||ef==2);
    fprintf('        Z=%.2f gap=%.2e | 分解 %.1e 互斥 %.1e 上界 %.1e | 等式 %.1e SOC %.1e CD %.1e 守恒 %.1e  %s\n\n', ...
        Z, oM.absolutegap, v.dPdm, v.mutex, v.aub, v.eq, v.soc, v.cd, v.link, ternary(okk,'✅','❌'));
    allok = allok && okk;
end

fprintf('%s\n', ternary(allok, 'PROBE_Q3B_BUILD_ALL_PASS', 'PROBE_Q3B_BUILD_FAILED'));

% ================================================================= 局部函数
function x = put(x, idx, v)
x(idx) = v;
end

function v = verify_solution(x, aux, prm, Lcur, PVcur, Lfut, PVfut, Pfix)
T = aux.T;  Tcur = aux.Tcur;  K = aux.K;  nFut = aux.nFut;  sl = aux.sl;
dt = prm.dt;  ob = aux.offB;
A  = x(aux.iA);
v.dPdm = 0;  v.mutex = 0;  v.aub = max(A - aux.U_cur);
if aux.hasAdj
    dP = x(aux.iDP);  dM = x(aux.iDM);  z = x(aux.iZ);
    v.dPdm  = max(abs((A - Pfix(sl+1:T)) - (dP - dM)));
    v.mutex = max(max(dP .* dM), max(max(dP - aux.U_cur.*z), max(dM - aux.U_cur.*(1-z))));
end
v.eq = 0;  v.soc = 0;  v.cd = 0;  v.link = 0;
for w = 1:K
    b0 = aux.blk(w,1);
    G  = @(nm) x(b0 + ob.(nm)*Tcur + (1:Tcur).');
    v.link = max(v.link, max(abs(G('GL') + G('GC') + G('W') - A)));
    v.eq   = max(v.eq, max(abs(G('GL') + G('D') + G('H') - aux.Lbar_cur(:,w))));
    v.eq   = max(v.eq, max(abs(G('PVC') + G('GC') - G('C'))));
    v.eq   = max(v.eq, max(abs(G('PVC') + G('V') - aux.PVbar_cur(:,w))));
    v.cd   = max(v.cd, max(G('C') .* G('D')));
    E = G('E');  Gc = G('C');  Gd = G('D');
    v.soc = max(v.soc, abs(E(1) - prm.E_init - prm.eta_ch*dt*Gc(1) + dt/prm.eta_dis*Gd(1)));
    v.soc = max(v.soc, max(abs(E(2:end) - E(1:end-1) - prm.eta_ch*dt*Gc(2:end) + dt/prm.eta_dis*Gd(2:end))));
    for j = 1:nFut
        bj = aux.blk(w,1+j);
        Q = @(nm) x(bj + ob.(nm)*T + (1:T).');
        v.link = max(v.link, max(abs(Q('GL') + Q('GC') + Q('W') - Q('GPF'))));
        v.eq   = max(v.eq, max(abs(Q('GL') + Q('D') + Q('H') - aux.Lbar_fut(:,j,w))));
        v.eq   = max(v.eq, max(abs(Q('PVC') + Q('GC') - Q('C'))));
        v.eq   = max(v.eq, max(abs(Q('PVC') + Q('V') - aux.PVbar_fut(:,j,w))));
        v.cd   = max(v.cd, max(Q('C') .* Q('D')));
        E2 = Q('E');  Qc = Q('C');  Qd = Q('D');
        prev = E(end);
        if j > 1; prev = x(aux.blk(w,j) + ob.E*T + T); end
        v.soc = max(v.soc, abs(E2(1) - prev - prm.eta_ch*dt*Qc(1) + dt/prm.eta_dis*Qd(1)));
        v.soc = max(v.soc, max(abs(E2(2:end) - E2(1:end-1) - prm.eta_ch*dt*Qc(2:end) + dt/prm.eta_dis*Qd(2:end))));
    end
end
v.all = max([v.dPdm v.mutex max(v.aub,0) v.eq v.soc v.cd v.link]);
end

function s = ternary(c,a,b)
if c; s=a; else; s=b; end
end
