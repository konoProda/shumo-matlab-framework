%% plot_q3_adj —— 问题三：调整量的逐日演化
% 图名:     问题3 调整量的逐日演化
% 对应问题: 问题三
% 数据来源: 本目录 data.csv（由 scripts/data_q3_adj.m 生成）
% 论文位置: 问题三·结果分析（调整在方向与规模上的时间分布）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 26.0;  FIG_H = 14.8;
NAME  = '调整量的逐日演化';
TITLE = '逐日调整量：高于与低于原计划的部分及调整费用';
AXPOS = [0.085 0.215 0.885 0.660];
XTIT  = 0.032;

x = D.doy;
Y = [D.up_kwh/1e3, -D.down_kwh/1e3];        % 千 kWh，下调取负便于对照
mstart = cumsum([31 28 31 30 31 30 31 31 30 31 30]);
mlab = {'2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'};

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
b = bar(ax, x, Y, 1.0, 'stacked', 'EdgeColor', 'none');
b(1).FaceColor = func_fig_pal(2);         % 上调
b(2).FaceColor = func_fig_pal(1);         % 下调（取负）
yline(ax, 0, '-', 'Color', func_fig_pal(6), 'LineWidth', 1.1);
[upmax, iu] = max(D.up_kwh/1e3);   [dnmax, id] = max(D.down_kwh/1e3);
text(ax, x(iu), upmax*1.04, sprintf('%.1f', upmax), 'HorizontalAlignment', 'center', ...
     'FontSize', 13, 'Color', func_fig_pal(2));
text(ax, x(id), -dnmax*1.06, sprintf('%.1f', dnmax), 'HorizontalAlignment', 'center', ...
     'FontSize', 13, 'Color', func_fig_pal(1));

set(ax, 'XTick', [1, mstart(1:end-1)+1], 'XTickLabel', mlab, 'XTickLabelRotation', 0);
xlabel(ax, '2025 年（日序）');
ylabel(ax, '调整量（千 kWh/日）');
xlim(ax, [0.5, 334.5]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
legend(ax, b, {'高于原计划', '低于原计划（取负）'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
