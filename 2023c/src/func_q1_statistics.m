function stats_q1 = func_q1_statistics(prod_info, PROJ_ROOT, save_figs)
% =========================================================================
% func_q1_statistics.m — 问题1: 品类/单品销量分布规律与关联分析（建模文档第3节）
% 公式(3.2): q_{i,t} = 第 i 类/单品第 t 天销量(kg), 未售出填 0
% 公式(3.3): rho_ij = 1 - 6*Σ(R_i(t)-R_j(t))^2 / (T*(T^2-1))
%            t  = rho*sqrt((T-2)/(1-rho^2));   p = 2*(1-F_{t,T-2}(|t|))
% 图表(A1~A8): 图1 品类销量占比扇形图 / 图2 月销量堆叠柱状图
%       图3 月销量箱线图 / 图4 单品销量直方图 / 图5 周内分布 / 图6 时间段堆叠
%       图7 品类散点矩阵 / 图8 单品散点矩阵 / 图9 top10单品相关热图
% 输入: prod_info 商品信息表;  PROJ_ROOT 题目根目录
% 输出: stats_q1 struct (dates/cat_qty/cat_price/item_qty/item_price/相关矩阵/描述统计)
% =========================================================================

OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
FIG_DIR = fullfile(PROJ_ROOT, 'figures');
if ~exist(FIG_DIR, 'dir'), mkdir(FIG_DIR); end
if nargin < 3, save_figs = true; end               % 扫描等场景传 false 跳过绘图

%% 1. 读取预处理产物, 重构矩阵
opts_cat = detectImportOptions(fullfile(OUT_DIR, 'category_daily.csv'), ...
    'TextType', 'string', 'Encoding', 'UTF-8');
opts_cat.VariableNames = {'class_code', 'sale_date', 'qty', 'revenue', 'avg_price', ...
                          'qty_am', 'qty_noon', 'qty_pm', 'disc_avg_price', ...
                          'loss_bar', 'weekday', 'is_weekend'};
opts_cat.VariableTypes = {'string', 'string', 'double', 'double', 'double', ...
                          'double', 'double', 'double', 'double', 'double', ...
                          'string', 'logical'};
cat = readtable(fullfile(OUT_DIR, 'category_daily.csv'), opts_cat);
opts_it = detectImportOptions(fullfile(OUT_DIR, 'daily_sales.csv'), ...
    'TextType', 'string', 'Encoding', 'UTF-8');
opts_it.VariableNames = {'prod_code', 'sale_date', 'qty', 'revenue', 'avg_price', ...
                         'has_discount', 'n_trans', 'qty_am', 'qty_noon', 'qty_pm'};
opts_it.VariableTypes = {'string', 'string', 'double', 'double', 'double', ...
                         'logical', 'double', 'double', 'double', 'double'};
item = readtable(fullfile(OUT_DIR, 'daily_sales.csv'), opts_it);

cat.sale_date = datetime(cat.sale_date);       % 统一转为 datetime, 供问题2/3比较
dates = unique(cat.sale_date);
n_date = numel(dates);
cat_codes = unique(cat.class_code);
n_cat = numel(cat_codes);
prod_codes = prod_info.prod_code;
[~, ci0] = ismember(cat_codes, prod_info.class_code);
cat_names = prod_info.class_name(ci0);        % 品类名称(用于图表标签与结果表)

[~, iC] = ismember(cat.class_code, cat_codes);
[~, iDc] = ismember(cat.sale_date, dates);
cat_qty = accumarray([iC, iDc], cat.qty, [n_cat, n_date]);   % 公式(3.2)
item.sale_date = datetime(item.sale_date);
[~, iP] = ismember(item.prod_code, prod_codes);
[~, iDi] = ismember(item.sale_date, dates);
item_qty   = accumarray([iP, iDi], item.qty,      [numel(prod_codes), n_date]);
item_price = accumarray([iP, iDi], item.avg_price, [numel(prod_codes), n_date]);
item_price(item_qty == 0) = NaN;

