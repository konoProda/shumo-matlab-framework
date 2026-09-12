% data_q2b_keydays.m —— 生成图 03 的绘图数据（组内产物，不交付）
%   图 03 指定日期_购电与储能：二分二至四日的逐槽计划购电量与槽末储电量（B3 联合校正）
% 数据源：outputs/final_results_q2b_B3.mat；电价取 func_read_q2 的口径（价格相位已归位）
% 输出：figures/问题二/03 指定日期_购电与储能/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2b_B3.mat'));
r = S.res;
[price_v, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
T = numel(price_v);
KEY = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];

rows = cell(numel(KEY), 1);
for k = 1:numel(KEY)
    d = find(day_list == KEY(k), 1);
    slot = (1:T).';
    hh = floor((slot-1)/6);  m1 = mod((slot-1)*10, 60);
    period = arrayfun(@(h, m) sprintf('%02d:%02d-%02d:%02d', h, m, ...
        floor((h*60+m+10)/60), mod(m+10, 60)), hh, m1, 'UniformOutput', false);
    rows{k} = table(repmat(KEY(k), T, 1), slot, period, price_v, r.buy_m(d,:).', r.Eend_m(d,:).', ...
        'VariableNames', {'date', 'slot', 'period', 'price', 'buy_kwh', 'E_kwh'});
end
T3 = vertcat(rows{:});
d3 = fullfile(PROJ_ROOT, 'figures', '问题二', '03 指定日期_购电与储能');
if ~exist(d3, 'dir'); mkdir(d3); end
writetable(T3, fullfile(d3, 'data.csv'));

fprintf('=== 图 03 指定日期（B3）===\n');
for k = 1:numel(KEY)
    S1 = T3(T3.date == KEY(k), :);
    fprintf('  %s：日购电 %9.1f kWh，日末储电量 %8.1f kWh，最低储电量 %8.1f kWh\n', ...
            char(KEY(k), 'yyyy-MM-dd'), sum(S1.buy_kwh), S1.E_kwh(end), min(S1.E_kwh));
end
fprintf('已写入 %s\n', fullfile(d3, 'data.csv'));
