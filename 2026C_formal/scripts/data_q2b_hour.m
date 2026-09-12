% data_q2b_hour.m —— 生成图 08 的绘图数据（组内产物，不交付）
%   图 08 紧急购电的逐时分布：B0（原预测）与 B3（联合校正）在报送窗口内的紧急购电量按时段汇总
% 数据源：outputs/final_results_q2b_{B0,B3}.mat
% 输出：figures/问题二/08 紧急购电的逐时分布/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

S0 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2b_B0.mat'));
S3 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2b_B3.mat'));
[~, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';      % 报送窗口 334 天
T  = 144;
hr = floor(((0:T-1)*10)/60) + 1;                      % 每槽所属小时（1..24）

em0 = zeros(24,1);  em3 = zeros(24,1);
for t = 1:T
    em0(hr(t)) = em0(hr(t)) + sum(S0.res.em_m(ri,t)) / 1e4;    % 万 kWh
    em3(hr(t)) = em3(hr(t)) + sum(S3.res.em_m(ri,t)) / 1e4;
end
T8 = table((0:23).', em0, em3, 100*em0/sum(em0), 100*em3/sum(em3), ...
    'VariableNames', {'hour', 'em_b0_wankwh', 'em_b3_wankwh', 'b0_pct', 'b3_pct'});
d8 = fullfile(PROJ_ROOT, 'figures', '问题二', '08 紧急购电的逐时分布');
if ~exist(d8, 'dir'); mkdir(d8); end
writetable(T8, fullfile(d8, 'data.csv'));

fprintf('=== 图 08 紧急购电逐时分布（报送窗口 %d 天，万 kWh）===\n', numel(ri));
fprintf('%6s %12s %12s\n', '小时', 'B0', 'B3');
for h = 1:24
    fprintf('%02d:00 %12.3f %12.3f\n', h-1, em0(h), em3(h));
end
fprintf('  合计：B0 %.2f 万 → B3 %.2f 万 kWh\n', sum(em0), sum(em3));
fprintf('  B3 峰值时段 19-21 时合计 %.2f 万 kWh（占其全年 %.1f%%）；B0 同时段 %.2f 万（%.1f%%）\n', ...
        sum(em3(20:22)), 100*sum(em3(20:22))/sum(em3), sum(em0(20:22)), 100*sum(em0(20:22))/sum(em0));
[mx, imx] = max(em3);
fprintf('  B3 最大单时段 %02d:00（%.3f 万 kWh）；B0 最大单时段 %02d:00（%.3f 万 kWh）\n', ...
        imx-1, mx, find(em0 == max(em0))-1, max(em0));
fprintf('已写入 %s\n', fullfile(d8, 'data.csv'));
