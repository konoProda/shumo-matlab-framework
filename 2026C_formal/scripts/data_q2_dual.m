% data_q2_dual.m —— 生成图件「问题二 04 两口径对照_紧急购电与费用」的绘图数据
% 组内产物，不交付。数据源：年视野滚动的两个口径结果（见下）
% 输出：figures/问题二/04 两口径对照_紧急购电与费用/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

A = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_plan.mat'));   % 不带纠偏（消融）
B = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_corr.mat'));   % 带纠偏（正式）
[~, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
D  = size(A.res.em_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';
mon = month(day_list(ri));
mm  = (2:12).';

rows = zeros(numel(mm), 6);
for k = 1:numel(mm)
    s = mon == mm(k);
    rows(k,:) = [ sum(A.res.em_m(ri(s),:), 'all'),   sum(B.res.em_m(ri(s),:), 'all'), ...
                  sum(A.res.cost_em(ri(s))),         sum(B.res.cost_em(ri(s))), ...
                  sum(A.res.cost(ri(s))),            sum(B.res.cost(ri(s))) ];
end

T = table(mm, rows(:,1), rows(:,2), rows(:,3), rows(:,4), rows(:,5), rows(:,6), ...
    'VariableNames', {'month', 'em_kwh_plan', 'em_kwh_corr', ...
                      'em_yuan_plan', 'em_yuan_corr', 'tot_yuan_plan', 'tot_yuan_corr'});

out_dir = fullfile(PROJ_ROOT, 'figures', '问题二', '04 两口径对照_紧急购电与费用');
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
writetable(T, fullfile(out_dir, 'data.csv'));

fprintf('=== 两口径对照（年视野滚动，报送窗口 %d 天，逐月）===\n', numel(ri));
fprintf('%6s %14s %14s %14s %14s\n', '月份', '紧急电量/不带', '紧急电量/带', '紧急费/不带', '紧急费/带');
for k = 1:numel(mm)
    fprintf('%4d 月 %14.1f %14.1f %14.1f %14.1f\n', mm(k), rows(k,1), rows(k,2), rows(k,3), rows(k,4));
end
fprintf('\n窗口紧急购电量 %.1f → %.1f 万 kWh（%.1f%%）\n', ...
        sum(rows(:,1))/1e4, sum(rows(:,2))/1e4, 100*(sum(rows(:,2))-sum(rows(:,1)))/sum(rows(:,1)));
fprintf('窗口紧急购电费 %.2f → %.2f 万元；电量加权单价 %.4f → %.4f 元/kWh\n', ...
        sum(rows(:,3))/1e4, sum(rows(:,4))/1e4, sum(rows(:,3))/sum(rows(:,1)), sum(rows(:,4))/sum(rows(:,2)));
fprintf('已写入 %s\n', fullfile(out_dir, 'data.csv'));
