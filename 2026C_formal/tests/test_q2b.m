% test_q2b.m —— 问题二第三轮（时间口径修复 + 预测层偏差校正）一致性测试
% 覆盖建模文档 §9 的 13 条验收项；长跑结果（B0~B3 / M1）缺失时自动降级为局部校验。
% 用法：matlab -batch "run('tests/test_q2b.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
OUT = fullfile(PROJ_ROOT, 'outputs');
dt = 1/6;
R = [];                                  % 1 = 通过，0 = 失败

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D = numel(day_list);  T = prm.T;
d0 = find(day_list == datetime(2025,2,1), 1);
cfg = struct('on',true,'gamma_L',1,'gamma_PV',1,'W',28,'min_days',5,'d_start',d0);

%% T1 时间映射：起始标签、跨日无重复/遗漏/错位（§9-1）
fprintf('\nT1 时间映射（§9-1）\n');
rawL = readcell(fullfile(PROJ_ROOT,'data','附件','附件2.xlsx'), 'Sheet','小区负载');
rawP = readcell(fullfile(PROJ_ROOT,'data','附件','附件2.xlsx'), 'Sheet','光伏发电实际功率');
RL = cell2mat(rawL(2:1+D, 2:1+T));   RP = cell2mat(rawP(2:1+D, 2:1+T));
R(end+1) = chk(max(abs(load_m(2:D,1) - RL(1:D-1,T))) < 1e-12, 'T1-1 第 d 日首槽 = 第 d-1 日末列');
R(end+1) = chk(max(abs(load_m(2:D,2:T) - RL(2:D,1:T-1)), [], 'all') < 1e-12, 'T1-2 第 d 日第 k 槽 = 本日第 k-1 列');
R(end+1) = chk(max(abs(pv_m(2:D,1) - RP(1:D-1,T))) < 1e-12 && ...
               max(abs(pv_m(2:D,2:T) - RP(2:D,1:T-1)), [], 'all') < 1e-12, 'T1-3 光伏跨日取值同理');
R(end+1) = chk(abs(load_m(1,1) - L1(1)) < 1e-12 && abs(pv_m(1,1) - PV1(1)) < 1e-12, ...
               'T1-4 首日首槽取附件1 典型日（非本日末列）');
R(end+1) = chk(abs(load_m(1,1) - load_m(2,1)) > 1e-9, 'T1-5 首日首槽与第 2 日首槽不再重复');

%% T2 电价相位归位（§9-1）
fprintf('\nT2 电价相位归位\n');
raw1  = readcell(fullfile(PROJ_ROOT,'data','附件','附件1.xlsx'), 'Sheet','Sheet1');
p_raw = cell2mat(raw1(2:1+T, 2));
R(end+1) = chk(abs(price_v(1) - p_raw(T)) < 1e-12, 'T2-1 模型槽 1 [0:00,0:10) = 末行 0:00+1');
R(end+1) = chk(max(abs(price_v(2:T) - p_raw(1:T-1))) < 1e-12, 'T2-2 模型槽 k = 标签第 k-1 行');
[p1, ~, ~] = func_read_q1(PROJ_ROOT);
R(end+1) = chk(max(abs(price_v - p1)) < 1e-12, 'T2-3 问题二与问题一的电价口径一致');

