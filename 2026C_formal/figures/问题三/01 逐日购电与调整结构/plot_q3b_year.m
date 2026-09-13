%% 逐日购电与调整量

% 读同目录 data.csv，输出 PNG 与 PDF。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

%% 画图参数
FIG_W = 20;  FIG_H = 10.8;
NAME  = '问题三 逐日购电与调整结构';
TITLE = '逐日购电与调整量';
AX    = [0.100 0.290 0.876 0.545];
XTIT  = 0.008;
WAN   = 1e4;                                  % kWh → 万 kWh
t     = D.date;

%% 绘制
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
       'Orientation','horizontal', 'Box','off', 'FontSize', 22);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
