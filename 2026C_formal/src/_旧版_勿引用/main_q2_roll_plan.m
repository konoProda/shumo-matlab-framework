% main_q2_roll_plan.m —— 问题二 年视野·不带纠偏（消融对照）
% 与 main_q2_roll_corr 的唯一区别在执行层：储能严格按 0:00 计划充放电，
% 即【去掉"负载优先"这一物理层】，只保留经济层。
% 这正是消融对照要暴露的：储能为经济上的储电安排而动作时，
% 若实际光伏富余未实现，它会在负载短缺的同时段照充不误——该行为非物理，
% 故本入口只作对照，不作正式口径。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;
H = Inf;                                  % 全年视野（视界 = 剩余天数）

%% 数据与滚动求解
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D  = size(load_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';

fprintf('=== 问题二 年视野·不带纠偏（消融对照）===\n');
fprintf('  视界：全年滚动（每天重解剩余全年，只执行当天）；同星期回溯 K=%d 周\n', K);
res = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, H, 'plan', 30);
fprintf('  完成，耗时 %.1f min\n', res.time/60);

%% 结果汇总
Z1y_win = 12182837.88;   Z1y_year = 13708240.22;    % 理想·全年联合（完美信息下界）
Z1d_win = 12210827.42;
fprintf('\n%-24s %16s\n', '指标', '年视野·不带纠偏');
fprintf('%-24s %16.2f\n', '全年总费用(元)', sum(res.cost));
fprintf('%-24s %16.2f\n', '报送窗口总费用(元)', sum(res.cost(ri)));
fprintf('%-24s %16.2f\n', '  计划购电费(全年)', sum(res.cost_plan));
fprintf('%-24s %16.2f\n', '  紧急购电费(全年)', sum(res.cost_em));
fprintf('%-24s %16.0f\n', '紧急购电量(全年 kWh)', sum(res.em_m(:)));
fprintf('%-24s %16d\n', '紧急购电出现天数', nnz(sum(res.em_m,2)>1e-6));
fprintf('%-24s %16d\n', '紧急购电出现槽数', nnz(res.em_m(:)>1e-6));
fprintf('%-24s %16.1f\n', '弃光/富余(全年 kWh)', sum(res.curt_m(:)));
fprintf('%-24s %16.1f\n', '储能充电(全年 kWh)', sum(res.chg_m(:)));
fprintf('%-24s %16.1f\n', '储能放电(全年 kWh)', sum(res.dis_m(:)));
fprintf('%-24s %16.1f\n', '日末储电量均值(kWh)', mean(res.Eend_m(:,end)));
fprintf('%-24s %16d\n', '计划解同槽同时充放槽数', sum(res.mutex));
fprintf('\n  信息价值 VoI：对理想·全年 %.2f%% ；对理想·逐日 %.2f%%\n', ...
        100*(sum(res.cost(ri)) - Z1y_win)/Z1y_win, 100*(sum(res.cost(ri)) - Z1d_win)/Z1d_win);

%% 落盘（消融对照不写结果文件）
save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_plan.mat'), 'res', 'prm', 'K', 'H');
dly = table(day_list(ri), sum(res.buy_m(ri,:),2), sum(res.em_m(ri,:),2), ...
            res.cost(ri).', res.cost_em(ri).', mean(res.Eend_m(ri,:),2), ...
            'VariableNames', {'date','buy_kwh','em_kwh','cost_yuan','em_cost_yuan','Eend_mean'});
writetable(dly, fullfile(PROJ_ROOT, 'outputs', 'q2_roll_plan_daily.csv'));
fprintf('\n明细：outputs/q2_roll_plan_daily.csv 与 final_results_q2_roll_plan.mat\n');