%% 2. 分布规律 (建模文档3.1: 均值/方差/偏度/峰度)
m  = @(X) mean(X, 2);
sd = @(X) std(X, 0, 2);
sk = @(X) skewness(X, 0, 2);
ku = @(X) kurtosis(X, 0, 2) - 3;                    % 超额峰度
cat_desc = table(cat_codes, m(cat_qty), sd(cat_qty), sk(cat_qty), ku(cat_qty), ...
    'VariableNames', {'class_code', 'mean_qty', 'std_qty', 'skewness', 'ex_kurtosis'});
writetable(cat_desc, fullfile(OUT_DIR, 'q1_category_distribution.csv'), 'Encoding', 'UTF-8');

%% 3. 斯皮尔曼秩相关 + 显著性检验 (公式3.3, 用内置 corr 计算)
T = n_date;
cat_rho = corr(cat_qty', 'Type', 'Spearman', 'Rows', 'pairwise');
cat_t   = cat_rho .* sqrt((T - 2) ./ (1 - cat_rho.^2));   % t 统计量
cat_p   = 2 * tcdf(-abs(cat_t), T - 2);                   % 双侧 p 值

item_rho = corr(item_qty', 'Type', 'Spearman', 'Rows', 'pairwise');
item_t   = item_rho .* sqrt((T - 2) ./ (1 - item_rho.^2));
item_p   = 2 * tcdf(-abs(item_t), T - 2);

n_const = sum(std(item_qty, 0, 2) == 0);
fprintf('[q1] 全期零销量单品 %d 个, 其相关系数为 NaN\n', n_const);
strong_frac = mean(abs(cat_rho(~tril(true(6)))) > 0.6, 'all');  % |rho|>0.6 强关联占比
fprintf('[q1] 品类间强关联(|rho|>0.6)占比: %.1f%%\n', strong_frac * 100);

%% 4. 显著相关组合表格 (A8: 只列显著且|rho|大的组合)
sig_cat = [];
for i = 1:n_cat
    for j = i + 1:n_cat
        if abs(cat_rho(i, j)) > 0.6 && cat_p(i, j) < 0.01
            sig_cat(end + 1, :) = [i, j]; %#ok<AGROW>
        end
    end
end
[ri, rj] = find(abs(item_rho) > 0.6 & item_p < 0.01);
keep = ri < rj;  ri = ri(keep);  rj = rj(keep);      % 只取上三角
[~, ord] = sort(abs(item_rho(sub2ind(size(item_rho), ri, rj))), 'descend');
ri = ri(ord);  rj = rj(ord);
if numel(ri) > 20, ri = ri(1:20);  rj = rj(1:20); end  % 论文表格限20对
sig_tbl = table([cat_names(sig_cat(:, 1)); prod_info.prod_name(ri)], ...
                [cat_names(sig_cat(:, 2)); prod_info.prod_name(rj)], ...
                [cat_rho(sub2ind(size(cat_rho), sig_cat(:, 1), sig_cat(:, 2))); ...
                 item_rho(sub2ind(size(item_rho), ri, rj))], ...
    'VariableNames', {'变量1', '变量2', 'Spearman相关系数'});
writetable(sig_tbl, fullfile(OUT_DIR, 'q1_significant_pairs.csv'), 'Encoding', 'UTF-8');
fprintf('[q1] 显著相关组合: 品类 %d 对, 单品 %d 对 (表已存档)\n', size(sig_cat, 1), numel(ri));

%% 5. 图表 (A1~A9, 300dpi PNG + EPS)
if save_figs
% ---- 图1 (A1): 品类总销量占比扇形图 ----
f = figure('Position', [100 100 640 480], 'Color', 'w');
pct = sum(cat_qty, 2) / sum(cat_qty, 'all') * 100;   % 占比(与论文文本同源)
pie(sum(cat_qty, 2), strcat(string(cat_names), ' ', string(round(pct, 1)), '%'));
title('六品类蔬菜三年总销量占比');
exportgraphics(f, fullfile(FIG_DIR, 'q1_pie_share.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_pie_share.eps'), '-depsc');
close(f);                                          % 导出后关闭图形

% ---- 图2 (A2): 月销量堆叠柱状图 (12月×6品类) ----
monthly = zeros(n_cat, 12);
for mm = 1:12
    monthly(:, mm) = sum(cat_qty(:, month(dates) == mm), 2);
end
f = figure('Position', [100 100 760 440], 'Color', 'w');
b = bar(monthly', 'stacked');                    % 12月组×6品类
legend(cat_names, 'Location', 'eastoutside');
xlabel('月份');  ylabel('销售量(kg)');
title('六品类蔬菜各月销售量堆叠柱状图');
xticklabels(1:12);
mtot = sum(monthly, 1);                          % 各月总量标注(与绘图数据同源)
text(b(end).XEndPoints, b(end).YEndPoints, string(round(mtot)), ...
    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 7);
exportgraphics(f, fullfile(FIG_DIR, 'q1_monthly_stacked.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_monthly_stacked.eps'), '-depsc');
close(f);

% ---- 图3 (A3): 箱线图 (各品类月销量分布) ----
f = figure('Position', [100 100 760 440], 'Color', 'w');
boxplot(monthly', 'Labels', cat_names);
xlabel('品类');  ylabel('月销售量(kg)');
title('六品类蔬菜月销售量箱线图');
grid on;
exportgraphics(f, fullfile(FIG_DIR, 'q1_monthly_boxplot.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_monthly_boxplot.eps'), '-depsc');
close(f);

% ---- 图4 (A4): 单品三年总销量直方图 (按品类, 对数分箱展示长尾分布) ----
item_total = sum(item_qty, 2);
f = figure('Position', [100 100 960 640], 'Color', 'w');
for c = 1:n_cat
    subplot(2, 3, c);
    vals = item_total(prod_info.class_code == cat_codes(c));
    n_zero = sum(vals <= 0);
    vals = vals(vals > 0);                          % 剔除零销量单品(图上注明)
    edges = logspace(log10(max(min(vals), 0.1)), log10(max(vals)), 12);  % 对数分箱
    histogram(vals, edges);
    set(gca, 'XScale', 'log');
    [N, ED] = histcounts(vals, edges);
    centers = sqrt(ED(1:end-1) .* ED(2:end));    % 对数区间几何中心
    text(centers, N, string(N), 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center', 'FontSize', 6);   % 频数标注
    xlabel('三年总销量(kg, 对数轴)');  ylabel('单品数');
    title(sprintf('%s (零销量%d个)', cat_names(c), n_zero));
end
sgtitle('各品类单品三年总销量直方图 (对数分箱, 长尾分布)');
exportgraphics(f, fullfile(FIG_DIR, 'q1_item_hist.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_item_hist.eps'), '-depsc');
close(f);

% ---- 图5 (A5): 周内分布 (周一~周日 × 6品类) ----
wd = weekday(dates);                       % 1=周日...7=周六
weekly = zeros(n_cat, 7);
for d = 1:7
    weekly(:, d) = sum(cat_qty(:, wd == d), 2);
end
f = figure('Position', [100 100 760 440], 'Color', 'w');
b = bar(weekly', 'grouped');
legend(cat_names, 'Location', 'eastoutside');
xlabel('星期');  ylabel('销售量(kg)');
xticklabels({'周日', '周一', '周二', '周三', '周四', '周五', '周六'});
title('六品类蔬菜周内销售量分布');
for k = 1:numel(b)                               % 每根柱数值标注
    text(b(k).XEndPoints, b(k).YEndPoints, string(round(b(k).YData)), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 6);
end
exportgraphics(f, fullfile(FIG_DIR, 'q1_weekly_dist.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_weekly_dist.eps'), '-depsc');
close(f);

% ---- 图6 (A6): 早中晚时间段堆叠百分比图 ----
am_c = accumarray(iC, cat.qty_am, [n_cat, 1]);
noon_c = accumarray(iC, cat.qty_noon, [n_cat, 1]);
pm_c = accumarray(iC, cat.qty_pm, [n_cat, 1]);
time_pct = [am_c, noon_c, pm_c];             % n_cat×3
time_pct = time_pct ./ sum(time_pct, 2);     % 行归一化 → 百分比
f = figure('Position', [100 100 760 440], 'Color', 'w');
b = bar(time_pct, 'stacked');
legend({'早上(8-13时)', '下午(13-17时)', '晚上(17-23时)'}, 'Location', 'eastoutside');
xlabel('品类');  ylabel('销量占比');
xticklabels(cat_names);
title('六品类蔬菜早中晚时间段销量占比');
cum_bot = zeros(1, n_cat);                       % 各分段百分比标注(段中点)
for k = 1:numel(b)
    cum_top = cum_bot + b(k).YData;
    text(b(k).XEndPoints, (cum_bot + cum_top) / 2, ...
        string(round(b(k).YData * 100, 1)) + "%", ...
        'HorizontalAlignment', 'center', 'FontSize', 7);
    cum_bot = cum_top;
end
exportgraphics(f, fullfile(FIG_DIR, 'q1_timeofday.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_timeofday.eps'), '-depsc');
close(f);

% ---- 图7 (A7a): 品类两两销量散点图矩阵 ----
f = figure('Position', [100 100 1050 900], 'Color', 'w');
for ci = 1:n_cat
    for cj = 1:n_cat
        subplot(n_cat, n_cat, (ci - 1) * n_cat + cj);
        if ci == cj
            histogram(cat_qty(ci, :), 20, 'FaceColor', [0.4 0.6 0.9]);
            title(cat_names(ci), 'FontSize', 9);
        else
            scatter(cat_qty(cj, :), cat_qty(ci, :), 4, '.');
            hold on;
            star = '';
            if abs(cat_rho(ci, cj)) > 0.6 && cat_p(ci, cj) < 0.01, star = '**';
            elseif cat_p(ci, cj) < 0.01, star = '*'; end
            text(0.05, 0.9, sprintf('\\rho=%.2f%s', cat_rho(ci, cj), star), ...
                'Units', 'normalized', 'FontSize', 8);
            hold off;
        end
        if ci == n_cat, xlabel(cat_names(cj), 'FontSize', 8); end
        if cj == 1, ylabel(cat_names(ci), 'FontSize', 8); end
    end
end
sgtitle('蔬菜品类日销量两两散点图 (** : |\rho|>0.6 且 p<0.01)');
exportgraphics(f, fullfile(FIG_DIR, 'q1_category_scatter.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_category_scatter.eps'), '-depsc');
close(f);

% ---- 图8 (A7b): 单品散点矩阵 (各品类销量前2单品, 12×12) ----
[~, ord_it] = sort(item_total, 'descend');
top2_idx = [];
for c = 1:n_cat
    in_cat = find(prod_info.class_code == cat_codes(c) & item_total > 0);
    [~, o2] = sort(item_total(in_cat), 'descend');
    top2_idx = [top2_idx; in_cat(o2(1:min(2, numel(o2))))]; %#ok<AGROW>
end
n_sel = numel(top2_idx);
sel_names = prod_info.prod_name(top2_idx);
f = figure('Position', [100 100 1050 900], 'Color', 'w');
for ii = 1:n_sel
    for jj = 1:n_sel
        subplot(n_sel, n_sel, (ii - 1) * n_sel + jj);
        if ii == jj
            histogram(item_qty(top2_idx(ii), :), 20, 'FaceColor', [0.4 0.6 0.9]);
            title(sel_names(ii), 'FontSize', 7);
        else
            scatter(item_qty(top2_idx(jj), :), item_qty(top2_idx(ii), :), 3, '.');
            rho_s = corr(item_qty(top2_idx(ii), :)', item_qty(top2_idx(jj), :)', ...
                         'Type', 'Spearman');
            text(0.05, 0.9, sprintf('\\rho=%.2f', rho_s), 'Units', 'normalized', ...
                 'FontSize', 6);
        end
        if ii == n_sel, xlabel(sel_names(jj), 'FontSize', 6); end
        if jj == 1, ylabel(sel_names(ii), 'FontSize', 6); end
    end
end
sgtitle('各品类销量前2单品日销量散点矩阵');
print(f, fullfile(FIG_DIR, 'q1_item_scatter.png'), '-dpng', '-r150');   % 144子图降分辨率防内存不足
print(f, fullfile(FIG_DIR, 'q1_item_scatter.eps'), '-depsc');
close(f);

% ---- 图9 (A8): top10单品相关热图 (可读范围) ----
top10_idx = ord_it(1:min(10, numel(ord_it)));
top10_rho = item_rho(top10_idx, top10_idx);
top10_names = prod_info.prod_name(top10_idx);
f = figure('Position', [100 100 780 680], 'Color', 'w');
h = heatmap(top10_rho, 'Colormap', parula, 'GridVisible', 'off');
h.XDisplayLabels = top10_names;  h.YDisplayLabels = top10_names;
h.Title = '销量前10单品斯皮尔曼相关系数热图';
h.CellLabelFormat = '%.2f';
exportgraphics(f, fullfile(FIG_DIR, 'q1_top10_heatmap.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_top10_heatmap.eps'), '-depsc');
close(f);

% ---- 品类相关热力图 + 单品聚类树状图 (保留) ----
f = figure('Position', [100 100 700 520], 'Color', 'w');
h = heatmap(cat_rho, 'Colormap', parula);
h.XDisplayLabels = cat_names;  h.YDisplayLabels = cat_names;
h.Title = '蔬菜品类日销量斯皮尔曼相关系数(公式3.3)';
h.CellLabelFormat = '%.2f';
exportgraphics(f, fullfile(FIG_DIR, 'q1_category_heatmap.png'), 'Resolution', 300);
print(f, fullfile(FIG_DIR, 'q1_category_heatmap.eps'), '-depsc');
close(f);

dist_mat = 1 - item_rho;
dist_mat(isnan(dist_mat)) = 1;
dist_mat(1:size(dist_mat, 1) + 1:end) = 0;
Z = linkage(squareform(dist_mat, 'tovector'), 'average');
f2 = figure('Position', [100 100 800 2400], 'Color', 'w');   % 251叶需足够纵向空间
dendrogram(Z, 0, 'Orientation', 'left', 'ColorThreshold', 0.7);
set(gca, 'FontSize', 7);
title('单品层次聚类树状图 (平均联动, 251 个单品; 颜色=距离0.7处切分的簇)');
exportgraphics(f2, fullfile(FIG_DIR, 'q1_item_dendrogram.png'), 'Resolution', 300);
print(f2, fullfile(FIG_DIR, 'q1_item_dendrogram.eps'), '-depsc');
close(f2);
end  % save_figs

%% 6. 输出结构体 (问题2/3 复用矩阵)
stats_q1 = struct();
stats_q1.dates     = dates;
stats_q1.cat_qty   = cat_qty;
stats_q1.cat_price = accumarray([iC, iDc], cat.avg_price, [n_cat, n_date]);
stats_q1.item_qty  = item_qty;
stats_q1.item_price = item_price;
stats_q1.cat_codes = cat_codes;
stats_q1.cat_names = cat_names;
stats_q1.cat_rho = cat_rho;   stats_q1.cat_t = cat_t;   stats_q1.cat_p = cat_p;
stats_q1.item_rho = item_rho; stats_q1.item_t = item_t; stats_q1.item_p = item_p;
stats_q1.cat_desc = cat_desc;
stats_q1.fig_paths = struct('pie', fullfile(FIG_DIR, 'q1_pie_share.png'), ...
                            'monthly', fullfile(FIG_DIR, 'q1_monthly_stacked.png'), ...
                            'boxplot', fullfile(FIG_DIR, 'q1_monthly_boxplot.png'), ...
                            'item_hist', fullfile(FIG_DIR, 'q1_item_hist.png'), ...
                            'weekly', fullfile(FIG_DIR, 'q1_weekly_dist.png'), ...
                            'timeofday', fullfile(FIG_DIR, 'q1_timeofday.png'), ...
                            'cat_scatter', fullfile(FIG_DIR, 'q1_category_scatter.png'), ...
                            'item_scatter', fullfile(FIG_DIR, 'q1_item_scatter.png'), ...
                            'top10_heatmap', fullfile(FIG_DIR, 'q1_top10_heatmap.png'), ...
                            'item_dendrogram', fullfile(FIG_DIR, 'q1_item_dendrogram.png'));
fprintf('[q1] 问题1分析完成, 图表保存至 %s\n', FIG_DIR);
end
