%% plot_q3_em —— 问题三：紧急购电的逐时分布（与问题二对照）
% 图名:     问题3 紧急购电的逐时分布
% 对应问题: 问题三
% 数据来源: 本目录 data.csv（由 scripts/data_q3_em.m 生成）
% 论文位置: 问题三·结果分析

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 17.7;  FIG_H = 12.4;
NAME  = '紧急购电的逐时分布';
TITLE = '紧急购电的逐时分布：问题三与问题二对照';
AXPOS = [0.115 0.230 0.860 0.620];
XTIT  = 0.032;

x = D.hour;

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

b = bar(ax, x, D.q3_wankwh, 0.70, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
p = plot(ax, x, D.q2_wankwh, '-s', 'Color', func_fig_pal(6), ...
         'LineWidth', 1.6, 'MarkerSize', 5, 'MarkerFaceColor', 'w');

set(ax, 'XTick', 0:2:22, 'XTickLabel', compose('%d:00', 0:2:22));
xlabel(ax, '时刻（区间起点）');
ylabel(ax, '紧急购电量（万 kWh）');
xlim(ax, [-1, 24]);
ylim(ax, [0, max([D.q3_wankwh; D.q2_wankwh])*1.20]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
[~, ipk] = max(D.q3_wankwh);
text(ax, D.hour(ipk), D.q3_wankwh(ipk)*1.03, sprintf('%.2f', D.q3_wankwh(ipk)), ...
     'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', func_fig_pal(1));
legend(ax, [b p], {'问题三（分阶段调整）', '问题二（年视野滚动）'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