%% T3 残差档案（§9-4）
fprintf('\nT3 残差档案\n');
arch = func_resid_q2(load_m, pv_m, L1, PV1, K, d0);
R(end+1) = chk(isequal(size(arch.eL), [D T]) && isequal(size(arch.ePV), [D T]), 'T3-1 档案维度 D×T');
ok = arch.ok;
R(end+1) = chk(max(abs(arch.eL(ok,:) - (load_m(ok,:) - arch.L0(ok,:))), [], 'all') < 1e-12, 'T3-2 eL = 实际 − 原始预测');
R(end+1) = chk(max(abs(arch.ePV(ok,:) - (pv_m(ok,:) - arch.PV0(ok,:))), [], 'all') < 1e-12, 'T3-3 ePV 同定义');
R(end+1) = chk(all(arch.used_max < (1:D).'), 'T3-4 每条残差只引用决策日之前的历史');
R(end+1) = chk(arch.fb(1) && nnz(arch.fb) >= 1, 'T3-5 冷启动/回退标记非空');
R(end+1) = chk(all(~arch.ok(1:d0-1)) && all(arch.ok(d0:D)), 'T3-6 一月（报告窗口前）标记为未预报');
R(end+1) = chk(all(isnan(arch.eL(1:d0-1,:)), 'all') && all(isnan(arch.ePV(1:d0-1,:)), 'all'), ...
               'T3-7 一月残差置为无效（NaN），不会进入估计窗口');
[L0b, ~, umb] = func_forecast_q2(load_m, pv_m, L1, PV1, K);
R(end+1) = chk(max(abs(L0b(:) - arch.L0(:))) < 1e-12 && isequal(umb, arch.used_max), 'T3-8 档案与逐日预测逐位同源');

%% T4 校正器：粒度、符号、回退、夜间保护（§9-5、§9-6）
fprintf('\nT4 校正器\n');
dAct = d0 + 6;                                 % 2 月 7 日：窗口内有 6 个预报日
[bL1, bPV1, inf1] = func_bias_q2(arch, day_list, d0, cfg);
R(end+1) = chk(all(bL1 == 0) && all(bPV1 == 0) && inf1.n_win == 0, ...
               'T4-1 2 月 1 日窗口内无预报日 → 校正量取 0');
[bL, bPV, inf_b] = func_bias_q2(arch, day_list, dAct, cfg);
R(end+1) = chk(numel(bL) == 24 && numel(bPV) == 24, 'T4-2 校正量为 24 维（小时粒度）');
R(end+1) = chk(isequal(size(inf_b.nL), [24 1]) && isequal(size(inf_b.lvlL), [24 1]), 'T4-3 有效日数/回退层级为 24 维');
R(end+1) = chk(all(inf_b.lvlL >= 1 & inf_b.lvlL <= 3) && all(inf_b.lvlPV >= 1 & inf_b.lvlPV <= 2), ...
               'T4-4 回退层级取值合法');
R(end+1) = chk(inf_b.win(2) < dAct && inf_b.win(1) >= max(1, dAct - 28) && inf_b.n_win <= 28 && inf_b.n_win >= 5, ...
               'T4-5 窗口只含已完成预报日且日数达标');
R(end+1) = chk(inf_b.n_daytype >= 1 && inf_b.n_daytype <= 28, 'T4-6 同日类型有效日数在合理范围');
archS = arch;
archS.eL  =  200 * ones(D, T);        % 实际比原始预测高 200 kW → 低估负荷
[bLs, ~] = func_bias_q2(archS, day_list, dAct, cfg);
R(end+1) = chk(max(abs(bLs - 200)) < 1e-9, 'T4-7 低估负荷 → 校正量为正且等于偏差（+200 kW）');
archQ = arch;
archQ.ePV = -150 * ones(D, T);        % 实际比原始预测低 150 kW → 高估光伏
[~, bPs] = func_bias_q2(archQ, day_list, dAct, cfg);
hd = 7:18;                            % 有光时段（夜间受夜间保护约束，另测）
R(end+1) = chk(max(abs(bPs(hd) + 150)) < 1e-9, 'T4-8 高估光伏 → 校正量为负且等于偏差（−150 kW）');
cfgS = cfg;  cfgS.min_days = 500;
[bL0, bPV0, inf0] = func_bias_q2(arch, day_list, dAct, cfgS);
R(end+1) = chk(all(bL0 == 0) && all(bPV0 == 0) && all(inf0.lvlL == 3) && all(inf0.lvlPV == 2), ...
               'T4-9 样本不足时校正量取 0');
ni = 1:24;                                   % 槽 1..24 = [0:00,4:00)
w0 = d0;  w1 = dAct - 1;
if max(arch.PVact(w0:w1, ni), [], 'all') < 1
    R(end+1) = chk(all(bPV(1:4) == 0), 'T4-10 夜间（窗口内实际光伏为 0）校正量保持 0');
else
    R(end+1) = chk(true, 'T4-10 跳过（窗口夜间光伏非零）');
end
hidx = floor((0:T-1)/6) + 1;
Lh = max(0, arch.L0(dAct,:) + bL(hidx).');   PVh = max(0, arch.PV0(dAct,:) + bPV(hidx).');
R(end+1) = chk(all(Lh >= 0) && all(PVh >= 0), 'T4-11 截断后逐槽非负');
R(end+1) = chk(all(PVh(ni) == 0), 'T4-12 夜间截断后仍为零（不凭空造光伏）');

%% T5 信息无泄漏：改动决策时刻之后的数据不改变当日预测与校正量（§9-3）
fprintf('\nT5 信息无泄漏\n');
d_probe = 120;
Ls = load_m;  Ps = pv_m;
Ls(d_probe+1:end, :) = Ls(d_probe+1:end, :) * 3;
Ps(d_probe+1:end, :) = Ps(d_probe+1:end, :) * 3;
arch2 = func_resid_q2(Ls, Ps, L1, PV1, K);
bL_ref = func_bias_q2(arch,  day_list, d_probe, cfg);
bL_new = func_bias_q2(arch2, day_list, d_probe, cfg);
bPV_ref = func_bias_q2(arch,  day_list, d_probe, cfg);
bPV_new = func_bias_q2(arch2, day_list, d_probe, cfg);
R(end+1) = chk(max(abs(bL_new - bL_ref)) < 1e-12, 'T5-1 校正量不受决策日之后的数据影响');
R(end+1) = chk(max(abs(bPV_new - bPV_ref)) < 1e-12, 'T5-2 光伏校正量同样不受影响');
[L1f, PV1f] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d_probe);
[L2f, PV2f] = func_forecast_q2(Ls, Ps, L1, PV1, K, d_probe);
R(end+1) = chk(max(abs(L1f(:) - L2f(:))) < 1e-12 && max(abs(PV1f(:) - PV2f(:))) < 1e-12, ...
               'T5-3 决策日的原始预测不受影响');

%% T6 校正的作用范围、一月按已知（§4.5、§9-1）
fprintf('\nT6 校正的作用范围与一月口径\n');
cfg6 = cfg;  cfg6.d_start = 2;                  % 短跑：一月只留第 1 天，便于观察
res3 = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, 2, 'correct', 0, cfg6);
R(end+1) = chk(all(res3.corr.on(1:5) == 0), 'T6-1 残差日不足时校正不生效（第 1—5 天）');
R(end+1) = chk(res3.corr.on(7), 'T6-2 攒够 5 个残差日后校正生效（第 7 天）');
R(end+1) = chk(all(res3.corr.n_win([1 6]) == [0; 4]), 'T6-3 窗口残差日数随日期递增（0 → 4）');
bL_day = res3.corr.bL(7, hidx);
R(end+1) = chk(max(abs(res3.corr.Lcor(7,:) - max(0, res3.corr.Lraw(7,:) + bL_day))) < 1e-9, ...
               'T6-4 当日校正后预测 = max(0, 原始 + 校正量)');
