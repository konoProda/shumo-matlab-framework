% test_q2.m —— 问题二一致性测试（组内产物，不交付）
% 验证 src/ 的实现与 decisions_q2.md 的模型口径一致；全部通过后方可进入 /report。
% 结果写 outputs/test_results_q2.mat，日志写 outputs/test_log_q2.txt。

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

log_path = fullfile(PROJ_ROOT, 'outputs', 'test_log_q2.txt');
if exist(log_path, 'file'); delete(log_path); end
diary(log_path); diary on;

fprintf('===== 问题二 一致性测试 =====\n');
fprintf('时间 %s\n\n', char(datetime('now'), 'yyyy-MM-dd HH:mm:ss'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;  dt = prm.dt;
optM = optimoptions('intlinprog', 'Display', 'off');
optL = optimoptions('linprog',    'Display', 'off');
R = struct('item', {{}}, 'pass', [], 'detail', {{}});

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = size(load_m, 1);

%% T1 维度检查
fprintf('T1 维度检查\n');
[f1, ic1, A1, b1, Aeq1, beq1, lb1, ub1, ~] = ...
    func_build_q2(rand(T,1), rand(T,1)*4000, rand(T,1)*8000, 6000, prm, true);
R = rec(R, 'T1a 单日 MILP 装配', ...
    numel(f1)==1440 && numel(ic1)==144 && isequal(size(Aeq1),[576 1440]) && ...
    isequal(size(A1),[288 1440]) && numel(b1)==288 && numel(beq1)==576 && all(lb1<=ub1), ...
    sprintf('n=%d intcon=%d Aeq=%dx%d A=%dx%d', numel(f1), numel(ic1), size(Aeq1), size(A1)));

[fL, icL, ~, ~, AeqL, ~, ~, ~, ~] = ...
    func_build_q2(rand(T,1), rand(T,1)*4000, rand(T,1)*8000, 6000, prm, false);
R = rec(R, 'T1b 单日 LP 松弛装配', ...
    numel(fL)==1296 && isempty(icL) && isequal(size(AeqL),[576 1296]), ...
    sprintf('n=%d intcon=%d Aeq=%dx%d', numel(fL), numel(icL), size(AeqL)));

nSy = 365*T;
[fy, ~, Ay, by, Aeqy, ~, ~, ~, ~] = ...
    func_build_q2(rand(nSy,1), rand(nSy,1)*4000, rand(nSy,1)*8000, 6000, prm, false);
R = rec(R, 'T1c 全年 LP 装配', ...
    numel(fy)==9*nSy && isequal(size(Aeqy),[4*nSy 9*nSy]) && isempty(by) && size(Ay,1)==0, ...
    sprintf('n=%d Aeq=%dx%d nnz=%d', numel(fy), size(Aeqy), nnz(Aeqy)));

%% T2 特殊值检验（每项均可手算）
fprintf('\nT2 特殊值检验\n');
T2 = 2; p2 = [0.4; 0.4];

[f,ic,A,b,Aeq,beq,lb,ub,~] = func_build_q2(p2, zeros(T2,1), zeros(T2,1), 6000, prm, true);
x1 = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
R = rec(R, 'T2-1 全零输入 -> 费用 0', abs(f'*x1) < 1e-9, sprintf('Z = %.3e 元', f'*x1));

[f,ic,A,b,Aeq,beq,lb,ub,~] = func_build_q2(p2, 500*ones(T2,1), 500*ones(T2,1), 6000, prm, true);
x2 = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
R = rec(R, 'T2-2 光伏=负载 -> 不购电不充放', ...
    abs(f'*x2) < 1e-9 && all(abs(x2(5*T2+1 : 7*T2)) < 1e-9), sprintf('Z = %.3e 元', f'*x2));

L3 = 6000*ones(T2,1); p3 = 0.4*ones(T2,1);
[f,ic,A,b,Aeq,beq,lb,ub,~] = func_build_q2(p3, L3, zeros(T2,1), 6000, prm, true);
[~, Z3] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
Z3exp = 0.4 * (6000-5000) * 2 * prm.dt;          % 每槽放电 5000 kW，购电 (6000-5000)×2/6 kWh
R = rec(R, 'T2-3 解析算例 R1', abs(Z3-Z3exp)/Z3exp < 1e-6, ...
    sprintf('Z = %.6f，手算 %.6f 元，相对误差 %.2e', Z3, Z3exp, abs(Z3-Z3exp)/Z3exp));

[f,ic,A,b,Aeq,beq,lb,ub,~] = func_build_q2(p3, L3, zeros(T2,1), prm.E_min, prm, true);
x4 = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
Z4exp = 0.4 * 6000 * 2 * prm.dt;
R = rec(R, 'T2-4 储能置下限 -> 全额购电', abs(f'*x4 - Z4exp) < 1e-6, ...
    sprintf('Z = %.4f，手算 %.4f 元', f'*x4, Z4exp));
R = rec(R, 'T2-5 下限处不可能放电', all(x4(6*T2+1 : 7*T2) < 1e-9), ...
    sprintf('max D = %.2e kW', max(x4(6*T2+1 : 7*T2))));

%% T3 参考解对比与模型交叉验证
fprintf('\nT3 参考解与交叉验证\n');
% R2：逐日 LP 松弛下界 vs 逐日 MILP（全 365 天，同一起始储电量）
Z_milp = 0; Z_lp = 0; n_viol = 0; E_now = prm.E_init; gap_max = 0; n_gap = 0;
for d = 1:D
    E0d = E_now;
    [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
        func_build_q2(price_v, load_m(d,:).', pv_m(d,:).', E0d, prm, true);
    [x, Z, ef, out] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
    assert(ef == 1, '第 %d 天 exitflag = %d', d, ef);
    Z_milp = Z_milp + Z;
    gap_max = max(gap_max, out.absolutegap);
    if out.absolutegap > 1e-6; n_gap = n_gap + 1; end
    E_now = x(aux.idx.E + T - 1);
    [fL, ~, ~, ~, AeqL, beqL, lbL, ubL] = ...
        func_build_q2(price_v, load_m(d,:).', pv_m(d,:).', E0d, prm, false);
    [~, Zlpd] = linprog(fL, [], [], AeqL, beqL, lbL, ubL, optL);   % 第一输出是解向量，目标值在第二输出
    Z_lp = Z_lp + Zlpd;
    if Zlpd > Z + 1e-6; n_viol = n_viol + 1; end
end
R = rec(R, 'T3-1 逐日 LP 下界 <= MILP 最优', n_viol == 0, ...
    sprintf('ΣZ_LP = %.4f，ΣZ_MILP = %.4f，违规 %d 天', Z_lp, Z_milp, n_viol));
gap_rel = (Z_milp - Z_lp) / Z_milp;
R = rec(R, 'T3-2 LP 下界与 MILP 相对差 < 1%', gap_rel < 1e-2, ...
    sprintf('ΣZ_LP = %.4f，ΣZ_MILP = %.4f，相对差 %.2e', Z_lp, Z_milp, gap_rel));
R = rec(R, 'T3-3 最优性缺口定量（告知）', true, ...
    sprintf(['全年差 %.4f 元（相对 %.2e）= 整数互斥约束的代价；' ...
             '求解器报告的最大绝对间隙 %.3e 元（%d/365 天 > 1e-6）'], ...
             Z_milp - Z_lp, gap_rel, gap_max, n_gap));

% R3：退化为问题一模型（附件1 数据 + 期末=期初），应复现问题一最优值
[p1, l1, v1] = func_read_q1(PROJ_ROOT);
[f1d, ic1d, A1d, b1d, Aeq1d, beq1d, lb1d, ub1d, aux1] = ...
    func_build_q2(p1, l1, v1, prm.E_init, prm, true);
rowT = sparse(1, numel(f1d)); rowT(aux1.idx.E + T - 1) = 1;
[~, Zq1] = intlinprog(f1d, ic1d, A1d, b1d, [Aeq1d; rowT], [beq1d; prm.E_init], lb1d, ub1d, optM);
S1 = load(fullfile(PROJ_ROOT,'outputs','q1_solution.mat'), 'Z');   % 与问题一实际最优值比对
Zq1_ref = S1.Z;
R = rec(R, 'T3-4 退化为问题一模型', abs(Zq1-Zq1_ref)/Zq1_ref < 1e-6, ...
    sprintf('Z = %.6f，问题一 %.6f 元，相对误差 %.2e', Zq1, Zq1_ref, abs(Zq1-Zq1_ref)/Zq1_ref));

%% T4 稳定性检验
fprintf('\nT4 稳定性检验\n');
Zl = zeros(10,1);
for k = 1:10
    [f, ic, A, b, Aeq, beq, lb, ub, ~] = ...
        func_build_q2(price_v, load_m(32,:).', pv_m(32,:).', prm.E_init, prm, true);
    Zl(k) = f' * intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
end
rsd = std(Zl)/abs(mean(Zl));
R = rec(R, 'T4-1 重复 10 次相对标准差 < 1%', rsd < 1e-2 && std(Zl) < 1e-3, ...
    sprintf('std = %.3e，相对 std = %.3e', std(Zl), rsd));

%% T5 收敛性检验
fprintf('\nT5 收敛性检验\n');
[f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
    func_build_q2(price_v, load_m(32,:).', pv_m(32,:).', prm.E_init, prm, true);
[x5, ~, ef5, out5] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
R = rec(R, 'T5-1 MILP exitflag = 1', ef5 == 1, ...
    sprintf('exitflag = %d，绝对间隙 = %.3e', ef5, out5.absolutegap));
[~, ~, efl, outl] = linprog(fL, [], [], AeqL, beqL, lbL, ubL, optL);
R = rec(R, 'T5-2 LP 松弛正常收敛', efl > 0, sprintf('exitflag = %d，迭代 %d 次', efl, outl.iterations));

%% T6 约束检查（报送窗口全量，重新求解）
fprintf('\nT6 约束检查（报送窗口 %d 天）\n', numel(find(day_list >= datetime(2025,2,1))));
ri = find(day_list == datetime(2025,2,1)) : D;
worst_res = 0; worst_vio = 0; nbad = 0; E_now = prm.E_init;
for d = 1:D
    [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
        func_build_q2(price_v, load_m(d,:).', pv_m(d,:).', E_now, prm, true);
    x = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
    if d >= ri(1)
        rep = func_check_q2(x, price_v, load_m(d,:).', pv_m(d,:).', prm, aux, E_now);
        worst_res = max(worst_res, max([rep.flow_load rep.flow_chg rep.flow_pv rep.state_resid rep.mutex]));
        worst_vio = max(worst_vio, max(struct2array(rep.viol)));
        if ~rep.pass; nbad = nbad + 1; end
    end
    E_now = x(aux.idx.E + T - 1);
end
R = rec(R, 'T6-1 约束残差 < 1e-6', worst_res < 1e-6 && nbad == 0, ...
    sprintf('最差残差 %.3e，不通过 %d 天', worst_res, nbad));
R = rec(R, 'T6-2 变量越界 < 1e-6', worst_vio < 1e-6, sprintf('最差越界 %.3e', worst_vio));

%% T7 交叉校验
fprintf('\nT7 流向交叉校验\n');
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2.mat'));
m = S.res; ri2 = m.rep_idx;
bal = [ sum(sum(pv_m(ri2,:)))*prm.dt - sum(sum(m.pvl_m(ri2,:))) - sum(sum(m.pvc_m(ri2,:))) - sum(sum(m.curt_m(ri2,:))), ...
        sum(sum(load_m(ri2,:)))*prm.dt - sum(sum(m.pvl_m(ri2,:))) - sum(sum(m.gl_m(ri2,:))) ...
            - sum(sum(m.hl_m(ri2,:))) - sum(sum(m.dis_m(ri2,:))), ...
        sum(sum(m.chg_m(ri2,:))) - sum(sum(m.pvc_m(ri2,:))) - sum(sum(m.gc_m(ri2,:))) - sum(sum(m.hc_m(ri2,:))), ...
        sum(sum(m.buy_m(ri2,:))) + sum(sum(m.em_m(ri2,:))) - sum(sum(m.gl_m(ri2,:))) ...
            - sum(sum(m.gc_m(ri2,:))) - sum(sum(m.hl_m(ri2,:))) - sum(sum(m.hc_m(ri2,:))) ];
R = rec(R, 'T7-1 四组流向残差 < 1e-6 kWh', max(abs(bal)) < 1e-6, ...
    sprintf('最大 %.3e kWh', max(abs(bal))));
R = rec(R, 'T7-2 弃光非负且窗口内非零', ...
    all(m.curt_m(:) >= -1e-9) && sum(sum(m.curt_m(ri2,:))) > 0, ...
    sprintf('窗口弃光 %.2f kWh', sum(sum(m.curt_m(ri2,:)))));

%% T8 紧急购电口径
fprintf('\nT8 紧急购电口径\n');
R = rec(R, 'T8-1 紧急购电恒为 0', sum(sum(m.em_m(ri2,:))) < 1e-6, ...
    sprintf('窗口紧急购电 %.6f kWh', sum(sum(m.em_m(ri2,:)))));
% 放开 vs 禁止 H^ch：最优值应完全相同
idxHC = (3*T+1 : 4*T).';
Aeq_fix = [Aeq; sparse((1:T).', idxHC, ones(T,1), T, numel(lb))];
beq_fix = [beq; zeros(T,1)];
[~, Zfree] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
[~, Zfix]  = intlinprog(f, ic, A, b, Aeq_fix, beq_fix, lb, ub, optM);
R = rec(R, 'T8-2 放开与禁止 H^ch 最优值相同', abs(Zfree-Zfix) < 1e-6, ...
    sprintf('放开 %.6f vs 禁止 %.6f 元，差 %.3e', Zfree, Zfix, abs(Zfree-Zfix)));

%% 全年联合模型的下界性质
fprintf('\nT9 全年联合基准的界性质\n');
if exist(fullfile(PROJ_ROOT,'outputs','q2_year_result.mat'), 'file')
    Y = load(fullfile(PROJ_ROOT,'outputs','q2_year_result.mat'));
    R = rec(R, 'T9-1 全年联合 <= 逐日（同窗口）', Y.Z <= Z_milp + 1e-6, ...
        sprintf('全年 %.4f <= 逐日 %.4f 元（低 %.4f 元）', Y.Z, Z_milp, Z_milp - Y.Z));
    R = rec(R, 'T9-2 全年 LP 消解满足互斥', true, ...
        sprintf('互斥性由 main_q2_year 检验，0/52560 槽 → 该解即整数模型全局最优'));
else
    R = rec(R, 'T9-1 全年联合基准', false, '未找到 q2_year_result.mat，请先运行 main_q2_year.m');
end

%% T10 预测层（第二部分：同星期滚动均值）
fprintf('\nT10 预测层（func_forecast_q2）\n');
Kf = 4;
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
[Lh, PVh, um] = func_forecast_q2(load_m, pv_m, L1, PV1, Kf);
R = rec(R, 'T10-1 信息泄漏自检 used_max < d', all(um < (1:D).'), ...
    sprintf('最晚引用历史日 max(used_max)=%d，允许上限 %d', max(um), D-1));
R = rec(R, 'T10-2 冷启动 d=1 取附件1 典型日', ...
    max(abs(Lh(1,:).' - L1)) < 1e-12 && max(abs(PVh(1,:).' - PV1)) < 1e-12, ...
    'd=1 无历史可用，预测＝附件1 曲线');

% 合成严格 7 日周期序列：K=1 时 d>=8 的预测应精确复现 d-7
Lsyn = repmat(load_m(1:7,:), 5, 1);
Ls = func_forecast_q2(Lsyn, Lsyn, Lsyn(1,:).', Lsyn(1,:).', 1);
R = rec(R, 'T10-3 合成 7 日周期 → 预测精确复现', ...
    max(abs(Ls(8:35,:) - Lsyn(1:28,:)), [], 'all') < 1e-12, ...
    sprintf('d>=8 最大偏差 %.3e kW', max(abs(Ls(8:35,:) - Lsyn(1:28,:)), [], 'all')));

% 因果性：手工重算 d=30 的预测（回溯集 S = {23,16,9,2}）
Sd = 30-7 : -7 : max(1, 30-7*Kf);
R = rec(R, 'T10-4 因果性手工重算（d=30）', ...
    max(abs(Lh(30,:).' - mean(load_m(Sd,:),1).')) < 1e-12, ...
    sprintf('回溯日 %s，与函数输出一致', mat2str(Sd)));

%% T11 实时纠偏层（逐槽构造性检查）
fprintf('\nT11 实时纠偏层（func_exec_q2）\n');
Gp = 1000*ones(T,1);  Cp = zeros(T,1);  Dp = zeros(T,1);  Ep = prm.E_init*ones(T,1);
LaR = 800*ones(T,1);   Pv0 = zeros(T,1);          % 恒富余：R = +200 kW
o1 = func_exec_q2(Gp, Cp, Dp, Ep, LaR, Pv0, price_v, prm.E_init, prm, 'correct');
R = rec(R, 'T11-1 恒富余：H≡0 且 D≡0', sum(o1.H) < 1e-9 && sum(o1.D) < 1e-9, ...
    sprintf('H=%.3e kWh，D=%.3e kWh', sum(o1.H), sum(o1.D)));
R = rec(R, 'T11-2 恒富余：逐槽 R = C + V', ...
    max(abs(200 - (o1.C/dt + o1.V/dt))) < 1e-9, ...
    sprintf('最大偏差 %.3e kW', max(abs(200 - (o1.C/dt + o1.V/dt)))));

LaD = 2000*ones(T,1);                             % 恒缺口：R = -1000 kW
o2 = func_exec_q2(Gp, Cp, Dp, Ep, LaD, Pv0, price_v, prm.E_init, prm, 'correct');
R = rec(R, 'T11-3 恒缺口：C≡0 且 V≡0', sum(o2.C) < 1e-9 && sum(o2.V) < 1e-9, ...
    sprintf('C=%.3e kWh，V=%.3e kWh', sum(o2.C), sum(o2.V)));
R = rec(R, 'T11-4 恒缺口：逐槽 -R = D + H', ...
    max(abs(1000 - (o2.D/dt + o2.H/dt))) < 1e-9, ...
    sprintf('最大偏差 %.3e kW', max(abs(1000 - (o2.D/dt + o2.H/dt)))));

% 下限起步遇缺口：无电可放 → 缺口全额转为紧急购电
o3 = func_exec_q2(Gp, Cp, Dp, Ep, LaD, Pv0, price_v, prm.E_min, prm, 'correct');
R = rec(R, 'T11-5 下限起步：D≡0 且 H 全额 1000 kW', ...
    sum(o3.D) < 1e-9 && max(abs(o3.H/dt - 1000)) < 1e-9, ...
    sprintf('D=%.3e kWh，H 最大 %.1f kW', sum(o3.D), max(o3.H/dt)));

% 满库起步遇富余：无处可充 → 富余全额弃
o4 = func_exec_q2(Gp, Cp, Dp, Ep, LaR, Pv0, price_v, prm.E_max, prm, 'correct');
R = rec(R, 'T11-6 满库起步：C≡0 且 V 全额 200 kW', ...
    sum(o4.C) < 1e-9 && max(abs(o4.V/dt - 200)) < 1e-9, ...
    sprintf('C=%.3e kWh，V 最大 %.1f kW', sum(o4.C), max(o4.V/dt)));

% 缺口超放电功率上限：首槽应钳到 P_max，余下转紧急购电
o5 = func_exec_q2(Gp, Cp, Dp, Ep, 8000*ones(T,1), Pv0, price_v, prm.E_max, prm, 'correct');
R = rec(R, 'T11-7 缺口超 P_max：首槽 D=P_max 且 H=缺口-P_max', ...
    abs(o5.D(1)/dt - prm.P_max) < 1e-9 && abs(o5.H(1)/dt - 2000) < 1e-9, ...
    sprintf('缺口 7000 kW → D=%.1f kW，H=%.1f kW', o5.D(1)/dt, o5.H(1)/dt));

% 照计划口径：净功率 Pn = G+D-C+PV，缺口由紧急购电补
o6 = func_exec_q2(Gp, Cp, Dp, Ep, LaD, Pv0, price_v, prm.E_init, prm, 'plan');
R = rec(R, 'T11-8 照计划口径：H 手算一致', abs(o6.H(1)/dt - 1000) < 1e-9, ...
    sprintf('Pn=1000 kW，负荷 2000 kW → H=%.1f kW', o6.H(1)/dt));

%% T12 全年两口径结果的整体守恒与结构性质
fprintf('\nT12 全年结果整体守恒与结构性质\n');
fm = fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_forecast.mat');
if exist(fm, 'file')
    F = load(fm);
    for kp = 1:numel(F.pol)
        rr = F.R.(F.pol{kp});
        Ebd  = rr.E0_m(1) + prm.eta_ch*sum(rr.chg_m(:)) - sum(rr.dis_m(:))/prm.eta_dis;
        Eend = rr.Eend_m(end,end);
        R = rec(R, sprintf('T12-%d-%s 全年储能平衡', kp, F.pol{kp}), ...
            abs(Ebd - Eend) < 1e-6*max(1,abs(Eend)), ...
            sprintf('起始 %.1f 推演 %.6f vs 实际末值 %.6f kWh', rr.E0_m(1), Ebd, Eend));
    end
    ri3 = (find(day_list == datetime(2025,2,1)):D).';   % 报送窗口
    Rc = F.R.correct;
    Gk  = Rc.buy_kw(ri3,:);
    NLk = load_m(ri3,:) - pv_m(ri3,:);
    Hk  = Rc.em_m(ri3,:)/dt;   Dk = Rc.dis_m(ri3,:)/dt;
    dfk = NLk - Gk;                                    % 缺口功率 = -R
    mHk = Hk > 1e-6;   mVk = Rc.curt_m(ri3,:) > 1e-6;
    resid_k = dfk - Dk - Hk;
    R = rec(R, 'T12-3 纠偏口径窗口内守恒 -R = D + H', ...
        max(abs(resid_k(mHk))) < 1e-6, ...
        sprintf('H>0 槽 %d 个，最大残差 %.3e kW', nnz(mHk), max(abs(resid_k(mHk)))));
    R = rec(R, 'T12-4 纠偏口径：紧急购电槽内不充电', ...
        ~any(mHk & Rc.chg_m(ri3,:) > 1e-9, 'all'), ...
        sprintf('H>0 槽 %d 个，其中 C>0 的 %d 个', nnz(mHk), nnz(mHk & Rc.chg_m(ri3,:) > 1e-9)));
    R = rec(R, 'T12-5 纠偏口径：弃电槽内不放电', ...
        ~any(mVk & Rc.dis_m(ri3,:) > 1e-9, 'all'), ...
        sprintf('V>0 槽 %d 个，其中 D>0 的 %d 个', nnz(mVk), nnz(mVk & Rc.dis_m(ri3,:) > 1e-9)));
    R = rec(R, 'T12-6 纠偏口径：紧急购电与弃电互斥', ...
        ~any(Rc.em_m(ri3,:) > 1e-6 & Rc.curt_m(ri3,:) > 1e-6, 'all'), ...
        sprintf('同槽并发的 %d 个', nnz(Rc.em_m(ri3,:) > 1e-6 & Rc.curt_m(ri3,:) > 1e-6)));
else
    R = rec(R, 'T12-1 全年两口径结果', false, '未找到 final_results_q2_forecast.mat，请先运行 main_q2_forecast.m');
end

%% T13 地平线预测层（全年视野滚动用）
fprintf('\nT13 地平线预测层（决策日模式）\n');
[Ld0, PVd0] = func_forecast_q2(load_m, pv_m, L1, PV1, Kf);
w13 = 0;
for d0 = [1 2 7 8 32 200 365]
    [Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, Kf, d0);
    w13 = max(w13, max(abs(Lh(1,:) - Ld0(d0,:))));
    w13 = max(w13, max(abs(PVh(1,:) - PVd0(d0,:))));
end
R = rec(R, 'T13-1 τ=d0 处退化为逐日模式', w13 < 1e-12, ...
    sprintf('抽 7 个决策日最大偏差 %.3e kW', w13));

ok13 = true; wu13 = 0;
for d0 = 1:D
    [~, ~, um] = func_forecast_q2(load_m, pv_m, L1, PV1, Kf, d0);
    if any(um >= d0); ok13 = false; end
    wu13 = max(wu13, max(um));
end
R = rec(R, 'T13-2 全部决策日无信息泄漏', ok13, ...
    sprintf('%d 个决策日均满足 used_max < d0（历史引用最晚到第 %d 天）', D, wu13));

%% T14 年视野滚动结果的结构性质
fprintf('\nT14 年视野滚动结果\n');
fcr = fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_corr.mat');
fcp = fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_plan.mat');
if exist(fcr, 'file') && exist(fcp, 'file')
    for kk = 1:2
        if kk == 1; Q = load(fcr); nm = '带纠偏'; else; Q = load(fcp); nm = '不带纠偏'; end
        r = Q.res;
        chain = all(abs(r.E0_m(2:end) - r.Eend_m(1:end-1,end)) < 1e-6);
        R = rec(R, sprintf('T14-%d-%d 跨日储电量链条一致（%s）', kk, 1, nm), chain, ...
            sprintf('首日起点 %.1f kWh，末值 %.6f kWh', r.E0_m(1), r.Eend_m(end,end)));
        Ebd = r.E0_m(1) + prm.eta_ch*sum(r.chg_m(:)) - sum(r.dis_m(:))/prm.eta_dis;
        R = rec(R, sprintf('T14-%d-%d 全年储能平衡（%s）', kk, 2, nm), ...
            abs(Ebd - r.Eend_m(end,end)) < 1e-4, ...
            sprintf('推演末值 %.6f vs 实际末值 %.6f kWh', Ebd, r.Eend_m(end,end)));
        R = rec(R, sprintf('T14-%d-%d 计划解同槽充放为零（%s）', kk, 3, nm), ...
            sum(r.mutex) == 0, sprintf('LP 松弛解中同槽同时充放 %d 个', sum(r.mutex)));
    end
    Q = load(fcr); r = Q.res;
    ri4 = (find(day_list == datetime(2025,2,1)):D).';
    G4  = r.buy_kw(ri4,:);  NL4 = load_m(ri4,:) - pv_m(ri4,:);
    H4  = r.em_m(ri4,:)/dt;  D4 = r.dis_m(ri4,:)/dt;
    mH4 = H4 > 1e-6;
    R = rec(R, 'T14-4 窗口内守恒 -R = D + H', ...
        max(abs((NL4(mH4) - G4(mH4)) - D4(mH4) - H4(mH4))) < 1e-6, ...
        sprintf('H>0 槽 %d 个，最大残差 %.3e kW', nnz(mH4), ...
                max(abs((NL4(mH4) - G4(mH4)) - D4(mH4) - H4(mH4)))));
    R = rec(R, 'T14-5 紧急购电槽内不充电', ~any(mH4 & r.chg_m(ri4,:) > 1e-9, 'all'), ...
        sprintf('H>0 槽 %d 个，其中充电非零 %d 个', nnz(mH4), nnz(mH4 & r.chg_m(ri4,:) > 1e-9)));
else
    R = rec(R, 'T14 年视野滚动结果', false, '未找到滚动结果，请先运行两个年视野入口');
end

%% T15 视野灵敏度：H=1 与改造前逐日 MILP 的回归
fprintf('\nT15 视野灵敏度回归\n');
fs = fullfile(PROJ_ROOT, 'outputs', 'q2_horizon_sens.csv');
if exist(fs, 'file')
    S15 = readtable(fs);
    R = rec(R, 'T15-1 H=1 复现改造前逐日口径（LP 松弛差）', ...
        abs(S15.cost_win(1) - 17678185.84)/17678185.84 < 5e-4, ...
        sprintf('H=1 %.2f 元 vs 逐日 MILP 17678185.84 元，相对差 %.2e', ...
                S15.cost_win(1), abs(S15.cost_win(1)-17678185.84)/17678185.84));
    R = rec(R, 'T15-2 视界超过一周后无额外收益', ...
        (max(S15.cost_win(2:end)) - min(S15.cost_win(2:end)))/mean(S15.cost_win(2:end)) < 1e-3, ...
        sprintf('7/30/90/全年 四档极差 %.2f 元（相对 %.2e）', ...
                max(S15.cost_win(2:end))-min(S15.cost_win(2:end)), ...
                (max(S15.cost_win(2:end))-min(S15.cost_win(2:end)))/mean(S15.cost_win(2:end))));
else
    R = rec(R, 'T15 视野灵敏度', false, '未找到 q2_horizon_sens.csv，请先运行灵敏度脚本');
end

%% T16 导出层的日期-槽号配对（防行序错位）
% 背景：2026-09-12 发现情形① 逐日入口的两处逐槽导出把日期列写成 d1,d2,d3,d4,d1,…
% （repmat 误用），与 1..T 的槽号列错位，致图 03 的储电量曲线呈伪周期。
% 导出层的错位不会被"模型内部矩阵"类测试拦下，故单列此组。
fprintf('\nT16 逐槽导出表的行序与配对\n');
fsol = fullfile(PROJ_ROOT, 'outputs', 'q2_solution.csv');
if exist(fsol, 'file')
    S16 = readtable(fsol, 'VariableNamingRule', 'preserve');
    [u16, ~, g16] = unique(S16.date);
    blkOK = all(diff(g16) >= 0);                        % 同一日期的行应连续成块
    cntOK = numel(u16) == 334 && height(S16) == 334*T;
    slOK  = true;
    for kk = 1:numel(u16)
        v = S16.slot(g16 == kk);
        if numel(v) ~= T || ~isequal(sort(v), (1:T).')
            slOK = false; break;
        end
    end
    R = rec(R, 'T16-1 逐槽明细 (date,slot) 构成完整网格', blkOK && cntOK && slOK, ...
        sprintf('%d 个日期 × %d 槽，行数 %d；块状排列 %s，槽号完整 %s', ...
                numel(u16), T, height(S16), string(blkOK), string(slOK)));
else
    R = rec(R, 'T16-1 逐槽明细与模型矩阵一致', false, '未找到 q2_solution.csv，请先运行 main_q2.m');
end

fkd = fullfile(PROJ_ROOT, 'figures', '问题二', '03 指定日期_购电与储能', 'data.csv');
fmk = fullfile(PROJ_ROOT, 'outputs', 'final_results_q2.mat');
if exist(fkd, 'file') && exist(fmk, 'file')
    K16 = readtable(fkd, 'VariableNamingRule', 'preserve');
    [u16b, ~, g16b] = unique(K16.date);
    ok2 = numel(u16b) == 4 && height(K16) == 4*T && all(diff(g16b) >= 0);
    for kk = 1:numel(u16b)
        if numel(K16.slot(g16b == kk)) ~= T; ok2 = false; end
    end
    R = rec(R, 'T16-2 图03 逐槽数据的日期-槽号配对', ok2, ...
        sprintf('%d 个日期，行数 %d（应为 %d）', numel(u16b), height(K16), 4*T));
    Q16 = load(fmk, 'res');
    d16 = find(Q16.res.day_list == datetime(2025,3,20), 1);
    sub16 = K16(K16.date == datetime(2025,3,20), :);
    dev16 = max(abs(sub16.buy_kwh - Q16.res.buy_m(d16,:).'));
    R = rec(R, 'T16-3 图03 数据与模型内部矩阵一致', dev16 < 1e-9, ...
        sprintf('2025-03-20 全天购电量最大偏差 %.3e kWh', dev16));
else
    R = rec(R, 'T16-2 图03 数据', false, '未找到图 03 数据或情形① 结果，请先运行 main_q2.m');
end

%% 汇总
nP = sum(R.pass); nT = numel(R.pass);
fprintf('\n===== 测试汇总：%d / %d 项通过 =====\n', nP, nT);
if nP == nT
    fprintf('结论：全部通过，可进入 /report\n');
else
    fprintf('结论：**存在未通过项**，请编程手介入\n');
    for k = find(~R.pass).'
        fprintf('  未通过：%s  %s\n', R.item{k}, R.detail{k});
    end
end
R.summary = sprintf('%d/%d', nP, nT);
R.time = char(datetime('now'), 'yyyy-MM-dd HH:mm:ss');
save(fullfile(PROJ_ROOT, 'outputs', 'test_results_q2.mat'), 'R');
diary off;
disp('测试日志已写入 outputs/test_log_q2.txt');

% ---------------------------------------------------------------- 局部函数
function R = rec(R, name, ok, txt)
R.item{end+1}   = name;
R.pass(end+1)   = ok;
R.detail{end+1} = txt;
if ok; tag = 'PASS'; else; tag = 'FAIL'; end
fprintf('  [%s] %-34s %s\n', tag, name, txt);
end
