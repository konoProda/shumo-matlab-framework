%% plot_q3b_soc —— 问题三：日末储电量轨迹与日内波动范围
% 图名:     问题三 日末储电量轨迹
% 对应问题: 问题三（第二版）
% 数据来源: 本目录 data.csv（逐日日末储电量与当日最小值/最大值）
% 论文位置: 问题三·结果分析
% 支撑结论: 日末储电量全年在上下限之间平稳运行，日内波动范围随季节变化

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 13;
NAME  = '问题三 日末储电量轨迹';
TITLE = '日末储电量与日内波动范围';
AX    = [0.092 0.270 0.884 0.560];
XTIT  = 0.030;
EMIN  = 1200;  EMAX = 10800;                   % 储能上下限 kWh

% ---------- 出图 ----------
f = figure('Units','centimeters','Position',[3 4 FIG_W FIG_H]);
ax = axes(f,'Units','normalized','Position',AX);
hold(ax,'on');
% 日内范围带（先画，避免压住均值线）
xb = [D.date; flipud(D.date)];
yb = [D.E_day_max; flipud(D.E_day_min)];
fill(ax, xb, yb, func_fig_pal(6), 'FaceAlpha', 0.22, 'EdgeColor','none');
plot(ax, D.date, D.E_end, '-', 'LineWidth', 1.6, 'Color', func_fig_pal(1));
yline(ax, EMIN, ':', 'Color', func_fig_pal(4), 'LineWidth', 1.2);
yline(ax, EMAX, ':', 'Color', func_fig_pal(4), 'LineWidth', 1.2);

ylim(ax, [0, EMAX*1.10]);
ylabel(ax, '储电量（kWh）');
xlabel(ax, '日期');
ax.YAxis.Exponent = 0;
func_fig_style(ax);
legend(ax, {'日内范围','日末储电量','储电量上/下限'}, 'Location','northoutside', ...
       'Orientation','horizontal', 'Box','off');
set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
