% probe_q2c_smoke.m —— 第三轮（7 日滚动 SAA 两阶段 MILP）冒烟验证（不跑全量）
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D = numel(day_list);  T = prm.T;
d0 = find(day_list == datetime(2025,2,1), 1);
cfgBase = struct('gamma',1, 'W',28, 'min_days',5, 'Kfc',4, 'libW',28, 'seed',2026, ...
                 'd_start', d0, 'use_bin', true);

%% 1 执行层：V 与 W 必须分开、守恒、同槽不同时充放
fprintf('1) 执行层分流\n');
% 造两种情形：前 4 小时储能接近满且光伏富余（应同时出现 V 与 W）；其余时段为缺口
E_near_full = prm.E_max - 10;
Gplan  = 800 * ones(T,1);
load_a = 3000 * ones(T,1);
pv_syn = zeros(T,1);
load_a(1:24) = 300;  pv_syn(1:24) = 1000;
o = func_exec_q2c(Gplan, load_a, pv_syn, price_v, E_near_full, prm);
bal = (Gplan + pv_syn + o.D/prm.dt + o.H/prm.dt - o.C/prm.dt - load_a - o.V/prm.dt - o.W/prm.dt) * prm.dt;
fprintf('   功率守恒残差 %.2e kWh；V=%.3f kWh，W=%.3f kWh（须分开统计）\n', ...
        max(abs(bal)), sum(o.V), sum(o.W));
assert(max(abs(bal)) < 1e-9, '执行层功率不守恒');
assert(all(o.C .* o.D < 1e-12), '同槽同时充放');
assert(sum(o.W) > 0 && sum(o.V) > 0, '本算例应同时出现 V 与 W');
% 恒等式：光伏余电 = 充电(光伏) + V；计划剩余 = 充电(计划) + W
pvsur = max(pv_syn - min(pv_syn, load_a), 0);
gleft = Gplan - min(Gplan, load_a - min(pv_syn, load_a));
assert(max(abs(o.V/prm.dt + o.pv2chg - pvsur)) < 1e-9, 'V 恒等式不符');
assert(max(abs(o.W/prm.dt + o.g2chg - gleft)) < 1e-9, 'W 恒等式不符');
assert(sum(o.H) > 0, '缺口时段应出现紧急购电');
fprintf('   首槽：pv2chg=%.1f g2chg=%.1f V=%.1f W=%.1f C=%.1f D=%.1f H=%.1f\n', ...
        o.pv2chg(1), o.g2chg(1), o.V(1), o.W(1), o.C(1), o.D(1), o.H(1));

%% 2 情景生成：抽样可复现、成对、整体、退化路径
fprintf('\n2) 情景生成\n');
arch = func_resid_q2(load_m, pv_m, L1, PV1, 4, d0);
eL = arch.eL;  ePV = arch.ePV;
d = d0 + 30;
Lc = load_m(d:d+6,:);  PVc = pv_m(d:d+6,:);
[Lsc, PVsc, si] = func_scen_q2c(eL, ePV, arch.ok, d, 4, 7, Lc, PVc, 28, 2026);
fprintf('   d=%d：库内 %d 日，抽中 %s（种子 2026）\n', d, si.lib_days, mat2str(si.picked));
assert(size(Lsc,3) == 4 && ~si.degraded, '情景数不符');
[~, ~, si2] = func_scen_q2c(eL, ePV, arch.ok, d, 4, 7, Lc, PVc, 28, 2026);
assert(isequal(si.picked, si2.picked), '同种子抽样不可复现');
% 情景 = 中心 + 该日误差模板
w = 2;  s = si.picked(w);
assert(max(abs(Lsc(:,:,w) - max(0, Lc + eL(s,:))), [], 'all') < 1e-12, '情景构造不符');
assert(min(min(si.picked)) >= max(1, d-28) && max(si.picked) < d, '抽样越界或非因果');
% 退化：制造只有 3 个有效日的场景
okv = false(D,1);  okv(d-3:d-1) = true;
[Lsd, PVd, sid] = func_scen_q2c(eL, ePV, okv, d, 4, 7, Lc, PVc, 28, 2026);
assert(sid.degraded && size(Lsd,3) == 1 && max(abs(Lsd(:,:,1) - Lc), [], 'all') < 1e-12, ...
       '退化路径不符（有效残差不足 max(K,5) 时应退化为 K=1 且情景=中心预测）');
