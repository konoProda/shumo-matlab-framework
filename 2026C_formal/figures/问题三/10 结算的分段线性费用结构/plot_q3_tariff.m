%% plot_q3_tariff —— 问题三：调整结算的分段线性费用结构
% 图名:     问题3 结算的分段线性费用结构
% 对应问题: 问题三
% 数据来源: 本目录 data.csv / data_marginal.csv（由 scripts/data_q3_tariff.m 生成）
% 论文位置: 问题三·模型建立与模型评价（解释"低于计划"的经济激励）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));
M = readtable(fullfile(THIS_DIR, 'data_marginal.csv'));

% ---------- 绘图参数 ----------
FIG_W = 17.7;  FIG_H = 11.8;
NAME  = '结算的分段线性费用结构';
TITLE = '调整购电量的结算费用与三档边际价格';
AXPOS = [0.130 0.235 0.830 0.600];
XTIT  = 0.032;
Qp0   = D.Q_plan(1);

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 结算总费用曲线：计划点两侧斜率不同
p1 = plot(ax, D.Q, D.c_all, '-',  'Color', func_fig_pal(4), 'LineWidth', 2.2);
p2 = plot(ax, D.Q, D.c_plan, '-', 'Color', func_fig_pal(6), 'LineWidth', 1.6);
xline(ax, Qp0, ':', 'Color', func_fig_pal(1), 'LineWidth', 1.6);

% 两档斜率标在曲线左上方空白区（现场由 data_marginal.csv 取价）
sl = M.price_yuan(1:2);
text(ax, 22, 8,  sprintf('%.3f 元/kWh（0.5 倍）', sl(1)), ...
     'FontSize', 14, 'Color', func_fig_pal(4), 'HorizontalAlignment', 'left');
text(ax, 150, 0.86*max(D.c_all), sprintf('%.3f 元/kWh（1.5 倍）', sl(2)), ...
     'FontSize', 14, 'Color', func_fig_pal(4), 'HorizontalAlignment', 'left');

xlabel(ax, '最终生效购电量（kWh）');
ylabel(ax, '结算费用（元）');
xlim(ax, [0, max(D.Q)]);
ylim(ax, [0, max(D.c_all)*1.12]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
legend(ax, [p1 p2], {'计划 + 调整 合计', '其中：计划部分'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
