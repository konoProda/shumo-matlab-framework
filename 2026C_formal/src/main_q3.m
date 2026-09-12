% main_q3.m —— 问题三 正式口径：四阶段调整 + 实际运行负载优先
% 计划层：每天 0:00 用附件3 当天预报 + 次日起自建预测，在全年视野上定当天计划；
%         6:00 / 12:00 / 18:00 依次以新预报重解当天剩余时段，只锁定本段
% 结算层：每个槽与当天 0:00 原计划比较（下调 0.5 倍、上调 1.5 倍、紧急 5 倍）
% 执行层：负载优先物理层（光伏直供 → 储能放电 → 仍不足才紧急购电），不强行维持原充电计划
% 本入口写正式交付文件 result3.xlsx；策略对照与消融分别见 main_q3_sens / main_q3_nocorr。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;
H = Inf;                                  % 阶段 0 的视野 = 剩余全年
stages = [true true true true];           % 启用 0:00 / 6:00 / 12:00 / 18:00 四个阶段

%% 数据与滚动求解
[price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D  = size(load_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';

fprintf('=== 问题三 正式口径（四阶段调整 + 负载优先）===\n');
fprintf('  阶段：0:00 全年视野定计划；6:00 / 12:00 / 18:00 重解当天剩余时段；同星期回溯 K=%d 周\n', K);
res = func_roll_q3(price_v, load_m, pv_m, day_list, fc3, L1, PV1, prm, K, H, 'correct', stages, 30);
fprintf('  完成，耗时 %.1f min\n', res.time/60);

%% 结果汇总
fprintf('\n=== 全年结果（报送窗口 2025-02-01 ~ 12-31，%d 天）===\n', numel(ri));
fprintf('%-26s %18.2f\n', '全年总费用(元)', sum(res.cost(ri)));
fprintf('%-26s %18.2f\n', '  其中: 计划购电费', sum(res.cost_plan(ri)));
fprintf('%-26s %18.2f\n', '  其中: 调整相关费用', sum(res.cost_adj(ri)));
fprintf('%-26s %18.2f\n', '  其中: 紧急购电费', sum(res.cost_em(ri)));
fprintf('%-26s %18.0f\n', '计划购电量(kWh)', sum(res.plan_m(ri,:), 'all'));
fprintf('%-26s %18.0f\n', '调整后购电量(kWh)', sum(res.adj_m(ri,:), 'all'));
fprintf('%-26s %18.0f\n', '  其中: 高于计划的部分', sum(res.dP_m(ri,:), 'all'));
fprintf('%-26s %18.0f\n', '  其中: 低于计划的部分', sum(res.dM_m(ri,:), 'all'));
fprintf('%-26s %18.0f\n', '紧急购电量(kWh)', sum(res.em_m(ri,:), 'all'));
fprintf('%-26s %18d\n', '紧急购电出现天数', nnz(sum(res.em_m(ri,:),2) > 1e-6));
fprintf('%-26s %18d\n', '调整发生天数（|Δ|>0）', nnz(sum(abs(res.adj_m(ri,:) - res.plan_m(ri,:)),2) > 1e-6));
fprintf('%-26s %18.1f\n', '弃光/富余(全年 kWh)', sum(res.curt_m(ri,:), 'all'));
fprintf('%-26s %18.1f\n', '储能充电(全年 kWh)', sum(res.chg_m(ri,:), 'all'));
fprintf('%-26s %18.1f\n', '储能放电(全年 kWh)', sum(res.dis_m(ri,:), 'all'));
fprintf('%-26s %18.1f\n', '日末储电量均值(kWh)', mean(res.Eend_m(ri,end)));
fprintf('%-26s %18d\n', '阶段0 同槽同时充放槽数', sum(res.mutex));
fprintf('%-26s %18d\n', '阶段1~3 同槽同时充放槽数', sum(res.mutex_s(:)));

%% 落盘
save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'res', 'prm', 'K', 'H', 'stages');
tab = func_write_q3(res, prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result3.xlsx'), ...
    fullfile(PROJ_ROOT, 'outputs', 'result3.xlsx'));
assert(all(isfinite(tab.t1_total)), '论文表 1 的四个指定日期未全部取到，请检查数据窗口');
save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'tab', '-append');
fprintf('\n结果文件 result3.xlsx 已写出（四阶段 + 负载优先，正式口径）。\n');

fprintf('\n=== 论文表 3 指定日期（最终生效口径）===\n');
for k = 1:4
    fprintf('  %s  全天购电量 %9.1f kWh  总费用 %10.2f 元（计划 %9.2f / 调整 %8.2f / 紧急 %9.2f）\n', ...
            tab.date_str{k}, tab.t1_total(k), tab.t1_cost(k), ...
            tab.cost_plan(k), tab.cost_adj(k), tab.cost_em(k));
end

dly = table(day_list(ri), sum(res.plan_m(ri,:),2), sum(res.adj_m(ri,:),2), ...
            res.cost_plan(ri).', res.cost_adj(ri).', ...
            sum(res.em_m(ri,:),2), res.cost_em(ri).', mean(res.Eend_m(ri,:),2), ...
            'VariableNames', {'date','plan_kwh','adj_kwh','cost_plan','cost_adj','em_kwh','cost_em','Eend_mean'});
writetable(dly, fullfile(PROJ_ROOT, 'outputs', 'q3_daily.csv'));
fprintf('明细：outputs/q3_daily.csv 与 final_results_q3.mat\n');
