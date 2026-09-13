% 储能充放电与储电量

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% --- 参数 ---
FIG_W = 20;  FIG_H = 10.1;
NAME  = '问题一 储能充放电与储电量';
TITLE = '储能充放电与储电量';
AXPOS = [0.150 0.27 0.680 0.58];
XTIT  = 0.008;                      % 图名的图归一化纵坐标
XH = (2*D.slot - 1) / 12;
E_CAP = 12000; E_LO = 1200; E_HI = 10800;        % 附录1 容量与运行区间
X_E = [0; XH];                                    % 储电量轨迹含 0:00 起点
Y_E = [D.E_start_kwh(1); D.E_kwh];
YL  = max(D.chg_kwh) * 1.30;

% --- 画图 ---
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);

bc = bar(ax, XH,  D.chg_kwh, 1.0, 'FaceColor', func_fig_pal(3), 'EdgeColor', 'none');
hold(ax, 'on');
bd = bar(ax, XH, -D.dis_kwh, 1.0, 'FaceColor', func_fig_pal(4), 'EdgeColor', 'none');

yyaxis(ax, 'right');
plot(ax, [0 24], [E_LO E_LO], '--', 'Color', func_fig_pal(6), 'LineWidth', 1.2);
plot(ax, [0 24], [E_HI E_HI], '--', 'Color', func_fig_pal(6), 'LineWidth', 1.2);
hl = plot(ax, X_E, Y_E, '-', 'Color', func_fig_pal(5), 'LineWidth', 2.0);
plot(ax, X_E([1 end]), Y_E([1 end]), 'o', 'Color', func_fig_pal(5), ...
     'MarkerFaceColor', func_fig_pal(5), 'MarkerSize', 6);

xlim(ax, [0 24]);
xticks(ax, 0:4:24);
xticklabels(ax, {'0:00','4:00','8:00','12:00','16:00','20:00','24:00'});
ax.XTickLabelRotation = 0;

yyaxis(ax, 'left');
ylim(ax, [-YL, YL]);
ylabel(ax, '充放电量（kWh）');
yyaxis(ax, 'right');
ylim(ax, [0, E_CAP]);
ylabel(ax, '储电量（kWh）');
xlabel(ax, '时刻');

func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
% 双轴各自定色：左轴黑、右轴与右侧序列同色。样式函数只能设到当前活动侧，
% 两侧都要显式声明，否则另一侧的刻度与轴名会沿用主题默认的灰。
yyaxis(ax, 'left');   ax.YColor = 'k';
set(get(ax, 'YLabel'), 'Color', 'k');
yyaxis(ax, 'right');  ax.YColor = func_fig_pal(2);
set(get(ax, 'YLabel'), 'Color', func_fig_pal(2));
FN = get(get(ax,'XLabel'), 'FontName');
yyaxis(ax, 'left');
bc.FaceColor = func_fig_pal(3);  bd.FaceColor = func_fig_pal(4);
yyaxis(ax, 'right');

lg = legend(ax, [bc, bd, hl], {'充电量', '放电量（负值）', '储电量'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside', 'FontSize', 22, 'TextColor', 'k');
set(lg, 'FontName', FN, 'FontSize', 22, 'Box', 'off', 'TextColor', 'k');

% 储电量区间、0:00/24:00 储电量、等效循环次数由论文表2 与正文给出

% --- 保存 ---
fig_dir = THIS_DIR;
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