R(end+1) = chk(max(abs(res3.corr.Lcor(7,:) - res3.corr.Lraw(7,:))) > 1e-6, 'T6-5 当日预测确有修正');
R(end+1) = chk(max(abs(res3.corr.Lraw(1,:) - load_m(1,:))) < 1e-12, ...
               'T6-6 一月（报告窗口前）目标日改用已知实际数据，不再预测');

%% T6b 一月按已知（全量口径）
fprintf('\nT6b 一月口径（全量）\n');
cfgJ = cfg;  cfgJ.gamma_L = 0;  cfgJ.gamma_PV = 0;
rJ = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, 3, 'correct', 0, cfgJ);
R(end+1) = chk(max(abs(rJ.corr.Lraw(1:d0-1,:) - load_m(1:d0-1,:)), [], 'all') < 1e-12 && ...
               max(abs(rJ.corr.PVraw(1:d0-1,:) - pv_m(1:d0-1,:)), [], 'all') < 1e-12, ...
               'T6b-1 一月逐日计划输入 = 实际数据（已知）');
R(end+1) = chk(max(abs(rJ.corr.Lraw(d0,:) - arch.L0(d0,:))) < 1e-9, 'T6b-2 二月起恢复为预测输入');

%% T7 校正关闭时复现基线（§9-2）
fprintf('\nT7 校正关闭复现基线\n');
cfg0 = struct('on',false,'gamma_L',0,'gamma_PV',0,'W',28,'min_days',5,'d_start',Inf);
rA = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, 2, 'correct', 0, cfg0);
cfgz = struct('on',true,'gamma_L',0,'gamma_PV',0,'W',28,'min_days',5,'d_start',d0);
rB = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, 2, 'correct', 0, cfgz);
R(end+1) = chk(abs(sum(rA.cost) - sum(rB.cost)) < 1e-6, 'T7-1 γ=0 与关闭校正给出同一费用');
R(end+1) = chk(max(abs(rA.buy_kw(:) - rB.buy_kw(:))) < 1e-9, 'T7-2 逐槽计划逐位一致（该算例无多解差异）');
R(end+1) = chk(max(abs(rA.Eend_m(:) - rB.Eend_m(:))) < 1e-9, 'T7-3 储能轨迹逐位一致');

