%% plot_q3_sens —— 问题三：预报使用策略对照与边际收益
% 图名:     问题3 策略对照与边际收益
% 对应问题: 问题三（题面末句：是否需要引入其他时刻的预报）
% 数据来源: 本目录 data.csv / data_marginal.csv（由 scripts/data_q3_sens.m 生成）
% 论文位置: 问题三·结果分析

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));
M = readtable(fullfile(THIS_DIR, 'data_marginal.csv'));
STEP = {'加入 6:00 预报', '再加入 12:00 预报', '再加入 18:00 预报'};   % 展示标签（对应 M 的三行）

% ---------- 绘图参数 ----------
FIG_W = 24.8;  FIG_H = 13.6;
NAME  = '策略对照与边际收益';
TITLE = '预报使用策略 S0~S3 的总费用与紧急购电';
XTIT  = 0.032;
AX1 = [0.085 0.300 0.415 0.520];      % 左：总费用
AX2 = [0.580 0.300 0.395 0.520];      % 右：紧急购电量
SLAB = {'S0', 'S1', 'S2', 'S3'};      % 短标签（含义见下方注记）

f = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% ---- 左：总费用（数据按 S3..S0 存储，绘图统一按 S0 → S3 自左向右）----
ord = 4:-1:1;
ax1 = axes(f, 'Units', 'normalized', 'Position', AX1);
hold(ax1, 'on');
C = D.cost_yuan(ord) / 1e4;
b = bar(ax1, (1:4).', C, 0.66, 'EdgeColor', 'none');
b.FaceColor = 'flat';
b.CData = repmat(func_fig_pal(1), 4, 1);
b.CData(end,:) = func_fig_pal(4);                 % 基准策略 S3 以强调色
for k = 1:4
    text(ax1, k, C(k) + max(C)*0.02, sprintf('%.0f', C(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end
set(ax1, 'XTick', 1:4, 'XTickLabel', SLAB, 'FontSize', 15);
ylabel(ax1, '总费用（万元）');
ylim(ax1, [0, max(C)*1.24]);
title(ax1, '各策略全年总费用', 'FontSize', 15, 'FontName', 'Noto Serif CJK SC');
func_fig_style(ax1);
% 费用变化注记：加入该时刻预报后总费用的变化（S0→S1 对应 x=1→2，依此类推）
for j = 1:3
    xa = j + 0.5;  xb = j + 1.5;
    plot(ax1, [xa xb], [1 1]*max(C)*1.09, '-', 'Color', func_fig_pal(2), 'LineWidth', 1.2);
    text(ax1, (xa+xb)/2, max(C)*1.115, sprintf('%+.1f 万', M.dcost_yuan(j)/1e4), ...
         'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', func_fig_pal(2));
end

% ---- 右：紧急购电 ----
ax2 = axes(f, 'Units', 'normalized', 'Position', AX2);
hold(ax2, 'on');
E = D.em_kwh(ord)/1e4;
b2 = bar(ax2, (1:4).', E, 0.66, 'EdgeColor', 'none');
b2.FaceColor = 'flat';
b2.CData = repmat(func_fig_pal(6), 4, 1);
b2.CData(end,:) = func_fig_pal(4);
set(ax2, 'XTick', 1:4, 'XTickLabel', SLAB, 'FontSize', 15);
ylabel(ax2, '紧急购电量（万 kWh）');
ylim(ax2, [0, max(E)*1.16]);
title(ax2, '各策略紧急购电量', 'FontSize', 15, 'FontName', 'Noto Serif CJK SC');
func_fig_style(ax2);

annotation(f, 'textbox', [0.060 0.120 0.900 0.050], 'Units', 'normalized', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'left', 'FontSize', 14, ...
    'FontName', 'Noto Serif CJK SC', ...
    'String', '橙色数字 = 加入该时刻预报后的费用变化（万元，正值=上升）');
annotation(f, 'textbox', [0 0.030 1 0.055], 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'FontSize', 17, 'FontWeight', 'bold', ...
    'FontName', 'AR PL UKai CN', 'String', TITLE);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
