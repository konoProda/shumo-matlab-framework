%% plot_q3b_emhour —— 问题三：紧急购电的逐时分布
% 图名:     问题三 紧急购电逐时分布
% 对应问题: 问题三（第二版）
% 数据来源: 本目录 data.csv（24 个时段各自的紧急购电量与出现槽数，窗口内统计）
% 论文位置: 问题三·结果分析
% 支撑结论: 紧急购电集中在傍晚峰段，正午前后基本为零——与电价峰谷和光伏出力错配

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(fullfile(THIS_DIR, '..', '..', '..', 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 12.5;
NAME  = '问题三 紧急购电逐时分布';
TITLE = '紧急购电的逐时分布';
AX_L  = [0.098 0.280 0.370 0.555];
AX_R  = [0.556 0.280 0.424 0.555];
XTIT  = 0.026;
BW    = 0.52;
ROT   = 90;
TOL   = 0.04;                                  % 低于最大值该比例的柱不标数值

x   = D.hour(:);
XT  = 1:3:22;
XTL = cellstr(compose('%d:00', XT - 1));

f = figure('Units','centimeters','Position',[3 5 FIG_W FIG_H]);
ax1 = axes(f,'Units','normalized','Position',AX_L);
hold(ax1,'on');
bar(ax1, x, D.em_kwh, BW, 'FaceColor', func_fig_pal(2), 'EdgeColor','none');
MX1 = max(D.em_kwh) * 1.38;
set(ax1, 'XTick', XT, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax1, [0.5 24.5]); ylim(ax1, [0 MX1]); ax1.YAxis.Exponent = 0;
xlabel(ax1, '时段起点（时）'); ylabel(ax1, '紧急购电量（kWh）');
func_fig_style(ax1);
for k = 1:numel(x)
    if D.em_kwh(k) > TOL * max(D.em_kwh)
        text(ax1, x(k), D.em_kwh(k) + 0.012*MX1, sprintf('%.0f', D.em_kwh(k)), ...
             'Rotation', ROT, 'HorizontalAlignment','center', 'FontSize', 14);
    end
end

ax2 = axes(f,'Units','normalized','Position',AX_R);
hold(ax2,'on');
bar(ax2, x, D.n_slot, BW, 'FaceColor', func_fig_pal(1), 'EdgeColor','none');
MX2 = max(D.n_slot) * 1.38;
set(ax2, 'XTick', XT, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax2, [0.5 24.5]); ylim(ax2, [0 MX2]); ax2.YAxis.Exponent = 0;
xlabel(ax2, '时段起点（时）'); ylabel(ax2, '出现槽数（个）');
func_fig_style(ax2);
for k = 1:numel(x)
    if D.n_slot(k) > TOL * max(D.n_slot)
        text(ax2, x(k), D.n_slot(k) + 0.012*MX2, sprintf('%d', D.n_slot(k)), ...
             'Rotation', ROT, 'HorizontalAlignment','center', 'FontSize', 14);
    end
end

func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
