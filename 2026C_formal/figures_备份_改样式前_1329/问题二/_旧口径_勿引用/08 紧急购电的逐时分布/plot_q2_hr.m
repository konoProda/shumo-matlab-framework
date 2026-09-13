%% plot_q2_hr —— 问题二：紧急购电的逐时分布
% 图名:     问题2 紧急购电的逐时分布
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（由 scripts/data_q2_season.m 生成）
% 论文位置: 问题二·结果分析（两种执行口径的时段形态差异）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF）
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24;   FIG_H = 11;
NAME  = '紧急购电的逐时分布';
TITLE = '两种执行口径的紧急购电逐时分布';
AXPOS = [0.070 0.28 0.895 0.58];
XTIT  = 0.010;
ANN   = [0.070 0.045 0.895 0.19];

x = D.hour;
fig_pal = @(i) func_fig_pal(i);

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 早晚峰区间以浅色标出（8-10 时、19-21 时）
patch(ax, [8 11 11 8], [0 0 1e4 1e4], func_fig_pal(6), 'FaceAlpha', 0.08, 'EdgeColor', 'none');
patch(ax, [19 22 22 19], [0 0 1e4 1e4], func_fig_pal(6), 'FaceAlpha', 0.08, 'EdgeColor', 'none');

p1 = plot(ax, x, D.em_nocorr_wankwh, '-o', 'Color', func_fig_pal(6), ...
          'LineWidth', 1.6, 'MarkerSize', 5, 'MarkerFaceColor', func_fig_pal(6));
p2 = plot(ax, x, D.em_corr_wankwh, '-o', 'Color', func_fig_pal(1), ...
          'LineWidth', 2.0, 'MarkerSize', 5, 'MarkerFaceColor', func_fig_pal(1));

set(ax, 'XTick', 0:2:22, 'XTickLabel', compose('%d:00', 0:2:22), 'XTickLabelRotation', 0);
ylabel(ax, '紧急购电量（万 kWh）');
xlim(ax, [-0.5, 23.5]);
ylim(ax, [0, max([D.em_nocorr_wankwh; D.em_corr_wankwh])*1.22]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
legend(ax, [p1 p2], {'② 无纠偏带预测', '③ 有纠偏带预测'}, ...
       'Location', 'northwest', 'Box', 'off', 'FontSize', 14);

annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', 'Noto Serif CJK SC', ...
    'String', { ...
        sprintf('③ 高度集中：晚峰 19-21 时占 %.0f%%、早峰 8-10 时占 %.0f%%，合计 %.0f%%（浅色区间）。', ...
                sum(D.corr_pct(D.hour>=19 & D.hour<=21)), sum(D.corr_pct(D.hour>=8 & D.hour<=10)), ...
                sum(D.corr_pct(D.hour>=19 & D.hour<=21)) + sum(D.corr_pct(D.hour>=8 & D.hour<=10))), ...
        sprintf('② 均匀分布于各小时，峰值反落在光伏最充足的正午——按预测富余充电，而富余未实际出现。')});

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
