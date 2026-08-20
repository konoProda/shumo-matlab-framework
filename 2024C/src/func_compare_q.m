function func_compare_q(sol1_c1, sol1_c2, sol_q2, sol_q3, fig_dir)
% func_compare_q —— 三问多维度对比（映射表 5.2 对比框架）
% 输入: 四个方案解（Q1滞销/Q1半价/Q2/Q3）与图目录
% 产出: 图1 总利润对比柱状图（标注数值）；图2 逐年利润折线；图3 三大类面积占比堆叠图
%       （300dpi PNG + EPS，图内标题不带图号）；outputs/compare_q.csv 指标表
% 说明: 参数在此重载（确定性与主流程一致）；数值全部由数据现场计算

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(PROJ_ROOT);
DATA_DIR = fullfile(PROJ_ROOT, 'data');
OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
[plot_area, plot_type, crop_type, plant_raw, stat_raw] = func_load_data(DATA_DIR);
[omega_list, ~] = func_build_omega(plot_type, crop_type);
param = func_build_params(plot_area, plot_type, crop_type, stat_raw, plant_raw, omega_list);
param.delta_min = 0.10;  param.p_disaster = 0.10;
oj = omega_list(:, 2);
grain = ismember(oj, 1:16);  veg = ismember(oj, 17:37);  fungi = ismember(oj, 38:41);

sol_list = {sol1_c1, sol1_c2, sol_q2, sol_q3};
names = {'Q1滞销', 'Q1半价', 'Q2期望', 'Q3期望'};
years = 2024:2030;

% ---- 指标计算（逐方案现场计算，与论文数字同源） ----
profit_total = zeros(4, 1);   profit_year = zeros(4, 7);
revenue_total = zeros(4, 1);  cost_total = zeros(4, 1);
std_total = [nan; nan; std(sol_q2.profit_total_vec); std(sol_q3.profit_total_vec)];
cvar_sum = [nan; nan; sum(sol_q2.cvar_by_year); sum(sol_q3.cvar_by_year)];
area_share = zeros(4, 3);     % 粮食/蔬菜/食用菌 七年累计面积占比
for k = 1:4
    s = sol_list{k};
    if k <= 2
        rev = sum(param.price_i .* s.q_norm + 0.5 * param.price_i .* s.q_disc, 'all');
        cst = sum(param.cost_i .* s.x, 'all');
        profit_year(k, :) = s.profit_by_year';
    else
        rev = sum(s.revenue_scen, 'all') / size(s.revenue_scen, 2);
        cst = sum(s.cost_scen, 'all') / size(s.cost_scen, 2);
        profit_year(k, :) = mean(s.profit_scen, 2)';
    end
    if k <= 2
        profit_total(k) = s.profit_total;
    else
        profit_total(k) = s.profit_mean_total;
    end
    revenue_total(k) = rev;  cost_total(k) = cst;
    area_all = sum(s.x, 2);
    area_share(k, :) = [sum(area_all(grain)), sum(area_all(veg)), sum(area_all(fungi))];
    area_share(k, :) = area_share(k, :) / sum(area_share(k, :)) * 100;
end

% ---- 图1 总利润对比（柱状，标注数值） ----
f1 = figure('Visible', 'off');
b1 = bar(profit_total, 'FaceColor', [0.25 0.55 0.85]);
set(gca, 'XTickLabel', names, 'XTick', 1:4);
ylabel('七年总利润（万元）');
title('三问四方案七年总利润对比');
grid on;
yvals = profit_total / 1e4;
for k = 1:4
    text(k, profit_total(k) * 1.02, sprintf('%.1f', yvals(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9);
end
export_figures(f1, fig_dir, 'compare_profit');

% ---- 图2 逐年利润折线 ----
f2 = figure('Visible', 'off');
plot(years, profit_year(2, :) / 1e4, 'o-', 'LineWidth', 1.5); hold on;
plot(years, profit_year(3, :) / 1e4, 's-', 'LineWidth', 1.5);
plot(years, profit_year(4, :) / 1e4, '^-', 'LineWidth', 1.5);
legend(names(2:4), 'Location', 'best');
xlabel('年份');  ylabel('年利润（万元）');
title('Q1半价 / Q2 / Q3 逐年利润对比');
grid on;
export_figures(f2, fig_dir, 'compare_profit_year');

% ---- 图3 三大类种植面积占比（堆叠柱） ----
f3 = figure('Visible', 'off');
b3 = bar(area_share, 'stacked');
set(gca, 'XTickLabel', names, 'XTick', 1:4);
ylabel('种植面积占比（%）');
legend({'粮食类', '蔬菜类', '食用菌'}, 'Location', 'eastoutside');
title('四方案作物大类种植面积占比');
export_figures(f3, fig_dir, 'compare_area_share');

% ---- 指标表 CSV（数值同源） ----
tbl = table(names', profit_total / 1e4, revenue_total / 1e4, cost_total / 1e4, ...
            std_total / 1e4, cvar_sum / 1e4, ...
            'VariableNames', {'方案', '七年总利润_万元', '总收入_万元', '总成本_万元', ...
                              '总利润情景标准差_万元', 'CVaR损失合计_万元'});
writetable(tbl, fullfile(OUT_DIR, 'compare_q.csv'));
end

function export_figures(fig_handle, fig_dir, name)
% 导出 300dpi PNG + EPS 后立即关闭释放内存
print(fig_handle, fullfile(fig_dir, [name '.png']), '-dpng', '-r300');
print(fig_handle, fullfile(fig_dir, [name '.eps']), '-depsc');
close(fig_handle);
end
