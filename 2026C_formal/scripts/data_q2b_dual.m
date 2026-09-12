% data_q2b_dual.m —— 生成图 04 的绘图数据（组内产物，不交付）
%   图 04 两口径对照_紧急购电与费用：B0（原预测）与 B3（联合校正）在全年、报送窗口两个口径下
%   的实际总费用分解（计划购电费 + 紧急购电费）与紧急购电量
% 说明：原图对照的"完美信息理想基准"属旧时间口径、本轮未重跑，故本图改以 B0 与 B3 作两口径对照，
%       不再出现理想基准数字（见同目录 说明.txt）。
% 数据源：outputs/final_results_q2b_{B0,B3}.mat
% 输出：figures/问题二/04 两口径对照_紧急购电与费用/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

names = {'B0', 'B3'};
[~, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';

R = cell(2, 1);
for k = 1:2
    S = load(fullfile(PROJ_ROOT, 'outputs', sprintf('final_results_q2b_%s.mat', names{k})));
    R{k} = S.res;
end

rows = zeros(4, 6);
for w = 1:2
    idx = (1:D).';   if w == 2; idx = ri; end
    for k = 1:2
        r = R{k};
        rows((w-1)*2 + k, :) = [w, k, ...
            sum(r.cost_plan(idx))/1e4, sum(r.cost_em(idx))/1e4, ...
            sum(r.cost(idx))/1e4, sum(r.em_m(idx,:), 'all')/1e4];
    end
end
T = table(rows(:,1), rows(:,2), rows(:,3), rows(:,4), rows(:,5), rows(:,6), ...
    'VariableNames', {'win_idx', 'plan_idx', 'plan_cost_wanyuan', 'em_cost_wanyuan', ...
                      'cost_wanyuan', 'em_wankwh'});
d4 = fullfile(PROJ_ROOT, 'figures', '问题二', '04 两口径对照_紧急购电与费用');
if ~exist(d4, 'dir'); mkdir(d4); end
writetable(T, fullfile(d4, 'data.csv'));

wtags = {'全年', '窗口'};
fprintf('=== 图 04 两口径对照（B0 与 B3）===\n');
fprintf('%6s %5s %14s %14s %14s %14s\n', '口径', '方案', '计划购电费', '紧急购电费', '实际总费用', '紧急电量');
for w = 1:2
    for k = 1:2
        v = rows((w-1)*2 + k, :);
        fprintf('%6s %5s %14.2f %14.2f %14.2f %14.1f\n', ...
                wtags{w}, names{k}, v(3), v(4), v(5), v(6));
    end
end
fprintf('已写入 %s\n', fullfile(d4, 'data.csv'));
