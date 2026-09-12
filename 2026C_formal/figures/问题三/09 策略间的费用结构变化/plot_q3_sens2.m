%% plot_q3_sens2 —— 问题三：策略间的费用结构变化
% 图名:     问题3 策略间的费用结构变化
% 对应问题: 问题三（收益来自哪一项：调整费还是紧急购电费）
% 数据来源: 本目录 data.csv（由 scripts/data_q3_sens.m 生成）
% 论文位置: 问题三·结果分析

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24.8;  FIG_H = 12.4;
NAME  = '策略间的费用结构变化';
TITLE = '各策略的费用结构：计划、调整与紧急购电费';
XTIT  = 0.032;

ord = 4:-1:1;                      % 数据按 S3..S0 存储，绘图统一按 S0 → S3 自左向右
pol = D.policy(ord);
x = (1:4).';
Y = [D.plan_yuan(ord), D.adj_yuan(ord), D.em_yuan(ord)] / 1e4;

% ---------- 出图 ----------
f = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', [0.085 0.235 0.885 0.640]);
hold(ax, 'on');
b = bar(ax, x, Y, 0.62, 'grouped', 'EdgeColor', 'none');
b(1).FaceColor = func_fig_pal(1);
b(2).FaceColor = func_fig_pal(2);
b(3).FaceColor = func_fig_pal(4);

set(ax, 'XTick', x, 'XTickLabel', pol);
ylabel(ax, '费用（万元）');
ylim(ax, [0, max(Y(:))*1.20]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
legend(ax, b, {'计划购电费', '调整相关费用', '紧急购电费'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);
% 组内柱顶标值
for k = 1:size(Y,1)
    for jj = 1:3
        text(ax, x(k) + (jj-2)*0.22, Y(k,jj) + max(Y(:))*0.015, sprintf('%.0f', Y(k,jj)), ...
             'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', func_fig_pal(6));
    end
end

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
