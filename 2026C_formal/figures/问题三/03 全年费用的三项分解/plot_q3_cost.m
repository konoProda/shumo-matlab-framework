%% plot_q3_cost —— 问题三：全年费用的三项分解
% 图名:     问题3 全年费用的三项分解
% 对应问题: 问题三
% 数据来源: 本目录 data.csv（由 scripts/data_q3_cost.m 生成）
% 论文位置: 问题三·结果分析

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 17.7;  FIG_H = 13.6;
NAME  = '全年费用的三项分解';
TITLE = '问题三购电费用的三项构成（2025 年 2-12 月）';
AXPOS = [0.115 0.230 0.860 0.600];
XTIT  = 0.032;

lab = compose('%d月', D.month);
x = 1:numel(lab);
Y = [D.plan_yuan, D.adj_yuan, D.em_yuan] / 1e4;
[~, imx] = max(Y(:,3));  [~, imn] = min(Y(:,3));

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
b = bar(ax, x, Y, 0.74, 'stacked', 'EdgeColor', 'none');
b(1).FaceColor = func_fig_pal(1);    % 计划购电费
b(2).FaceColor = func_fig_pal(2);    % 调整相关费用
b(3).FaceColor = func_fig_pal(4);    % 紧急购电费

set(ax, 'XTick', x, 'XTickLabel', lab);
ylabel(ax, '费用（万元）');
ylim(ax, [0, max(sum(Y,2))*1.16]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
legend(ax, b, {'计划购电费', '调整相关费用', '紧急购电费'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);
% 柱顶标注各月合计
for k = 1:numel(x)
    text(ax, x(k), sum(Y(k,:)) + max(sum(Y,2))*0.02, sprintf('%.0f', sum(Y(k,:))), ...
         'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', func_fig_pal(6));
end

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
