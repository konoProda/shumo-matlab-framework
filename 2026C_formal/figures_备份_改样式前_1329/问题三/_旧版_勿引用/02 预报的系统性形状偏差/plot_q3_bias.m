%% plot_q3_bias —— 问题三：题面预报的系统性形状偏差
% 图名:     问题3 预报的系统性形状偏差
% 对应问题: 问题三
% 数据来源: 本目录 data.csv（由 scripts/data_q3_bias.m 生成）
% 论文位置: 问题三·数据说明（解释预报误差的结构，而非仅给幅度）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 17.7;  FIG_H = 12.4;
NAME  = '预报的系统性形状偏差';
TITLE = '题面预报相对实际光伏的逐小时平均偏差';
AXPOS = [0.115 0.235 0.860 0.630];
XTIT  = 0.032;

x = D.hour;
y = D.bias_kw;

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 正偏差（高估）与负偏差（低估）分色：同一含义在同一图内保持一致
pos = y >= 0;
b1 = bar(ax, x(pos),  y(pos),  0.66, 'FaceColor', func_fig_pal(4), 'EdgeColor', 'none');
b2 = bar(ax, x(~pos), y(~pos), 0.66, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
yline(ax, 0, '-', 'Color', func_fig_pal(6), 'LineWidth', 1.2);

set(ax, 'XTick', 0:2:22, 'XTickLabel', compose('%d:00', 0:2:22));
xlabel(ax, '时刻（区间起点）');
ylabel(ax, '平均偏差（kW）');
xlim(ax, [-1, 24]);
ylim(ax, [min(y)*1.30, max(y)*1.22]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
% 逐柱数据标注
for k = 1:numel(y)
    if abs(y(k)) < 60; continue; end                       % 近零柱不标，避免堆叠
    off = (0.05*abs(y(k)) + 60) * (1 + 0.7*mod(k,2));        % 相邻柱交替错开，防标注重叠
    text(ax, x(k), y(k) + sign(y(k))*off, sprintf('%.0f', y(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', func_fig_pal(6));
end
legend(ax, [b1 b2], {'预报高估实际', '预报低估实际'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
