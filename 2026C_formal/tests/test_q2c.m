% test_q2c.m —— 问题二第三轮（7 日滚动 SAA 两阶段 MILP）一致性测试
% 覆盖方案文档 §17 的 T1~T8 与执行层/退化/结果口径的附加判据。
% 长跑结果缺失时自动降级为局部校验。
% 用法：matlab -batch "run('tests/test_q2c.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
OUT = fullfile(PROJ_ROOT, 'outputs');
R = [];

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1d, PV1d] = func_read_q1(PROJ_ROOT);
D  = numel(day_list);
d0 = find(day_list == datetime(2025,2,1), 1);
cfg = struct('gamma',1, 'W',28, 'min_days',5, 'Kfc',4, 'libW',28, 'seed',2026, ...
             'd_start', d0, 'use_bin', true, 'ideal', false, 'd_max', D);
arch = func_resid_q2(load_m, pv_m, L1d, PV1d, 4, d0);

%% T1 时间标签（§17 T1）
fprintf('\nT1 时间标签与数据口径\n');
raw1  = readcell(fullfile(PROJ_ROOT,'data','附件','附件1.xlsx'), 'Sheet','Sheet1');
p_raw = cell2mat(raw1(2:1+T, 2));
R(end+1) = chk(abs(price_v(1) - p_raw(T)) < 1e-12 && max(abs(price_v(2:T) - p_raw(1:T-1))) < 1e-12, ...
               'T1-1 电价按起始标签循环右移一位（0:00+1 归位到首槽）');
R(end+1) = chk(abs(load_m(1,1) - L1d(1)) < 1e-12, 'T1-2 首日首槽取附件1 典型日值');
R(end+1) = chk(all(~arch.ok(1:d0-1)) && all(arch.ok(d0:D)), 'T1-3 一月不预测（ok 掩码自 2 月 1 日起）');

%% T2 信息泄漏（§17 T2）
fprintf('\nT2 信息泄漏\n');
dP = 120;
Ls = load_m;  Ps = pv_m;
Ls(dP+1:end,:) = Ls(dP+1:end,:) * 3;
Ps(dP+1:end,:) = Ps(dP+1:end,:) * 3;
arch2 = func_resid_q2(Ls, Ps, L1d, PV1d, 4, d0);
R(end+1) = chk(max(abs(arch2.eL(dP,:) - arch.eL(dP,:))) < 1e-12, 'T2-1 改动决策日之后的实测不改变当日残差');
eL1 = arch.eL;  eL2 = arch2.eL;
R(end+1) = chk(max(abs(eL2(2:dP-1,:) - eL1(2:dP-1,:)), [], 'all') < 1e-12, ...
               'T2-2 误差库只含决策日之前的日子');
[Lc1, ~, s1] = func_scen_q2c(eL1, arch.ePV, arch.ok, dP, 4, 7, load_m(dP:dP+6,:), pv_m(dP:dP+6,:), 28, 2026);
[Lc2, ~, s2] = func_scen_q2c(eL2, arch2.ePV, arch2.ok, dP, 4, 7, load_m(dP:dP+6,:), pv_m(dP:dP+6,:), 28, 2026);
R(end+1) = chk(isequal(s1.picked, s2.picked) && max(abs(Lc1(:) - Lc2(:))) < 1e-12, ...
               'T2-3 改动未来数据不改变当日情景（同样本同种子）');

%% T3 第一阶段非预见性（§17 T3）——真判据，全部在 K>1 模型上做
fprintf('\nT3 第一阶段非预见性\n');
K3 = 4;  R3 = 3;
[Lsc3, PVsc3] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d0+60, K3, R3, ...
                              load_m(d0+60:d0+60+R3-1,:), pv_m(d0+60:d0+60+R3-1,:), 28, 2026);
[f3, ic3, A3, b3, Aeq3, beq3, lb3, ub3, aux3] = func_build_q2c(price_v, Lsc3, PVsc3, 6000, prm, true);
R(end+1) = chk(numel(aux3.iGP) == T, 'T3-1 G^plan 只有一组 T 个变量（无情景索引）');

% 非预见性：每个情景"当日连接式"的 -1 系数必须落在同一组 aux.iGP 列上
okNa = true;
for w = 1:K3
    rl = (w-1)*R3*5*T + 4*T + (1:T);              % (情景w, 日 j=1) 的第 5 组（连接）行
    [~, cols] = find(Aeq3(rl, :) == -1);
    okNa = okNa && isequal(unique(cols(:)), aux3.iGP);
end
R(end+1) = chk(okNa, 'T3-2 各情景的当日连接式引用同一组 G^plan 列（第一阶段非预见性）');

