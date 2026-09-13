% 电价预测的逐时平均绝对误差
% 数据：同目录 data.csv。
% 改图只需改本文件顶部的参数区。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

%% 画图参数
FIG_W = 20;  FIG_H = 10.1;
NAME  = '问题四 电价预测画像';
TITLE = '电价预测的逐时平均绝对误差';
AX    = [0.092 0.280 0.884 0.560];
XTIT  = 0.008;
x     = D.hour(:);
XT    = 1:2:24;
XTL   = cellstr(compose('%d:00', XT - 1));

%% 绘制
f = figure('Units','centimeters','Position',[3 5 FIG_W FIG_H]);
ax = axes(f,'Units','normalized','Position',AX);
hold(ax,'on');
b = bar(ax, x, [D.mae_base, D.mae_corr], 0.84, 'grouped', 'EdgeColor','none');
b(1).FaceColor = func_fig_pal(6);
b(2).FaceColor = func_fig_pal(1);
plot(ax, x, D.bias_corr, '-o', 'LineWidth', 1.6, 'MarkerSize', 4, ...
     'Color', func_fig_pal(2), 'MarkerFaceColor', func_fig_pal(2));

set(ax, 'XTick', XT, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax, [0.3 24.7]);
ylim(ax, [0, max([D.mae_base; D.mae_corr])*1.25]);
ax.YAxis.Exponent = 0;
xlabel(ax, '时段起点（时）');
ylabel(ax, '误差（元/kWh）');
func_fig_style(ax);
legend(ax, {'校正前 MAE','校正后 MAE','校正后偏差'}, 'Location','northoutside', ...
       'Orientation','horizontal', 'Box','off', 'FontSize', 22, 'TextColor', 'k');
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
