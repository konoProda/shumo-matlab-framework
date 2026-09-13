%% plot_q3_soc —— 问题三：储能储电量轨迹与日末分布
% 图名:     问题3 储能储电量轨迹与日末分布
% 对应问题: 问题三
% 数据来源: 本目录 data.csv（由 scripts/data_q3_soc.m 生成）
% 论文位置: 问题三·结果分析（日末储电量趋于下限这一结构性现象）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24.8;  FIG_H = 11.8;
NAME  = '储能储电量轨迹与日末分布';
TITLE = '储能储电量：日初/日末轨迹与日末分布（问题三 vs 问题二）';
XTIT  = 0.032;
E_MIN = 1200;  E_MAX = 10800;
AX1 = [0.105 0.230 0.395 0.615];      % 左：轨迹
AX2 = [0.585 0.230 0.390 0.615];      % 右：分布

f = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% ---- 左：日初/日末轨迹 ----
ax1 = axes(f, 'Units', 'normalized', 'Position', AX1);
hold(ax1, 'on');
p1 = plot(ax1, D.doy, D.E0_q3,   '-',  'Color', func_fig_pal(1), 'LineWidth', 1.3);
p2 = plot(ax1, D.doy, D.Eend_q3, '-',  'Color', func_fig_pal(4), 'LineWidth', 1.6);
p3 = plot(ax1, D.doy, D.Eend_q2, '-', 'Color', func_fig_pal(6), 'LineWidth', 1.6);
yline(ax1, E_MIN, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
yline(ax1, E_MAX, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
xlabel(ax1, '2025 年（日序）');
ylabel(ax1, '储电量（kWh）');
xlim(ax1, [0.5, 334.5]);
ylim(ax1, [0, E_MAX*1.06]);
title(ax1, '日初与日末储电量轨迹', 'FontSize', 15, 'FontName', 'Noto Serif CJK SC');
func_fig_style(ax1);
legend(ax1, [p2 p1 p3], {'问题三 日末', '问题三 日初', '问题二 日末'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 13);
% 日末均值数据标注
text(ax1, 5, mean(D.Eend_q3)*0.55, sprintf('问题三日末均值 %.0f', mean(D.Eend_q3)), ...
     'FontSize', 14, 'Color', func_fig_pal(4));
text(ax1, 5, mean(D.Eend_q2), sprintf('问题二日末均值 %.0f', mean(D.Eend_q2)), ...
     'FontSize', 14, 'Color', func_fig_pal(6));

% ---- 右：日末分布 ----
ax2 = axes(f, 'Units', 'normalized', 'Position', AX2);
hold(ax2, 'on');
edges = 0:600:E_MAX;
h1 = histogram(ax2, D.Eend_q3, edges, 'FaceColor', func_fig_pal(4), 'EdgeColor', 'w');
h2 = histogram(ax2, D.Eend_q2, edges, 'FaceColor', func_fig_pal(6), 'EdgeColor', 'w');
h1.FaceAlpha = 0.75;  h2.FaceAlpha = 0.55;
xlabel(ax2, '日末储电量（kWh）');
ylabel(ax2, '天数');
xlim(ax2, [0, E_MAX]);
ylim(ax2, [0, max([h1.Values, h2.Values])*1.25]);
title(ax2, '日末储电量分布', 'FontSize', 15, 'FontName', 'Noto Serif CJK SC');
func_fig_style(ax2);
legend(ax2, [h2 h1], {'问题二', '问题三'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 13);

annotation(f, 'textbox', [0 0.030 1 0.055], 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'FontSize', 17, 'FontWeight', 'bold', ...
    'FontName', 'AR PL UKai CN', 'String', TITLE);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