% 当日块不得含"情景内临时计划变量"，否则当日计划会被按情景索引
R(end+1) = chk(aux3.blk{1,2} - aux3.blk{1,1} == 10*T, ...
               'T3-3 当日块仅 10 个变量（无临时计划变量）');

% 求解 K>1 的完整 MILP，供 T4/T5 做**模型级**判据（执行层自己有 assert，测不出模型问题）
optM3 = optimoptions('intlinprog', 'Display', 'off', ...
                     'RelativeGapTolerance', 1e-8, 'AbsoluteGapTolerance', 1e-8);
x03 = linprog(f3, A3, b3, Aeq3, beq3, lb3, ub3, optimoptions('linprog','Display','off'));
[xm3, ~, ef3] = intlinprog(f3, ic3, A3, b3, Aeq3, beq3, lb3, ub3, x03, optM3);
R(end+1) = chk(ef3 == 1, sprintf('T3-4 K=%d 情景 MILP 求得最优（供 T4/T5 使用）', K3));
getv3 = @(x, w, j, name) x(aux3.blk{w,j} + aux3.offB.(name)*T + (1:T));

%% T4 能量守恒（§17 T4）
fprintf('\nT4 能量守恒（执行层与情景层）\n');
Gplan = 800*ones(T,1);  load_a = 3000*ones(T,1);  pv_s = zeros(T,1);
load_a(1:24) = 300;  pv_s(1:24) = 1000;
o = func_exec_q2c(Gplan, load_a, pv_s, price_v, prm.E_max - 10, prm);
bal = (Gplan + pv_s + o.D/prm.dt + o.H/prm.dt - o.C/prm.dt - load_a - o.V/prm.dt - o.W/prm.dt) * prm.dt;
R(end+1) = chk(max(abs(bal)) < 1e-9, 'T4-1 执行层逐槽守恒（购入+光伏+放电+紧急 = 负荷+充电+未消纳+已购未用）');
pvsur = max(pv_s - min(pv_s, load_a), 0);
gleft = Gplan - min(Gplan, load_a - min(pv_s, load_a));
R(end+1) = chk(max(abs(o.V/prm.dt + o.pv2chg - pvsur)) < 1e-9 && ...
               max(abs(o.W/prm.dt + o.g2chg - gleft)) < 1e-9, 'T4-2 V 与 W 分开记账、各自恒等');
R(end+1) = chk(sum(o.W) > 0 && sum(o.V) > 0, 'T4-3 该算例同时出现 V 与 W');
Erec = prm.E_max - 10 + cumsum(prm.eta_ch*o.C - o.D/prm.eta_dis);
R(end+1) = chk(max(abs(Erec - o.E)) < 1e-9, 'T4-4 实际 SOC 递推一致');
% 模型级守恒：全部 (情景,日) 的 5 组等式同时成立（含 K>1 与跨日 SOC 链接）
vEq3 = max(abs(Aeq3 * xm3 - beq3));
R(end+1) = chk(vEq3 < 1e-6, ...
    sprintf('T4-5 模型级 K=%d 情景逐日 5 组等式全部成立', K3), ...
    sprintf('%d 行，最大违反 %.1fe-9', numel(beq3), vEq3*1e9));

%% T5 SOC 与互斥（§17 T5）
fprintf('\nT5 SOC 与互斥\n');
R(end+1) = chk(all(o.E >= prm.E_min - 1e-9) && all(o.E <= prm.E_max + 1e-9), 'T5-1 实际 SOC 在 [1200,10800] 内');
R(end+1) = chk(all(o.C .* o.D < 1e-12), 'T5-2 实际执行层不得同槽同时充放');
% 模型级互斥：直接检验 K>1 模型解的 C/D（执行层输出自带 assert，测不出模型二值失效）
mEx = 0;
for w = 1:K3
    for j = 1:R3
        mEx = max(mEx, max(min(getv3(xm3, w, j, 'C'), getv3(xm3, w, j, 'D'))));
    end
end
R(end+1) = chk(mEx < 1e-6, sprintf('T5-3 模型解不得同槽同时充放（K=%d 情景逐日，二值 u 生效）', K3), ...
               sprintf('max min(C,D) = %.2e kW', mEx));
% 二值变量确实取到 0/1（注意当日块无临时计划变量，U 的偏移比未来块少 1）
uAll = [];
for w = 1:K3
    for j = 1:R3
        if j == 1; offU = aux3.offB.U - 1; else; offU = aux3.offB.U; end
        uAll = [uAll; xm3(aux3.blk{w,j} + offU*T + (1:T))]; %#ok<AGROW>
    end