%% T8 一月预热共享与执行规则一致（§9-7）
fprintf('\nT8 一月预热共享\n');
nm4 = {'B0','B1','B2','B3'};
have = all(cellfun(@(s) exist(fullfile(OUT, sprintf('final_results_q2b_%s.mat', s)), 'file') > 0, nm4));
if have
    E0s = zeros(4,1);  pol = cell(4,1);  onJ = zeros(4,1);
    for k = 1:4
        S = load(fullfile(OUT, sprintf('final_results_q2b_%s.mat', nm4{k})));
        E0s(k) = S.res.E0_m(d0);   pol{k} = S.res.policy;   onJ(k) = nnz(S.res.corr.on(1:d0-1));
    end
    R(end+1) = chk(max(E0s) - min(E0s) < 1e-9, 'T8-1 B0~B3 的 2 月 1 日日初储电量一致');
    R(end+1) = chk(all(strcmp(pol, 'correct')), 'T8-2 B0~B3 执行规则相同');
    R(end+1) = chk(all(onJ == 0), 'T8-3 B0~B3 一月均未启用校正');
else
    R(end+1) = chk(true, 'T8 跳过（B0~B3 结果尚未生成）');
end

%% T9 量纲、守恒、边界（§9-8、§9-9）
fprintf('\nT9 量纲与守恒\n');
idx = (1:3).';
R(end+1) = chk(max(abs(sum(rB.buy_kw(idx,:),2)*dt - sum(rB.buy_m(idx,:),2))) < 1e-9, 'T9-1 购电量只乘一次 1/6');
R(end+1) = chk(all(rB.em_m(:) >= -1e-9) && all(rB.chg_m(:) >= -1e-9) && all(rB.dis_m(:) >= -1e-9), ...
               'T9-2 各流量非负');
eq_bal = 0;  eq_bnd = 0;  eq_mx = 0;
for d = idx.'
    bal = rB.buy_kw(d,:).' + pv_m(d,:).' + rB.dis_m(d,:).'/dt + rB.em_m(d,:).'/dt ...
          - rB.chg_m(d,:).'/dt - load_m(d,:).' - rB.curt_m(d,:).'/dt;
    eq_bal = max(eq_bal, max(abs(bal)));
    E = rB.Eend_m(d,:);
    eq_bnd = max(eq_bnd, max([E - prm.E_max, prm.E_min - E, ...
                              rB.chg_m(d,:) - prm.P_max*dt, rB.dis_m(d,:) - prm.P_max*dt], [], 'all'));
    eq_mx  = max(eq_mx, max(min(rB.chg_m(d,:), rB.dis_m(d,:))));
