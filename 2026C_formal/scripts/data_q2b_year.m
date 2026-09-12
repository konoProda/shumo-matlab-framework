% data_q2b_year.m —— 生成图 01 的绘图数据（组内产物，不交付）
%   图 01 全年购电与弃光：B3（联合校正）逐日的计划购电量、未消纳余电量与实际总费用
% 数据源：outputs/final_results_q2b_B3.mat（第三轮重跑结果；旧口径结果作数）
% 输出：figures/问题二/01 全年购电与弃光/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2b_B3.mat'));
r = S.res;
[~, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
D = numel(day_list);

T = table(day_list, sum(r.buy_m, 2), sum(r.curt_m, 2), r.cost.', ...
    'VariableNames', {'date', 'buy_kwh', 'curt_kwh', 'cost_yuan'});
d1 = fullfile(PROJ_ROOT, 'figures', '问题二', '01 全年购电与弃光');
if ~exist(d1, 'dir'); mkdir(d1); end
writetable(T, fullfile(d1, 'data.csv'));

fprintf('=== 图 01 全年（%d 天，B3）===\n', D);
fprintf('  购电量 %12.1f 万 kWh；未消纳余电 %10.1f 万 kWh；实际总费用 %10.2f 万元\n', ...
        sum(T.buy_kwh)/1e4, sum(T.curt_kwh)/1e4, sum(T.cost_yuan)/1e4);
jan = month(T.date) == 1;
fprintf('  其中一月 %d 天：购电 %8.1f 万 kWh、余电 %6.1f 万 kWh、费用 %8.2f 万元\n', ...
        nnz(jan), sum(T.buy_kwh(jan))/1e4, sum(T.curt_kwh(jan))/1e4, sum(T.cost_yuan(jan))/1e4);
fprintf('  最大日购电 %s（%.0f kWh）；有弃光日数 %d 天\n', ...
        char(T.date(find(T.buy_kwh == max(T.buy_kwh), 1)), 'yyyy-MM-dd'), max(T.buy_kwh), ...
        nnz(T.curt_kwh > 1e-6));
fprintf('已写入 %s\n', fullfile(d1, 'data.csv'));
