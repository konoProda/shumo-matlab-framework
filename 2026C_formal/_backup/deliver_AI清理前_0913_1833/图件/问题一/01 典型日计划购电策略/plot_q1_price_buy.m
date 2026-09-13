%% 典型日计划购电策略
% 画的是 data.csv 里的逐条记录，数据与图放在同一个文件夹。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

%% 绘图参数
FIG_W = 20;  FIG_H = 10.3;
NAME  = '问题一 典型日计划购电策略';
TITLE = '典型日计划购电策略';
AXPOS = [0.155 0.27 0.685 0.58];
XTIT  = 0.008;                      % 图名的图归一化纵坐标
XH = (2*D.slot - 1) / 12;            % 各槽中点对应的小时数

%% 出图
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
% 双轴各自定色：左轴黑、右轴与右侧序列同色。样式函数只能设到当前活动侧，
% 两侧都要显式声明，否则另一侧的刻度与轴名会沿用主题默认的灰。
yyaxis(ax, 'left');   ax.YColor = 'k';
set(get(ax, 'YLabel'), 'Color', 'k');
yyaxis(ax, 'right');  ax.YColor = func_fig_pal(2);
set(get(ax, 'YLabel'), 'Color', func_fig_pal(2));
FN = get(get(ax,'XLabel'), 'FontName');
yyaxis(ax, 'left');   b.FaceColor = func_fig_pal(1);

lg = legend(ax, [b, p], {'购电量', '电价'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside', 'FontSize', 22, 'TextColor', 'k');
set(lg, 'FontName', FN, 'FontSize', 22, 'Box', 'off', 'TextColor', 'k');

% 全天购电量与购电费由论文表1 与正文给出

%% 导出
fig_dir = THIS_DIR;
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
