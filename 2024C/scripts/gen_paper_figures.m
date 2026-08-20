% gen_paper_figures.m —— 论文图件批量生成（只读已存解，零重求解，约5分钟）
% 产出（全部 300dpi PNG + EPS，图内标题不带图号，数值现场计算）:
%   1. saa_cumulative    SAA 累计均值收敛曲线（K=5..50，替换两柱图）
%   2. data_land_area    六类地块面积构成（数据侧写）
%   3. data_price_range  41作物价格区间均值条形（数据侧写）
%   4. q2_profit_hist    Q2 情景总利润分布直方图（标注均值/5%分位）
%   5. q3_corr_heatmap   Q3 Spearman 相关热力图（41x41）
%   6. q3_clusters       Q3 K-means 聚类散点（均价 x 价格波动）
%   7. q1_plant_matrix   Q1 半价 2024 种植矩阵热图（54地块 x 41作物）
%   8. area_share_evol   Q3 三大类面积占比逐年演变（替换四方案堆叠图）

clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
DATA_DIR = fullfile(PROJ_ROOT, 'data');
OUT_DIR  = fullfile(PROJ_ROOT, 'outputs');
FIG_DIR  = fullfile(PROJ_ROOT, 'figures');

[plot_area, plot_type, crop_type, plant_raw, stat_raw] = func_load_data(DATA_DIR);
[omega_list, ~] = func_build_omega(plot_type, crop_type);
param = func_build_params(plot_area, plot_type, crop_type, stat_raw, plant_raw, omega_list);
param.delta_min = 0.10;  param.p_disaster = 0.10;
% 作物名称（附件1 sheet2 第2列，前41行）
T_crop = readtable(fullfile(DATA_DIR, '附件1.xlsx'), 'Sheet', '乡村种植的农作物', ...
                   'VariableNamingRule', 'preserve');
crop_name = cellstr(T_crop.('作物名称')(1:41));

S1 = load(fullfile(OUT_DIR, 'q1_solution.mat'));
S2 = load(fullfile(OUT_DIR, 'q2_solution.mat'));
S3 = load(fullfile(OUT_DIR, 'q3_solution.mat'));
ST = load(fullfile(OUT_DIR, 'q3_stats.mat'));

oj = omega_list(:, 2);
grain = ismember(oj, 1:16);  veg = ismember(oj, 17:37);  fungi = ismember(oj, 38:41);

% 统一柔和配色（中等饱和度、类别边界清晰，避免高艳度）
pal = struct('blue', [0.35 0.55 0.75], 'green', [0.45 0.65 0.45], ...
             'orange', [0.85 0.65 0.35], 'red', [0.75 0.45 0.40], ...
             'purple', [0.55 0.50 0.70], 'gray', [0.65 0.65 0.65]);

% ---- 1. SAA 累计均值收敛曲线 ----
p_vec = S2.sol_q2.profit_total_vec;   % 1x50
Ks = 5:numel(p_vec);
cum_mean = arrayfun(@(k) mean(p_vec(1:k)), Ks);
f1 = figure('Visible', 'off');
plot(Ks, cum_mean / 1e4, '-o', 'MarkerSize', 3, 'LineWidth', 1.2, 'Color', pal.blue);
hold on;
yline(cum_mean(end) / 1e4, '--', 'Color', pal.gray);
text(Ks(1) + 2, cum_mean(end) / 1e4 * 1.001, sprintf('K=50 收敛值 %.1f 万元', cum_mean(end) / 1e4), ...
     'FontSize', 8);
xlabel('情景数 K');
ylabel('期望总利润（万元）');
title('SAA 样本平均逼近收敛曲线');
grid on;
print(f1, fullfile(FIG_DIR, 'saa_cumulative.png'), '-dpng', '-r300');
print(f1, fullfile(FIG_DIR, 'saa_cumulative.eps'), '-depsc');
close(f1);

% ---- 2. 六类地块面积构成 ----
type_list = {'平旱地', '梯田', '山坡地', '水浇地', '普通大棚', '智慧大棚'};
area_by_type = zeros(1, 6);
for k = 1:6
    area_by_type(k) = sum(plot_area(strcmp(plot_type, type_list{k})));