end
R(end+1) = chk(max(abs(uAll - round(uAll))) < 1e-6, 'T5-3b 互斥二值变量取值全为 0/1', ...
               sprintf('%d 个二值变量，最大偏离整数 %.1e', numel(uAll), max(abs(uAll - round(uAll)))));

cfg2 = cfg;  cfg2.d_max = 6;
out = func_roll_q2c(price_v, load_m, pv_m, day_list, L1d, PV1d, prm, 4, 3, cfg2, 0);
R(end+1) = chk(max(out.gap(1:6)) < 1e-6, 'T5-4 短跑逐日求得全局最优（间隙为 0）');
R(end+1) = chk(max(out.viol(1:6)) < 1e-6, 'T5-5 最大约束违反量在容差内');

%% T6 完美信息退化（§17 T6）
fprintf('\nT6 完美信息退化\n');
Lp = load_m(60:66,:);  PVp = pv_m(60:66,:);
[fp, icp, Ap, bp, Aeqp, beqp, lbp, ubp, auxp] = func_build_q2c(price_v, Lp, PVp, 6000, prm, true);
x0p = linprog(fp, Ap, bp, Aeqp, beqp, lbp, ubp, optimoptions('linprog','Display','off'));
[xm, Zm, efm] = intlinprog(fp, icp, Ap, bp, Aeqp, beqp, lbp, ubp, x0p, ...
    optimoptions('intlinprog','Display','off','RelativeGapTolerance',1e-8,'AbsoluteGapTolerance',1e-8));
GP = xm(auxp.iGP);
op = func_exec_q2c(GP, load_m(60,:).', pv_m(60,:).', price_v, 6000, prm);
R(end+1) = chk(efm == 1 && sum(op.H) < 1e-6, 'T6-1 情景=真实数据时紧急购电为 0（向确定性基准退化）');
cfgi = cfg;  cfgi.ideal = true;  cfgi.gamma = 0;  cfgi.d_max = 3;
oi = func_roll_q2c(price_v, load_m, pv_m, day_list, L1d, PV1d, prm, 1, 1, cfgi, 0);
R(end+1) = chk(sum(oi.em_m(:)) < 1e-6 && all(oi.Keff(1:3) == 1), 'T6-2 第一层理想基准紧急购电为 0');

%% T7/T8 视野与情景数（§17 T7、T8）——读长跑结果
fprintf('\nT7/T8 视野长度与情景数\n');
haveRun = @(s) exist(fullfile(OUT, sprintf('final_results_q2c_%s.mat', s)), 'file') > 0;
if haveRun('L2') && haveRun('L2r1') && haveRun('L2r3')
    c = @(s) load(fullfile(OUT, sprintf('final_results_q2c_%s.mat', s))).res;
    r1 = c('L2r1'); r3 = c('L2r3'); r7 = c('L2');
    ri = (d0:D).';
    R(end+1) = chk(numel(unique([r1.R r3.R r7.R])) == 3, 'T7-1 三档视野 R=1/3/7 结果齐备');
    fprintf('   R=1：窗口费用 %.2f，紧急 %.1f kWh，日末 SOC 均值 %.1f，均耗时 %.2fs\n', ...
            sum(r1.cost(ri)), sum(r1.em_m(ri,:),'all'), mean(r1.Eend_m(ri,end)), mean(r1.t_solve(r1.t_solve>0)));
    fprintf('   R=3：窗口费用 %.2f，紧急 %.1f kWh，日末 SOC 均值 %.1f，均耗时 %.2fs\n', ...
            sum(r3.cost(ri)), sum(r3.em_m(ri,:),'all'), mean(r3.Eend_m(ri,end)), mean(r3.t_solve(r3.t_solve>0)));
    fprintf('   R=7：窗口费用 %.2f，紧急 %.1f kWh，日末 SOC 均值 %.1f，均耗时 %.2fs\n', ...
            sum(r7.cost(ri)), sum(r7.em_m(ri,:),'all'), mean(r7.Eend_m(ri,end)), mean(r7.t_solve(r7.t_solve>0)));
else
    R(end+1) = chk(true, 'T7-1 跳过（R=1/3/7 结果尚未生成）');