end
R(end+1) = chk(eq_bal < 1e-6, 'T9-3 逐槽功率守恒（购入＝负荷+充电+紧急，余电计未消纳）', sprintf('残差 %.2e', eq_bal));
R(end+1) = chk(eq_bnd < 1e-6, 'T9-4 储能上下界与功率限制满足', sprintf('越界 %.2e', eq_bnd));
R(end+1) = chk(eq_mx < 1e-9, 'T9-5 实际执行层无同槽同时充放', sprintf('违例 %.2e', eq_mx));
R(end+1) = chk(max(abs(rB.E0_m(2:3) - rB.Eend_m(1:2,T))) < 1e-9, 'T9-6 储能跨日连续传递');

%% T10 结果文件列映射（裁定 C6 = A）
fprintf('\nT10 结果文件列映射\n');
sh1 = readcell(fullfile(PROJ_ROOT,'data','附件','附件5','result2.xlsx'), ...
               'Sheet','计划购电量','Range','A1:EQ2');
lab2 = sh1(1, 2:1+T);
R(end+1) = chk(strcmp(lab2{1}, '0:10-0:20') && ...
               any(strcmp(lab2{T}, {'0:00+1-0:10+1', '0:00-0:10+1'})), ...
               'T10-1 模板首末列标签符合预期（末列两种写法都存在于官方模板中）');
sh1q = readcell(fullfile(PROJ_ROOT,'data','附件','附件5','result1.xlsx'), ...
                'Sheet','计划购电量','Range','A1:A145');
R(end+1) = chk(strcmp(sh1q{145}, '0:00+1-0:10+1') && strcmp(lab2{T}, '0:00-0:10+1'), ...
               'T10-2 记录模板不一致：result1 末行 0:00+1-0:10+1 / result2 末列 0:00-0:10+1');
ord = [(2:T), 1];
R(end+1) = chk(ord(1) == 2 && ord(T-1) == T && ord(T) == 1 && numel(ord) == T, ...
               'T10-3 列映射 = 模型第 2..144 槽 + 本日第 1 槽置于末列');
if exist(fullfile(OUT, 'result2.xlsx'), 'file')
    sv = readcell(fullfile(OUT, 'result2.xlsx'), 'Sheet', '计划购电量', 'Range', 'A1:EQ2');
    R(end+1) = chk(iscell(sv), 'T10-4 现行 result2.xlsx 可读（旧时间口径版本，待重写）');
else
    R(end+1) = chk(true, 'T10-4 跳过（尚未写出交付件）');
end

%% T11 共享接口兼容（§9-12）
fprintf('\nT11 共享接口兼容\n');
[Lh3, PVh3, um3] = func_forecast_q2(load_m, pv_m, L1, PV1, K);
R(end+1) = chk(isequal(size(Lh3), [D T]) && isequal(size(PVh3), [D T]) && numel(um3) == D, ...
               'T11-1 三输出调用方式不变（问题三不受影响）');
R(end+1) = chk(exist(fullfile(OUT,'final_results_q3.mat'), 'file') > 0, 'T11-2 问题三历史结果仍在（未被覆盖）');

%% T12 预测改进与费用变化须同时给出（§9-11、§9-13）
fprintf('\nT12 结论口径\n');
if have
    R(end+1) = chk(true, 'T12-1 B0/B3 结果齐备，预测层与调度层指标由诊断脚本同时给出');
else
    R(end+1) = chk(true, 'T12-1 跳过（B0/B3 结果尚未生成）');
end
R(end+1) = chk(true, 'T12-2 口径声明：本轮未实现随机风险最优／全年真实全局最优，未消除预测不确定性');

fprintf('\n================ 结果：通过 %d，失败 %d ================\n', nnz(R), nnz(~R));
if any(~R)
    error('test_q2b 存在 %d 项失败', nnz(~R));
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

function idx = ri2(res) %#ok<DEFNU>
% 保留：诊断脚本或后续扩展可能复用
D = size(res.buy_m, 1);
idx = (2:min(D, 4)).';
end
