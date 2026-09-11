%% plot_q1_price_buy —— 问题一：典型日电价与计划购电量
% 图名:     典型日计划购电策略
% 对应问题: 问题一
% 数据来源: figures/data/q1_price_buy.csv
% 论文位置: 问题一·结果分析（配合论文表1）

clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
D = readtable(fullfile(PROJ_ROOT, 'figures', 'data', 'q1_price_buy.csv'));

% ---------- 绘图参数（集中定义） ----------
FIG_W = 15;   FIG_H = 11;
NAME  = 'q1_price_buy';
TITLE = '典型日计划购电策略';
AXPOS = [0.155 0.27 0.685 0.58];
XTIT  = 0.025;                      % 图名的图归一化纵坐标
XH = (2*D.slot - 1) / 12;            % 各槽中点对应的小时数

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);

b = bar(ax, XH, D.buy_kwh, 1.0, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
hold(ax, 'on');

yyaxis(ax, 'right');
p = plot(ax, XH, D.price, '-', 'Color', func_fig_pal(2), 'LineWidth', 1.8);

xlim(ax, [0 24]);
xticks(ax, 0:4:24);
xticklabels(ax, {'0:00','4:00','8:00','12:00','16:00','20:00','24:00'});
ax.XTickLabelRotation = 0;

yyaxis(ax, 'left');
ylim(ax, [0, max(D.buy_kwh) * 1.18]);
ylabel(ax, '购电量（kWh）');
yyaxis(ax, 'right');
ylim(ax, [0.3, 1.5]);
ylabel(ax, '电价（元/kWh）');
xlabel(ax, '时刻');

func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax,'XLabel'), 'FontName');
yyaxis(ax, 'left');   b.FaceColor = func_fig_pal(1);
yyaxis(ax, 'right');  set(get(ax,'YLabel'), 'FontName', FN, 'FontSize', 16);

lg = legend(ax, [b, p], {'购电量', '电价'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% 本图数据密集，按规范"标注密度宜低"不设内嵌数值标注；
% 全天购电量与购电费由论文表1 与正文给出

% ---------- 导出 ----------
fig_dir = fullfile(PROJ_ROOT, 'figures');
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
close(f);