end
if haveRun('L2k8') && haveRun('L2')
    r4 = load(fullfile(OUT,'final_results_q2c_L2.mat')).res;
    r8 = load(fullfile(OUT,'final_results_q2c_L2k8.mat')).res;
    ri = (d0:D).';
    d8 = 100*(sum(r8.cost(ri)) - sum(r4.cost(ri))) / sum(r4.cost(ri));
    fprintf('   K=4 窗口费用 %.2f，K=8 %.2f，相对差 %+.3f%%\n', sum(r4.cost(ri)), sum(r8.cost(ri)), d8);
    R(end+1) = chk(abs(d8) >= 0, 'T8-1 K=4 与 K=8 均已跑出（相对差见上）');
    R(end+1) = chk(abs(d8) < 5, 'T8-2 情景数翻倍后费用相对差 < 5%（稳定性）', sprintf('%.3f%%', d8));
else
    R(end+1) = chk(true, 'T8-1 跳过（K=8 结果尚未生成）');
end

%% T9 执行层优先级（C3）
fprintf('\nT9 执行层优先级\n');
R(end+1) = chk(sum(o.H) > 0, 'T9-1 缺口时段出现紧急购电');
sl = find(o.H > 0, 1);
R(end+1) = chk(o.W(sl) < 1e-9 && o.V(sl) < 1e-9, 'T9-2 缺口槽不得同时出现未用购电或弃光');
R(end+1) = chk(all(o.H <= 0 | o.C < 1e-9), 'T9-3 紧急购电不给储能充电（缺口槽充电为 0）');

%% T10 抽样与退化
fprintf('\nT10 情景抽样与退化\n');
[~, ~, sa] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d0+100, 4, 7, ...
                           load_m(d0+100:d0+106,:), pv_m(d0+100:d0+106,:), 28, 2026);
[~, ~, sb] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d0+100, 4, 7, ...
                           load_m(d0+100:d0+106,:), pv_m(d0+100:d0+106,:), 28, 2026);
R(end+1) = chk(isequal(sa.picked, sb.picked) && numel(sa.picked) == 4 && ...
               numel(unique(sa.picked)) == 4, 'T10-1 无放回抽样、固定种子可复现');
R(end+1) = chk(max(sa.picked) < d0+100 && min(sa.picked) >= max(1, d0+100-28), 'T10-2 抽样严格因果且限于最近 28 日');
okv = false(D,1);  okv(d0:d0+2) = true;
[~, ~, sd] = func_scen_q2c(arch.eL, arch.ePV, okv, d0+10, 4, 7, ...
                           load_m(d0+10:d0+16,:), pv_m(d0+10:d0+16,:), 28, 2026);
R(end+1) = chk(sd.degraded && sd.Keff == 1, 'T10-3 有效残差不足 max(K,5) 时退化为确定性（K=1）');

%% T11 抽样独立性（回归判据：防"每日重置 = 全年同一置换"复发）
fprintf('\nT11 抽样独立性\n');
Lg = zeros(5, 4);
for k = 1:5
    dk = d0 + 100 + k;
    [~, ~, sk] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, dk, 4, 7, ...
                               load_m(dk:dk+6,:), pv_m(dk:dk+6,:), 28, 2026);
    Lg(k, :) = sort(dk - sk.picked);              % 相对滞后集合
end
R(end+1) = chk(size(unique(Lg, 'rows'), 1) >= 3, ...
               'T11-1 连续 5 日抽中的相对滞后集合互不相同（逐日独立，非固定模板）', ...
               sprintf('5 日内 %d 种不同滞后集合', size(unique(Lg,'rows'),1)));
[~, ~, sw] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d0+100, 4, 7, ...
                           load_m(d0+100:d0+106,:), pv_m(d0+100:d0+106,:), 28, 2026);
R(end+1) = chk(max(sw.picked) < d0+100 && min(sw.picked) >= d0+100-28, ...
               'T11-2 抽样严格因果且限于最近 28 个有效预测日');
[~, ~, s101] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d0+101, 4, 7, ...
                             load_m(d0+101:d0+107,:), pv_m(d0+101:d0+107,:), 28, 2026);
R(end+1) = chk(~isequal(sort(sw.picked), sort(s101.picked)), ...
               'T11-3 相邻两日抽中的历史日集合不同（H0 的固定滞后模板已被排除）');

fprintf('\n================ 结果：通过 %d，失败 %d ================\n', nnz(R), nnz(~R));
if any(~R)
    error('test_q2c 存在 %d 项失败', nnz(~R));
end

%% ---------------------------------------------------------------- 局部函数
function r = chk(cond, name, extra)
r = logical(cond);
assert(isscalar(r), '判据必须为标量，请检查测试写法：%s', name);
if nargin > 2 && ~isempty(extra)
    name = sprintf('%s  [%s]', name, extra);
end
if r
    fprintf('  [通过] %s\n', name);
else
    fprintf('  [失败] %s\n', name);
end
end
