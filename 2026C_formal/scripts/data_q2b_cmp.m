% data_q2b_cmp.m —— 生成图 09、图 10 的绘图数据（组内产物，不交付）
%   图 09 预测校正的四方案对照：B0~B3 在全年与报送窗口两个口径下的费用与紧急购电量
%   图 10 分段收益的时间分布：2—4 月（开发区间）与 5—12 月（评估区间）上 B1~B3 相对 B0 的节省量
% 数据源：outputs/final_results_q2b_{B0,B1,B2,B3}.mat（第三轮重跑结果；旧口径结果不作数）
% 输出：figures/问题二/09 .../data.csv、figures/问题二/10 .../data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

names = {'B0', 'B1', 'B2', 'B3'};
[~, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';      % 报送窗口 334 天

R = cell(4, 1);
for k = 1:4
    S = load(fullfile(PROJ_ROOT, 'outputs', sprintf('final_results_q2b_%s.mat', names{k})));
    R{k} = S.res;
end

%% 图 09：四方案 × 两口径
rows9 = zeros(8, 4);
for k = 1:4
    for w = 1:2
        idx = (1:D).';   if w == 2; idx = ri; end
        rows9((k-1)*2 + w, :) = [k, w, ...
            sum(R{k}.cost(idx))/1e4, sum(R{k}.em_m(idx,:), 'all')/1e4];
    end
end
T9 = table(rows9(:,1), rows9(:,2), rows9(:,3), rows9(:,4), ...
    'VariableNames', {'plan_idx', 'win_idx', 'cost_wanyuan', 'em_wankwh'});
d9 = fullfile(PROJ_ROOT, 'figures', '问题二', '09 预测校正的四方案对照');
if ~exist(d9, 'dir'); mkdir(d9); end
writetable(T9, fullfile(d9, 'data.csv'));

fprintf('=== 图 09 四方案 × 两口径 ===\n');
fprintf('%5s %16s %16s %14s %14s\n', '方案', '全年费用', '窗口费用', '全年紧急电量', '窗口紧急电量');
for k = 1:4
    fprintf('%-5s %16.2f %16.2f %14.1f %14.1f\n', names{k}, rows9((k-1)*2+1,3)*1e4, ...
            rows9((k-1)*2+2,3)*1e4, rows9((k-1)*2+1,4)*1e4, rows9((k-1)*2+2,4)*1e4);
end
fprintf('  全年与窗口的紧急电量之差：%s（元/kWh 口径无关）\n', ...
        mat2str(unique(rows9(1:2:7,4) - rows9(2:2:8,4)), 6));

%% 图 10：分段收益（B0 为基准，正值 = 省钱/少买紧急电）
seg = struct('tag', {'2—4 月（开发区间）', '5—12 月（评估区间）'}, ...
             'sel', {ismember(month(day_list(ri)), 2:4), ismember(month(day_list(ri)), 5:12)});
rows10 = zeros(6, 4);
for s = 1:2
    ii = ri(seg(s).sel);
    c0 = sum(R{1}.cost(ii));   e0 = sum(R{1}.em_m(ii,:), 'all');
    for k = 2:4
        rows10((s-1)*3 + (k-1), :) = [s, k-1, ...
            (c0 - sum(R{k}.cost(ii)))/1e4, (e0 - sum(R{k}.em_m(ii,:), 'all'))/1e4];
    end
end
T10 = table(rows10(:,1), rows10(:,2), rows10(:,3), rows10(:,4), ...
    'VariableNames', {'seg_idx', 'plan_idx', 'save_cost_wanyuan', 'save_em_wankwh'});
d10 = fullfile(PROJ_ROOT, 'figures', '问题二', '10 分段收益的时间分布');
if ~exist(d10, 'dir'); mkdir(d10); end
writetable(T10, fullfile(d10, 'data.csv'));

fprintf('\n=== 图 10 分段收益（正 = 相对 B0 节省）===\n');
for s = 1:2
    fprintf('— %s —\n', seg(s).tag);
    for k = 2:4
        fprintf('  %-4s 费用节省 %9.2f 万元；紧急电量节省 %9.2f 万 kWh\n', names{k}, ...
                rows10((s-1)*3+k-1, 3), rows10((s-1)*3+k-1, 4));
    end
end
fprintf('\n已写入图 09、图 10 两个目录的 data.csv\n');
