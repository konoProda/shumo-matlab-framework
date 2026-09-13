%% plot_q4_lag —— 问题四：日内峰价与谷价时刻的预测偏差分布
% 图名:     问题四 峰谷时刻预测误差
% 对应问题: 问题四
% 数据来源: 本目录 data.csv（峰/谷时刻预测相对实际的偏差分布，单位：10 分钟槽）
% 论文位置: 问题四·模型检验
% 支撑结论: 储能调度关心"何时贵、何时便宜"；峰谷时刻的预测偏差集中在若干小时以内

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 12.5;
NAME  = '问题四 峰谷时刻预测误差';
TITLE = '峰价与谷价时刻的预测偏差分布';
AX    = [0.092 0.280 0.884 0.560];
XTIT  = 0.028;
x     = D.lag_slot(:);
XT    = -12:4:12;
XTL   = cellstr(compose('%+d', XT));

% ---------- 出图 ----------
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
       'Orientation','horizontal', 'Box','off');
set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