fprintf('   退化路径：有效日 %d < max(K,5)=%d → Keff=%d（情景=中心预测）\n', ...
        sid.lib_days, max(4,5), sid.Keff);

%% 3 两阶段装配：第一阶段非预见性 + 连接约束 + 目标结构
fprintf('\n3) 两阶段装配\n');
[f, ic, A, b, Aeq, beq, lb, ub, aux] = func_build_q2c(price_v, Lsc, PVsc, 6000, prm, true);
assert(numel(aux.iGP) == T, '第一阶段变量应为 T 个且只有一组');
assert(numel(ic) == 4*7*T, '二元变量数应为 K×R×T');
[~, ~, efL] = linprog(f, A, b, Aeq, beq, lb, ub, optimoptions('linprog','Display','off'));
assert(efL == 1, 'LP 松弛未收敛');
fprintf('   列 %d，二元 %d，等式 %d，不等式 %d\n', numel(f), numel(ic), size(Aeq,1), size(A,1));

%% 4 短跑滚动（前 6 天，R=3）
fprintf('\n4) 短跑滚动\n');
cfg = cfgBase;  cfg.d_max = 6;
out = func_roll_q2c(price_v, load_m, pv_m, day_list, L1, PV1, prm, 4, 3, cfg, 1);
fprintf('   6 天费用 %.2f 元；Keff=%s；退化 %d 天；单次求解均值 %.2f s\n', ...
        sum(out.cost), mat2str(out.Keff.'), nnz(out.degraded), mean(out.t_solve));
assert(out.degraded(1), '第 1 天应退化（无有效残差）');
assert(all(out.Keff(1:min(5,6)) == 1), '前 5 天应退化');
fprintf('   逐日间隙 %s\n', mat2str(out.gap(1:6).', 6));
assert(all(out.gap(1:6) < 1e-6), '短跑应全部求得最优');
% 一月按已知：目标日在报告窗口之前时，计划输入 = 实际
assert(max(abs(out.corr.Lraw(1,:) - load_m(1,:))) < 1e-12, '一月目标日未按已知处理');

%% 5 完美信息退化（T6）：情景全为真实数据时，计划应贴近确定性最优
fprintf('\n5) 完美信息退化（T6）\n');
Lp = load_m(60:66,:);  PVp = pv_m(60:66,:);
[f2, ic2, A2, b2, Aeq2, beq2, lb2, ub2, aux2] = func_build_q2c(price_v, Lp, PVp, 6000, prm, true);
x0 = linprog(f2, A2, b2, Aeq2, beq2, lb2, ub2, optimoptions('linprog','Display','off'));
[xM, ZM, efM] = intlinprog(f2, ic2, A2, b2, Aeq2, beq2, lb2, ub2, x0, ...
                           optimoptions('intlinprog','Display','off'));
GP = xM(aux2.iGP);
o = func_exec_q2c(GP, load_m(60,:).', pv_m(60,:).', price_v, 6000, prm);
fprintf('   情景=真实数据时：当日紧急购电 %.4f kWh（理想信息下应为 0）\n', sum(o.H));
assert(sum(o.H) < 1e-6, '完美信息下不应出现紧急购电');

fprintf('\n冒烟验证全部通过\n');

%% 6 第一层理想基准（cfg.ideal）：情景=真实数据、无扰动、紧急购电应为 0
fprintf('\n6) 第一层理想基准\n');
cfgi = cfgBase;  cfgi.ideal = true;  cfgi.gamma = 0;  cfgi.d_max = 3;
oi = func_roll_q2c(price_v, load_m, pv_m, day_list, L1, PV1, prm, 1, 1, cfgi, 1);
fprintf('   3 天：费用 %.2f 元，紧急购电 %.6f kWh，场景数 %d\n', ...
        sum(oi.cost), sum(oi.em_m(:)), oi.Keff(1));
assert(all(oi.Keff(1:3) == 1) && ~oi.degraded(1), '理想层不应走退化路径');
assert(sum(oi.em_m(:)) < 1e-6, '理想信息下紧急购电应为 0');
assert(max(abs(oi.chg_m(:) .* oi.dis_m(:))) < 1e-12, '实际执行层不得同槽同时充放');
fprintf('   冒烟：理想层通过\n');
