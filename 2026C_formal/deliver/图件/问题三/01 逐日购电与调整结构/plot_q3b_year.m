%% plot_q3b_year —— 问题三：全年逐日购电与调整结构
% 图名:     问题三 逐日购电与调整结构
% 对应问题: 问题三（第二版：日内多阶段预报更新 + 购电计划再调整）
% 数据来源: 本目录 data.csv（窗口内逐日的最终生效购电、调增、调减、紧急购电量）
% 论文位置: 问题三·结果分析
% 支撑结论: 最终生效购电全年平稳，调增/调减在少量日期集中出现，紧急购电仅零星发生

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 13;
NAME  = '问题三 逐日购电与调整结构';
TITLE = '逐日购电与调整量';
AX    = [0.100 0.290 0.876 0.545];
XTIT  = 0.030;
WAN   = 1e4;                                  % kWh → 万 kWh
t     = D.date;

% ---------- 出图 ----------
f = figure('Units','centimeters','Position',[3 4 FIG_W FIG_H]);
ax = axes(f,'Units','normalized','Position',AX);
hold(ax,'on');
y = [D.buy_kwh, D.up_kwh, -D.dn_kwh, D.em_kwh] / WAN;
h = bar(ax, t, y, 1.0, 'stacked', 'EdgeColor','none');
for k = 1:numel(h); h(k).FaceColor = func_fig_pal(k); end

ylim(ax, [-0.6 8.2]);
ylabel(ax, '电量（万 kWh）');
xlabel(ax, '日期');
ax.YAxis.Exponent = 0;
func_fig_style(ax);
ax.XTickLabelRotation = 0;
legend(ax, {'最终生效购电','调增','调减','紧急购电'}, 'Location','northoutside', ...
       'Orientation','horizontal', 'Box','off');
set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