end
f2 = figure('Visible', 'off');
b2 = bar(area_by_type, 'FaceColor', pal.blue);
set(gca, 'XTickLabel', type_list, 'XTick', 1:6);
ylabel('总面积（亩）');
title('六类耕地面积构成');
grid on;
y_off = max(area_by_type) * 0.02;
for k = 1:6
    text(k, area_by_type(k) + y_off, sprintf('%.0f', area_by_type(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
end
print(f2, fullfile(FIG_DIR, 'data_land_area.png'), '-dpng', '-r300');
print(f2, fullfile(FIG_DIR, 'data_land_area.eps'), '-depsc');
close(f2);

% 饼图：六类地块面积占比（百分比入图例，避免贴饼边重叠）
f2b = figure('Visible', 'off');
pct2 = round(area_by_type / sum(area_by_type) * 1000) / 10;
pie(area_by_type, repmat({''}, 1, 6));
colormap([pal.blue; pal.green; pal.orange; pal.red; pal.purple; pal.gray]);
lbl2 = cell(1, 6);
for k = 1:6
    lbl2{k} = sprintf('%s %.1f%%', type_list{k}, pct2(k));
end
legend(lbl2, 'Location', 'eastoutside', 'FontSize', 8);
title('六类耕地面积占比');
print(f2b, fullfile(FIG_DIR, 'data_land_area_pie.png'), '-dpng', '-r300');
print(f2b, fullfile(FIG_DIR, 'data_land_area_pie.eps'), '-depsc');
close(f2b);

% ---- 3. 41作物价格区间均值 ----
price_by_crop = zeros(41, 1);
for j = 1:41
    ids = find(oj == j);
    price_by_crop(j) = mean(param.price_i(ids));
end
f3 = figure('Visible', 'off');
b3 = bar(price_by_crop, 'FaceColor', pal.orange);
set(gca, 'XTick', 1:41, 'XTickLabel', crop_name, 'XTickLabelRotation', 45, 'FontSize', 6);
ylabel('价格区间均值（元/斤）');
title('41 种作物销售单价区间均值');
grid on;
print(f3, fullfile(FIG_DIR, 'data_price_range.png'), '-dpng', '-r300');
print(f3, fullfile(FIG_DIR, 'data_price_range.eps'), '-depsc');
close(f3);

% ---- 4. Q2 情景总利润直方图 ----
f4 = figure('Visible', 'off');
histogram(p_vec / 1e4, 10, 'FaceColor', pal.blue);
hold on;
p_mean = mean(p_vec) / 1e4;
p_p05 = prctile(p_vec, 5) / 1e4;
xline(p_mean, '--', 'Color', pal.red, 'LineWidth', 1.5);
xline(p_p05, '--', 'Color', pal.purple, 'LineWidth', 1.5);
legend({'情景频数', sprintf('均值 %.0f 万元', p_mean), sprintf('5%%分位 %.0f 万元', p_p05)}, ...
       'Location', 'best', 'FontSize', 8);
xlabel('七年总利润（万元）');
ylabel('情景数');
title('Q2 情景总利润分布');
grid on;
print(f4, fullfile(FIG_DIR, 'q2_profit_hist.png'), '-dpng', '-r300');
print(f4, fullfile(FIG_DIR, 'q2_profit_hist.eps'), '-depsc');
close(f4);

% ---- 5. Q3 Spearman 热力图 ----
f5 = figure('Visible', 'off');
imagesc(S3.rho_sp, [-1 1]);
colormap(bluewhitered);
colorbar;
set(gca, 'XTick', 1:41, 'XTickLabel', crop_name, 'XTickLabelRotation', 90, 'FontSize', 6);
set(gca, 'YTick', 1:41, 'YTickLabel', crop_name, 'FontSize', 6);
axis square;
title('41 种作物 Spearman 等级相关系数矩阵');
print(f5, fullfile(FIG_DIR, 'q3_corr_heatmap.png'), '-dpng', '-r300');
print(f5, fullfile(FIG_DIR, 'q3_corr_heatmap.eps'), '-depsc');
close(f5);

% ---- 6. Q3 聚类散点（均价 x 价格波动） ----
feat = ST.feat;                      % 41x4: [需求均值, 均价, 成本均值, 价格标准差]
x_feat = feat(:, 2);
y_feat = feat(:, 4);
cl = ST.clusters;
f6 = figure('Visible', 'off');
cl_colors = [pal.blue; pal.green; pal.orange; pal.purple];
hold on;
for c = 1:4
    idx_c = find(cl == c);
    scatter(x_feat(idx_c), y_feat(idx_c), 40, cl_colors(c, :), 'filled', ...
            'DisplayName', sprintf('类%d (n=%d)', c, numel(idx_c)));
end
y_off6 = max(y_feat) * 0.015;
for j = 1:41
    text(x_feat(j), y_feat(j) + y_off6, num2str(j), 'FontSize', 6, ...
         'HorizontalAlignment', 'center');
end
xlabel('均价（元/斤）');
ylabel('价格波动（标准差）');
title('作物功能聚类结果（K-means，4 类）');
legend('Location', 'best', 'FontSize', 8);
grid on;
print(f6, fullfile(FIG_DIR, 'q3_clusters.png'), '-dpng', '-r300');
print(f6, fullfile(FIG_DIR, 'q3_clusters.eps'), '-depsc');
close(f6);

% ---- 7. Q1 半价 2024 种植矩阵热图 ----
u_2024 = S1.sol_case2.u(:, 1);      % 1062x1
u_map = zeros(54, 41);
u_map(sub2ind([54 41], omega_list(:, 1), omega_list(:, 2))) = u_2024;
f7 = figure('Visible', 'off');
imagesc(u_map');
colormap([1 1 1; pal.blue]);
set(gca, 'XTick', 1:54, 'XTickLabel', plot_name_list(), 'FontSize', 5);
set(gca, 'YTick', 1:41, 'YTickLabel', crop_name, 'FontSize', 5);
xlabel('地块');
ylabel('作物');
title('Q1 半价情形 2024 年种植方案矩阵（蓝=种植）');
print(f7, fullfile(FIG_DIR, 'q1_plant_matrix.png'), '-dpng', '-r300');
print(f7, fullfile(FIG_DIR, 'q1_plant_matrix.eps'), '-depsc');
close(f7);

% ---- 8. Q3 三大类面积占比逐年演变 ----
x3 = S3.sol_q3.x;
share = zeros(7, 3);
for t = 1:7
    area_t = x3(:, t);
    share(t, 1) = sum(area_t(grain));
    share(t, 2) = sum(area_t(veg));
    share(t, 3) = sum(area_t(fungi));
    share(t, :) = share(t, :) / sum(share(t, :)) * 100;
end
f8 = figure('Visible', 'off');
b8 = bar(2024:2030, share, 'stacked');
b8(1).FaceColor = pal.blue;
b8(2).FaceColor = pal.green;
b8(3).FaceColor = pal.orange;
legend({'粮食类', '蔬菜类', '食用菌'}, 'Location', 'eastoutside', 'FontSize', 8);
xlabel('年份');
ylabel('种植面积占比（%）');
title('Q3 策略下三大类种植面积占比演变');
grid on;
print(f8, fullfile(FIG_DIR, 'area_share_evol.png'), '-dpng', '-r300');
print(f8, fullfile(FIG_DIR, 'area_share_evol.eps'), '-depsc');
close(f8);

% ---- 9. Q3 三大类面积占比饼图（七年累计） ----
share_7y = sum(share, 1);
f9 = figure('Visible', 'off');
pie(share_7y, repmat({''}, 1, 3));
colormap([pal.blue; pal.green; pal.orange]);
pct9 = round(share_7y / sum(share_7y) * 1000) / 10;
lbl9 = cell(1, 3);
cat9 = {'粮食类', '蔬菜类', '食用菌'};
for k = 1:3
    lbl9{k} = sprintf('%s %.1f%%', cat9{k}, pct9(k));
end
legend(lbl9, 'Location', 'eastoutside', 'FontSize', 8);
title('Q3 策略下三大类种植面积占比（七年累计）');
print(f9, fullfile(FIG_DIR, 'q3_area_share_pie.png'), '-dpng', '-r300');
print(f9, fullfile(FIG_DIR, 'q3_area_share_pie.eps'), '-depsc');
close(f9);

% ---- 10. 灵敏度结果重绘（自 outputs/sensitivity.csv，数据点少 -> 仅柱状，不连线） ----
if isfile(fullfile(OUT_DIR, 'sensitivity.csv'))
    M = readmatrix(fullfile(OUT_DIR, 'sensitivity.csv'));
    x_all = M(:, 1);
    y_all = M(:, 2);
    seg_ends = find(isnan(x_all));       % NaN 分隔四个段
    seg_ends = [seg_ends; numel(x_all) + 1];
    seg_starts = [1; seg_ends(1:end-1) + 1];
    seg_names = {'sens_lambda', 'sens_disaster', 'sens_delta', 'sens_phi'};
    xlabels = {'\lambda 取值', '灾害年触发概率（%）', '最小种植比例 \delta', '互补折减系数 \phi'};
    for sg = 1:4
        xx = x_all(seg_starts(sg):seg_ends(sg) - 1);
        yy = y_all(seg_starts(sg):seg_ends(sg) - 1);
        fs = figure('Visible', 'off');
        bs = bar(1:numel(yy), yy, 'FaceColor', pal.blue);
        set(gca, 'XTick', 1:numel(yy), 'XTickLabel', string(xx));
        xlabel(xlabels{sg});
        ylabel('指标（万元）');
        title(sprintf('灵敏度分析 S%d', sg));
        grid on;
        y_off = max(yy) * 0.02;
        for k = 1:numel(yy)
            text(k, yy(k) + y_off, sprintf('%.0f', yy(k)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 8);
        end
        print(fs, fullfile(FIG_DIR, [seg_names{sg} '.png']), '-dpng', '-r300');
        print(fs, fullfile(FIG_DIR, [seg_names{sg} '.eps']), '-depsc');
        close(fs);
    end
end

fprintf('论文图件生成完毕: 全部 PNG+EPS 已写入 figures/\n');

function names = plot_name_list()
% 附件1 顺序生成地块名（A1-A6, B1-B14, C1-C6, D1-D8, E1-E16, F1-F4）
names = [strcat('A', string(1:6)), strcat('B', string(1:14)), strcat('C', string(1:6)), ...
         strcat('D', string(1:8)), strcat('E', string(1:16)), strcat('F', string(1:4))];
names = cellstr(names);
end

function newmap = bluewhitered()
% 柔和蓝-白-红发散色图（-1..1，低饱和）
n = 256;
newmap = interp1([1 n/2 n], [0.25 0.45 0.75; 1 1 1; 0.80 0.50 0.40], 1:n);
end
