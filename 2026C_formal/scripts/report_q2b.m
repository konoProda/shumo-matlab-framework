% report_q2b.m —— 问题二第三轮（预测层偏差校正）诊断与对比报告
% 基于 outputs/final_results_q2b_{B0,B1,B2,B3,M1}.mat，不重跑求解。
% 输出：q2b_metrics.csv（预测层）、q2b_dispatch.csv（调度层）、q2b_timefix.csv（时间修复三步）、
%       q2b_forecast_diag.csv（B0 与 B3 的逐日逐槽预测明细）

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
OUT = fullfile(PROJ_ROOT, 'outputs');
dt = 1/6;
names = {'B0', 'B1', 'B2', 'B3'};
R = cell(1, 4);
for k = 1:4
    S = load(fullfile(OUT, sprintf('final_results_q2b_%s.mat', names{k})));
    R{k} = S.res;
end
[~, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';
wins = struct('tag', {'全年365天', '报送窗口334天'}, 'idx', {(1:D).', ri});

fprintf('\n================ 问题二第三轮 诊断报告 ================\n');

%% A. 预测层（§8.1）——以 B0（原始）与 B3（联合校正）为对照
c0 = R{1}.corr;   c3 = R{4}.corr;
isPV = pv_m > 1e-6;                       % "有光伏时段"的筛选规则：实际光伏 > 0
fprintf('\n【A. 预测层】决策日预测对实际（报送窗口 %d 天）\n', numel(ri));
fprintf('%-26s %12s %12s %12s\n', '指标', 'B0 原始', 'B3 校正后', '变化');

addrow = @(lab, a, b) fprintf('%-26s %12.2f %12.2f %12.2f\n', lab, a, b, b - a);

rL = err_stats(c0.Lraw(ri,:) - load_m(ri,:));
rP = err_stats(c0.PVraw(ri,:) - pv_m(ri,:));
rN = err_stats((c0.Lraw(ri,:) - c0.PVraw(ri,:)) - (load_m(ri,:) - pv_m(ri,:)));
cL = err_stats(c3.Lcor(ri,:) - load_m(ri,:));
cP = err_stats(c3.PVcor(ri,:) - pv_m(ri,:));
cN = err_stats((c3.Lcor(ri,:) - c3.PVcor(ri,:)) - (load_m(ri,:) - pv_m(ri,:)));

addrow('负荷 Bias (kW)',      rL.bias, cL.bias);
addrow('负荷 MAE (kW)',       rL.mae,  cL.mae);
addrow('负荷 RMSE (kW)',      rL.rmse, cL.rmse);
addrow('光伏 Bias (kW)',      rP.bias, cP.bias);
addrow('光伏 MAE (kW)',       rP.mae,  cP.mae);
addrow('光伏 RMSE (kW)',      rP.rmse, cP.rmse);
mk = isPV(ri,:);
eP0 = c0.PVraw(ri,:) - pv_m(ri,:);   eP3 = c3.PVcor(ri,:) - pv_m(ri,:);
mA0 = mean(abs(eP0(mk)), 'all');   mA3 = mean(abs(eP3(mk)), 'all');
addrow('光伏 MAE 仅有光时段 (kW)', mA0, mA3);
addrow('净负荷 Bias (kW)',    rN.bias, cN.bias);
addrow('净负荷 MAE (kW)',     rN.mae,  cN.mae);
addrow('净负荷 RMSE (kW)',    rN.rmse, cN.rmse);
acc0 = sum(max((c0.Lraw(ri,:)-c0.PVraw(ri,:)) - (load_m(ri,:)-pv_m(ri,:)), 0), 'all')*dt/1e4;
acc3 = sum(max((c3.Lcor(ri,:)-c3.PVcor(ri,:)) - (load_m(ri,:)-pv_m(ri,:)), 0), 'all')*dt/1e4;
addrow('净负荷正误差累计 (万kWh)', acc0, acc3);

% 高峰前连续 1/2/3 小时的累计净负荷误差分布
pk = struct('name', {'早高峰前', '晚高峰前'}, 'start', {49, 109});   % 08:00 / 18:00 对应槽
fprintf('\n高峰前连续 1/2/3 小时累计净负荷误差（kWh，报送窗口逐日分布）\n');
fprintf('%-10s %-6s %10s %10s %10s %10s %10s %10s\n', '高峰', '时长', 'B0 中位', 'B3 中位', 'B0 均值', 'B3 均值', 'B0 P95', 'B3 P95');
for p = 1:numel(pk)
    for k = 1:3
        sl = pk(p).start - 6*k : pk(p).start - 1;
        e0 = sum(((c0.Lraw(ri,sl) - c0.PVraw(ri,sl)) - (load_m(ri,sl) - pv_m(ri,sl))) * dt, 2);
        e3 = sum(((c3.Lcor(ri,sl) - c3.PVcor(ri,sl)) - (load_m(ri,sl) - pv_m(ri,sl))) * dt, 2);
        fprintf('%-10s %-6s %10.1f %10.1f %10.1f %10.1f %10.1f %10.1f\n', pk(p).name, ...
                sprintf('%d 小时', k), median(e0), median(e3), mean(e0), mean(e3), quant(e0,95), quant(e3,95));
    end
end

% 月份 × 小时诊断（事后汇总）
fprintf('\n净负荷误差月度 Bias（kW，B0 → B3）\n');
for mo = 2:12
    mm = month(day_list(ri)) == mo;
    b0 = mean(rNmat(c0.Lraw, c0.PVraw, load_m, pv_m, ri(mm,:)), 'all');
    b3 = mean(rNmat(c3.Lcor, c3.PVcor, load_m, pv_m, ri(mm,:)), 'all');
    fprintf('  %2d 月: %9.1f → %9.1f\n', mo, b0, b3);
end

%% B. 调度层（§8.2）
fprintf('\n【B. 调度层】\n');
rows = {};
load_kwh = @(idx) sum(load_m(idx,:), 'all') * dt;
for k = 1:4
    r = R{k};
    for w = 1:2
        idx = wins(w).idx;
        plan_kwh = sum(r.buy_m(idx,:), 'all');
        plan_cost = sum(r.cost_plan(idx));
        em_kwh = sum(r.em_m(idx,:), 'all');
        em_cost = sum(r.cost_em(idx));
        Emin_d = min(r.Eend_m(idx,:), [], 2);
        floor_h = nnz(r.Eend_m(idx,:) <= 1200 + 1e-6) * dt;
        rows(end+1, :) = {names{k}, wins(w).tag, sum(r.cost(idx)), plan_kwh, plan_cost, ...
            em_kwh, em_cost, nnz(sum(r.em_m(idx,:),2) > 1e-6), nnz(r.em_m(idx,:) > 1e-6), ...
            100*em_kwh/load_kwh(idx), mean(Emin_d), floor_h, ...
            mean(r.Eend_m(idx,48)), mean(r.Eend_m(idx,108)), sum(r.curt_m(idx,:), 'all'), ...
            r.E0_m(idx(1)), r.Eend_m(idx(end),144)}; %#ok<SAGROW>
    end
end
Td = cell2table(rows, 'VariableNames', {'plan','window','cost_total','plan_kwh','plan_cost', ...
    'em_kwh','em_cost','em_days','em_slots','em_share_pct','E_min_mean','floor_hours', ...
    'E_before_morning_peak','E_before_evening_peak','surplus_kwh','E_win_start','E_win_end'});
writetable(Td, fullfile(OUT, 'q2b_dispatch.csv'));
for w = 1:2
    fprintf('\n— %s —\n', wins(w).tag);
    fprintf('%-5s %14s %13s %13s %12s %8s %7s %8s %9s %10s\n', '方案', '实际总费用', ...
        '计划购电费', '紧急购电费', '紧急电量', '紧急日', '紧急槽', '占比%', '日末均值', '触底小时');
    for k = 1:4
        sub = Td(strcmp(Td.plan, names{k}) & strcmp(Td.window, wins(w).tag), :);
        fprintf('%-5s %14.2f %13.2f %13.2f %12.1f %8d %7d %8.3f %9.1f %10.1f\n', names{k}, ...
            sub.cost_total, sub.plan_cost, sub.em_cost, sub.em_kwh, sub.em_days, sub.em_slots, ...
            sub.em_share_pct, sub.E_min_mean, sub.floor_hours);
    end
end

%% C. 时间修复三步对比
fprintf('\n【C. 时间口径修复的三步对比】\n');
fixfile = fullfile(OUT, 'q2b_timefix.csv');
haveM1 = exist(fullfile(OUT, 'final_results_q2b_M1.mat'), 'file') > 0;
lab = {'旧口径（预测一月+旧时间）', '新一月规则+电价相位已修', '再修首日首槽（=B0）'};
cost_y = [NaN NaN NaN];  cost_w = [NaN NaN NaN];  em_y = [NaN NaN NaN];
if haveM1
    S1 = load(fullfile(OUT, 'final_results_q2b_M1.mat'));   rM = S1.res;
    S0 = load(fullfile(OUT, 'final_results_q2_roll_corr.mat')); rO = S0.res;
    cost_y = [sum(rO.cost), sum(rM.cost), sum(R{1}.cost)];
    cost_w = [sum(rO.cost(ri)), sum(rM.cost(ri)), sum(R{1}.cost(ri))];
    em_y   = [sum(rO.em_m(:)), sum(rM.em_m(:)), sum(R{1}.em_m(:))];
    Tf = table(lab.', cost_y.', cost_w.', em_y.', 'VariableNames', {'stage','cost_year','cost_win','em_kwh_year'});
    writetable(Tf, fixfile);
    fprintf('%-24s %16s %16s %16s\n', '阶段', '全年费用', '窗口费用', '全年紧急电量');
    for k = 1:3
        fprintf('%-24s %16.2f %16.2f %16.1f\n', lab{k}, cost_y(k), cost_w(k), em_y(k));
    end
    fprintf('  一月规则 + 电价相位修复的合并净效果：%+.2f 元（全年，相对旧口径）\n', cost_y(2) - cost_y(1));
    fprintf('  首日首槽修复的净效果：%+.2f 元（全年，相对上一阶段）\n', cost_y(3) - cost_y(2));
else
    fprintf('  （缺少 M1 结果，跳过；先运行 scripts/cmp_q2_timefix.m）\n');
end

%% C2. 分段持留检验（§10-4）：校正收益在后续日期是否保持
fprintf('\n【C2. 分段对照】开发区间（2—4 月）与后续区间（5—12 月）\n');
seg = struct('tag', {'2—4 月', '5—12 月'}, 'sel', {ismember(month(day_list(ri)), 2:4), ...
                                                    ismember(month(day_list(ri)), 5:12)});
fprintf('%-9s %-5s %14s %14s %13s %13s\n', '区间', '方案', '费用', '相对 B0', '紧急电量', '相对 B0');
for s = 1:2
    ii = ri(seg(s).sel);
    base_c = sum(R{1}.cost(ii));  base_e = sum(R{1}.em_m(ii,:), 'all');
    for k = 1:4
        c = sum(R{k}.cost(ii));  e = sum(R{k}.em_m(ii,:), 'all');
        fprintf('%-9s %-5s %14.2f %14.2f %13.1f %13.1f\n', seg(s).tag, names{k}, c, c - base_c, e, e - base_e);
    end
end

%% D. 逐日逐槽预测明细（B0 原始 / B3 校正）
nr  = numel(ri);
hrow = floor((0:143)/6) + 1;                    % 每槽所属小时（1×144）
Tfd = table(repelem(day_list(ri), 144), repmat((1:144).', nr, 1), ...
    'VariableNames', {'date', 'slot'});
Tfd.L_raw  = reshape(c0.Lraw(ri,:).',  [], 1);
Tfd.L_cor  = reshape(c3.Lcor(ri,:).',  [], 1);
Tfd.L_act  = reshape(load_m(ri,:).',   [], 1);
Tfd.PV_raw = reshape(c0.PVraw(ri,:).', [], 1);
Tfd.PV_cor = reshape(c3.PVcor(ri,:).', [], 1);
Tfd.PV_act = reshape(pv_m(ri,:).',    [], 1);
Tfd.bL         = reshape(c3.bL(ri, hrow).',   [], 1);
Tfd.bPV        = reshape(c3.bPV(ri, hrow).',  [], 1);
Tfd.n_valid_L  = reshape(c3.nL(ri, hrow).',   [], 1);
Tfd.lvl_L      = reshape(c3.lvlL(ri, hrow).', [], 1);
Tfd.n_valid_PV = reshape(c3.nPV(ri, hrow).',  [], 1);
Tfd.n_fb       = reshape(repmat(c3.n_fb(ri), 1, 144).', [], 1);
writetable(Tfd, fullfile(OUT, 'q2b_forecast_diag.csv'), 'WriteMode', 'overwrite');

fprintf('\n诊断完成：q2b_dispatch.csv、q2b_timefix.csv、q2b_forecast_diag.csv\n');

%% E. 直出 Markdown 数值块（供回传报告与实现报告直接引用，免手抄）
fid = fopen(fullfile(OUT, 'q2b_handback_tables.md'), 'w', 'n', 'UTF-8');
mk = @(varargin) fprintf(fid, varargin{:});
mk('# 问题二第三轮 数值块（程序直出）\n\n> 由 scripts/report_q2b.m 生成，所有数字取自 outputs/ 下的结果文件。\n\n');

mk('## 表A 时间口径修复的三步对比（重解实测）\n\n');
mk('| 阶段 | 全年费用 | 相对上一阶段 | 报送窗口费用 | 全年紧急电量 |\n|---|---|---|---|---|\n');
if haveM1
    for k = 1:3
        d = [NaN, cost_y(2) - cost_y(1), cost_y(3) - cost_y(2)];
        if k == 1; s = '—'; else; s = sprintf('%+.2f 元', d(k)); end
        mk('| %s | %.2f | %s | %.2f | %.1f |\n', lab{k}, cost_y(k), s, cost_w(k), em_y(k));
    end
end
mk('\n');

for w = 1:2
    mk('## 表B%d B0~B3（%s）\n\n', w, wins(w).tag);
    mk('| 方案 | 实际总费用 | 计划购电费 | 紧急购电费 | 紧急电量 | 紧急天数 | 紧急槽数 | 紧急占负荷 | 日末均值 | 触底小时 |\n');
    mk('|---|---|---|---|---|---|---|---|---|---|\n');
    for k = 1:4
        sub = Td(strcmp(Td.plan, names{k}) & strcmp(Td.window, wins(w).tag), :);
        mk('| %s | %.2f | %.2f | %.2f | %.1f | %d | %d | %.3f%% | %.1f | %.1f |\n', ...
           names{k}, sub.cost_total, sub.plan_cost, sub.em_cost, sub.em_kwh, sub.em_days, ...
           sub.em_slots, sub.em_share_pct, sub.E_min_mean, sub.floor_hours);
    end
    mk('\n');
end

mk('## 表C 预测层精度（报送窗口 334 天）\n\n');
mk('| 指标 | B0 原始 | B3 校正后 | 变化 |\n|---|---|---|---|\n');
mk('| 负荷 Bias (kW) | %.2f | %.2f | %.2f |\n', rL.bias, cL.bias, cL.bias - rL.bias);
mk('| 负荷 MAE (kW) | %.2f | %.2f | %.2f |\n', rL.mae, cL.mae, cL.mae - rL.mae);
mk('| 负荷 RMSE (kW) | %.2f | %.2f | %.2f |\n', rL.rmse, cL.rmse, cL.rmse - rL.rmse);
mk('| 光伏 Bias (kW) | %.2f | %.2f | %.2f |\n', rP.bias, cP.bias, cP.bias - rP.bias);
mk('| 光伏 MAE (kW) | %.2f | %.2f | %.2f |\n', rP.mae, cP.mae, cP.mae - rP.mae);
mk('| 光伏 RMSE (kW) | %.2f | %.2f | %.2f |\n', rP.rmse, cP.rmse, cP.rmse - rP.rmse);
mk('| 光伏 MAE 仅有光时段 (kW) | %.2f | %.2f | %.2f |\n', mA0, mA3, mA3 - mA0);
mk('| 净负荷 Bias (kW) | %.2f | %.2f | %.2f |\n', rN.bias, cN.bias, cN.bias - rN.bias);
mk('| 净负荷 MAE (kW) | %.2f | %.2f | %.2f |\n', rN.mae, cN.mae, cN.mae - rN.mae);
mk('| 净负荷 RMSE (kW) | %.2f | %.2f | %.2f |\n', rN.rmse, cN.rmse, cN.rmse - rN.rmse);
mk('| 净负荷正误差累计 (万kWh) | %.2f | %.2f | %.2f |\n\n', acc0, acc3, acc3 - acc0);

mk('## 表D 分段对照（开发区间 vs 后续区间）\n\n');
mk('| 区间 | 方案 | 费用 | 相对 B0 | 紧急电量 | 相对 B0 |\n|---|---|---|---|---|---|\n');
for s = 1:2
    ii = ri(seg(s).sel);
    base_c = sum(R{1}.cost(ii));  base_e = sum(R{1}.em_m(ii,:), 'all');
    for k = 1:4
        c = sum(R{k}.cost(ii));  e = sum(R{k}.em_m(ii,:), 'all');
        mk('| %s | %s | %.2f | %+.2f | %.1f | %+.1f |\n', seg(s).tag, names{k}, c, c - base_c, e, e - base_e);
    end
end
mk('\n## 表E 净负荷误差月度 Bias（kW，B0 → B3）\n\n| 月份 | B0 | B3 |\n|---|---|---|\n');
for mo = 2:12
    mm = month(day_list(ri)) == mo;
    mk('| %d 月 | %.1f | %.1f |\n', mo, ...
       mean(rNmat(c0.Lraw, c0.PVraw, load_m, pv_m, ri(mm,:)), 'all'), ...
       mean(rNmat(c3.Lcor, c3.PVcor, load_m, pv_m, ri(mm,:)), 'all'));
end
mk('\n## 运行环境\n\n校正窗口达标日数：B0/B1/B2/B3 = %d / %d / %d / %d 天（窗口内残差日数达 5 日才算达标；\n', ...
   nnz(R{1}.corr.on), nnz(R{2}.corr.on), nnz(R{3}.corr.on), nnz(R{4}.corr.on));
mk('B0 的 γ 为 0，即使达标也不施加校正）。\n窗口内残差日数最大值 %d 日；校正通道启用起始日 %s。\n', ...
   max(R{1}.corr.n_win), char(day_list(find(R{4}.corr.on, 1)), 'yyyy-MM-dd'));
fclose(fid);
fprintf('数值块已写入 outputs/q2b_handback_tables.md\n');

%% ---------------------------------------------------------------- 局部函数
function s = err_stats(e)
s = struct('bias', mean(e, 'all'), 'mae', mean(abs(e), 'all'), ...
           'rmse', sqrt(mean(e.^2, 'all')));
end

function e = rNmat(L, PV, La, PVa, idx)
e = (L(idx,:) - PV(idx,:)) - (La(idx,:) - PVa(idx,:));
end

function q = quant(x, p)
% 分位数（不依赖统计工具箱）：线性插值定义
x = sort(x(:));
n = numel(x);
if n == 1; q = x; return; end
pos = 1 + (n - 1) * p / 100;
lo = floor(pos);  hi = min(lo + 1, n);
q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
