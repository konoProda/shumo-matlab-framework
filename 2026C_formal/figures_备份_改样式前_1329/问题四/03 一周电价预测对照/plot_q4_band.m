%% plot_q4_band —— 问题四：一周实测电价与中心预测对照
% 图名:     问题四 一周电价预测对照
% 对应问题: 问题四
% 数据来源: 本目录 data.csv（某一周逐槽的实际电价与中心预测）
% 论文位置: 问题四·预测与情景
% 支撑结论: 中心预测能刻画日内峰谷形态；实际价格在峰谷时刻上仍有偏差
%
% 说明：本图**只画实际与中心预测两条线**，不画情景带——情景带是 SAA 的内部构造、
%       不可直接观测，画出来会被误读为"预测区间"。图名因此定为"预测对照"。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 12.5;
NAME  = '问题四 一周电价预测对照';
TITLE = '一周实测电价与预测电价';
AX    = [0.092 0.280 0.884 0.560];
XTIT  = 0.028;
n     = height(D);
x     = (1:n).';
step  = 24*6;                                   % 每天 144 槽，每 24 槽一个刻度

% ---------- 出图 ----------
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
       'Orientation','horizontal', 'Box','off');
set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
