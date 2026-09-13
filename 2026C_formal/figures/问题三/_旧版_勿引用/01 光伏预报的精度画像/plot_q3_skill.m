%% plot_q3_skill —— 问题三：题面预报的精度画像
% 图名:     问题3 光伏预报的精度画像
% 对应问题: 问题三
% 数据来源: 本目录 data.csv（由 scripts/data_q3_skill.m 生成）
% 论文位置: 问题三·数据说明（预报精度是本问结果的主要解释变量）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 17.7;  FIG_H = 12.4;
NAME  = '光伏预报的精度画像';
TITLE = '题面光伏预报的精度：随预报步长的误差与两条参照';
AXPOS = [0.115 0.230 0.860 0.590];
XTIT  = 0.032;

x = D.lead_h;

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% RMSE 以浅色带示意离散程度
p1 = plot(ax, x, D.rmse_kw, '-', 'Color', func_fig_pal(5), 'LineWidth', 1.6);
p2 = plot(ax, x, D.mae_kw, '-o', 'Color', func_fig_pal(1), ...
          'LineWidth', 2.0, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
p3 = plot(ax, x, D.mae_self_kw, '-', 'Color', func_fig_pal(2), 'LineWidth', 1.8);
p4 = plot(ax, x, D.mae_week_kw, '-', 'Color', func_fig_pal(6), 'LineWidth', 1.8);
% 关键点数据标注（最高/最低步长）
[~, ihi] = max(D.mae_kw);  [~, ilo] = min(D.mae_kw);
text(ax, x(ihi)-1.4, D.mae_kw(ihi)*0.97, sprintf('%.0f', D.mae_kw(ihi)), ...
     'HorizontalAlignment', 'right', 'FontSize', 14, 'Color', func_fig_pal(1));
text(ax, x(ilo), D.mae_kw(ilo)*1.06, sprintf('%.0f', D.mae_kw(ilo)), ...
     'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', func_fig_pal(1));
text(ax, 24, D.mae_self_kw(end)*1.05, sprintf('%.0f', D.mae_self_kw(end)), ...
     'HorizontalAlignment', 'right', 'FontSize', 14, 'Color', func_fig_pal(2));
text(ax, 24, D.mae_week_kw(end)*0.90, sprintf('%.0f', D.mae_week_kw(end)), ...
     'HorizontalAlignment', 'right', 'FontSize', 14, 'Color', func_fig_pal(6));

set(ax, 'XTick', 1:2:23);
xlabel(ax, '预报步长（自发布时刻起，小时）');
ylabel(ax, '误差（kW）');
xlim(ax, [0.5, 24.5]);
ylim(ax, [0, max(D.rmse_kw)*1.16]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
legend(ax, [p2 p1 p3 p4], {'题面预报 MAE', '题面预报 RMSE', ...
       '自建同星期回溯 MAE', '相邻同星期日的固有差异'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'NumColumns', 2, 'Box', 'off', 'FontSize', 14);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
