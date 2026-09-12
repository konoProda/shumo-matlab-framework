% main_q3_nocorr.m —— 问题三 消融对照：储能严格照计划充放电
% 与 main_q3 的唯一差别在执行层：本入口不做日内纠偏，储能按阶段解出的计划充放电，
% 实际光伏不足时由外网补足充电缺口（即"强行维持原充电计划"）。
% 仅作对照，不写交付文件；正式结果以 main_q3.m 为准。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;
H = Inf;
stages = [true true true true];

%% 数据与滚动求解
[price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D  = size(load_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';

fprintf('=== 问题三 消融对照（照计划充放电，不带纠偏）===\n');
res = func_roll_q3(price_v, load_m, pv_m, day_list, fc3, L1, PV1, prm, K, H, 'plan', stages, 60);
fprintf('  完成，耗时 %.1f min\n', res.time/60);

%% 汇总
fprintf('\n%-26s %18.2f\n', '报送窗口总费用(元)', sum(res.cost(ri)));
fprintf('%-26s %18.2f\n', '  其中: 计划购电费', sum(res.cost_plan(ri)));
fprintf('%-26s %18.2f\n', '  其中: 调整相关费用', sum(res.cost_adj(ri)));
fprintf('%-26s %18.2f\n', '  其中: 紧急购电费', sum(res.cost_em(ri)));
fprintf('%-26s %18.0f\n', '紧急购电量(kWh)', sum(res.em_m(ri,:), 'all'));
fprintf('%-26s %18.1f\n', '弃光/富余(全年 kWh)', sum(res.curt_m(ri,:), 'all'));
fprintf('%-26s %18.1f\n', '日末储电量均值(kWh)', mean(res.Eend_m(ri,end)));

%% 落盘（旁路）
save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3_nocorr.mat'), 'res', 'prm', 'K', 'H');
dly = table(day_list(ri), sum(res.adj_m(ri,:),2), res.cost_plan(ri).', res.cost_adj(ri).', ...
            sum(res.em_m(ri,:),2), res.cost_em(ri).', ...
            'VariableNames', {'date','adj_kwh','cost_plan','cost_adj','em_kwh','cost_em'});
writetable(dly, fullfile(PROJ_ROOT, 'outputs', 'q3_nocorr_daily.csv'));
fprintf('\n明细已写入 outputs/q3_nocorr_daily.csv 与 final_results_q3_nocorr.mat（旁路，不覆盖交付件）。\n');
