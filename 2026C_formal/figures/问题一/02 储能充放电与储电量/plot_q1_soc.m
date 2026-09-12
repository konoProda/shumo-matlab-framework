%% plot_q1_soc —— 问题一：储能充放电量与储电量
% 图名:     储能充放电与储电量
% 对应问题: 问题一
% 数据来源: 本目录 data.csv（与脚本同目录）
% 论文位置: 问题一·结果分析（配合论文表2）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数（集中定义） ----------
FIG_W = 15;   FIG_H = 11;
NAME  = '储能充放电与储电量';
TITLE = '储能充放电与储电量';
AXPOS = [0.150 0.27 0.680 0.58];
XTIT  = 0.025;                      % 图名的图归一化纵坐标
XH = (2*D.slot - 1) / 12;
E_CAP = 12000; E_LO = 1200; E_HI = 10800;        % 附录1 容量与运行区间
X_E = [0; XH];                                    % 储电量轨迹含 0:00 起点
Y_E = [D.E_start_kwh(1); D.E_kwh];
YL  = max(D.chg_kwh) * 1.30;

% ---------- 出图 ----------
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
FN = get(get(ax,'XLabel'), 'FontName');
yyaxis(ax, 'left');
bc.FaceColor = func_fig_pal(3);  bd.FaceColor = func_fig_pal(4);
yyaxis(ax, 'right');
set(get(ax,'YLabel'), 'FontName', FN, 'FontSize', 16);

lg = legend(ax, [bc, bd, hl], {'充电量', '放电量（负值）', '储电量'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% 本图数据密集，按规范"标注密度宜低"不设内嵌数值标注；
% 储电量区间、0:00/24:00 储电量、等效循环次数由论文表2 与正文给出

% ---------- 导出 ----------
fig_dir = THIS_DIR;
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
close(f);
