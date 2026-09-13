%% 峰价与谷价时刻的预测偏差分布

% 读同目录 data.csv，输出 PNG 与 PDF。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

%% 绘图参数
FIG_W = 20;  FIG_H = 10;
NAME  = '问题四 峰谷时刻预测误差';
TITLE = '峰价与谷价时刻的预测偏差分布';
AX    = [0.092 0.280 0.884 0.560];
XTIT  = 0.008;
x     = D.lag_slot(:);
XT    = -12:4:12;
XTL   = cellstr(compose('%+d', XT));

%% 出图
f = figure('Units','centimeters','Position',[3 5 FIG_W FIG_H]);
ax = axes(f,'Units','normalized','Position',AX);
hold(ax,'on');
b = bar(ax, x, [D.n_peak, D.n_valley], 0.86, 'grouped', 'EdgeColor','none');
b(1).FaceColor = func_fig_pal(1);
b(2).FaceColor = func_fig_pal(2);

set(ax, 'XTick', XT, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax, [-12.7 12.7]);
ylim(ax, [0, max([D.n_peak; D.n_valley])*1.22]);
ax.YAxis.Exponent = 0;
xlabel(ax, '预测时刻 − 实际时刻（个 10 分钟槽）');
ylabel(ax, '出现天数');
func_fig_style(ax);
legend(ax, {'峰价时刻','谷价时刻'}, 'Location','northoutside', ...
       'Orientation','horizontal', 'Box','off', 'FontSize', 22, 'TextColor', 'k');
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
