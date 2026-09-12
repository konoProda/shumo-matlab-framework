%% plot_q2c_soc —— 问题二：日末储电量轨迹与日内波动范围
% 图名:     问题二 日末储电量轨迹
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（逐日 E_end 与日内最小 / 最大储电量，单位 kWh）
% 论文位置: 问题二·结果分析
% 支撑结论: 日末在窗口内均值 7,046 kWh，最低触到下限 1,200 kWh

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 24.5;  FIG_H = 12;
NAME  = '问题二 日末储电量轨迹';
TITLE = '日末储电量轨迹与日内波动范围';
AXPOS = [0.112 0.290 0.838 0.560];      % 左边界右移，右边界不动，给“储电量（kWh）”腾出位置
XTIT  = 0.026;
E_MIN = 1200;                           % 储电量下限（kWh），模型参数
E_MAX = 10800;                          % 储电量上限（kWh），模型参数
E_AVE = 7046;                           % 报送窗口日末均值（kWh），与总览文档表 2 一致
W0    = datetime(2025, 2, 1);           % 报送窗口起点（1 月不在窗口内）

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 日内波动范围（最小—最大）画成浅色带，日末值以实线叠在带上
xb = [D.date; flipud(D.date)];
yb = [D.E_day_min; flipud(D.E_day_max)];
hband = fill(ax, xb, yb, func_fig_pal(6), 'FaceAlpha', 0.22, 'EdgeColor', 'none');
hline = plot(ax, D.date, D.E_end, '-', 'Color', func_fig_pal(1), 'LineWidth', 1.8);

% 上/下限与窗口均值：点线参考线，名称写在图例里
yline(ax, E_MAX, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
yline(ax, E_MIN, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
yline(ax, E_AVE, ':', 'Color', func_fig_pal(3), 'LineWidth', 1.3);
xline(ax, W0, ':', 'Color', func_fig_pal(4), 'LineWidth', 1.3);

xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, E_MAX * 1.10]);
xtickformat(ax, 'MMM');
xlabel(ax, '月份');
ylabel(ax, '储电量（kWh）');
ax.YAxis.Exponent = 0;
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

% 图例句柄：浅色带与曲线用真实句柄，四条参考线用不可见占位线
g1 = plot(ax, D.date(1:2), nan(2,1), ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
g2 = plot(ax, D.date(1:2), nan(2,1), ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
g3 = plot(ax, D.date(1:2), nan(2,1), ':', 'Color', func_fig_pal(3), 'LineWidth', 1.3);
g4 = plot(ax, [W0; W0 + days(1)], nan(2,1), ':', 'Color', func_fig_pal(4), 'LineWidth', 1.3);
FN = get(get(ax, 'XLabel'), 'FontName');
lg = legend(ax, [hband, hline, g1, g2, g3, g4], ...
            {'日内波动范围（最小—最大）', '日末储电量', '上限 10,800', '下限 1,200', ...
             '窗口日末均值 7,046', '报送窗口起点 02-01'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');
xlim(ax, [D.date(1), D.date(end)]);     % 图例会重置日期轴，冻结一次

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
