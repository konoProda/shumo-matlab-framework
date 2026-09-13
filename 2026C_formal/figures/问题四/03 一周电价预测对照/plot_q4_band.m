% 一周实测电价与预测电价（问题四）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% --- 参数 ---
FIG_W = 20;  FIG_H = 10.1;
NAME  = '问题四 一周电价预测对照';
TITLE = '一周实测电价与预测电价';
AX    = [0.092 0.280 0.884 0.560];
XTIT  = 0.008;
n     = height(D);
x     = (1:n).';
step  = 24*6;                                   % 每天 144 槽，每 24 槽一个刻度

% --- 画图 ---
f = figure('Units','centimeters','Position',[3 5 FIG_W FIG_H]);
ax = axes(f,'Units','normalized','Position',AX);
hold(ax,'on');
plot(ax, x, D.price_act, '-',  'LineWidth', 1.5, 'Color', func_fig_pal(1));
plot(ax, x, D.price_hat, '-',  'LineWidth', 1.5, 'Color', func_fig_pal(2));

xt = unique(max(1, min(n, 1:step:n)));            % 保证递增且在范围内
set(ax, 'XTick', xt, 'XTickLabel', cellstr(D.date_str(xt)), 'XTickLabelRotation', 0);
xlim(ax, [1 n]);
ylim(ax, [0, max([D.price_act; D.price_hat])*1.20]);
ax.YAxis.Exponent = 0;
xlabel(ax, '日期');
ylabel(ax, '电价（元/kWh）');
func_fig_style(ax);
legend(ax, {'实测电价','中心预测'}, 'Location','northoutside', ...
       'Orientation','horizontal', 'Box','off', 'FontSize', 22);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
