%% plot_q2_sens —— 问题二：计划视野长度的影响
% 图名:     问题2 视野灵敏度_费用与紧急购电
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（由 scripts/data_q2_sens.m 生成）
% 论文位置: 问题二·检验章 / 模型评价（回答"全年视野值多少"）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF）
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24;   FIG_H = 10;
NAME  = '视野灵敏度_费用与紧急购电';
TITLE = '计划视野长度对费用与紧急购电的影响';
AX_L  = [0.078 0.30 0.378 0.55];
AX_R  = [0.580 0.30 0.378 0.55];
XTIT  = 0.010;
ANN   = [0.078 0.045 0.88 0.20];

lab = D.label;
x   = 1:numel(lab);

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
b1  = bar(ax1, x, D.gap_wan, 0.5, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
set(ax1, 'XTick', x, 'XTickLabel', lab, 'XTickLabelRotation', 0);
ylabel(ax1, '超理想下界的费用（万元）');
ylim(ax1, [0, max(D.gap_wan)*1.22]);
func_fig_style(ax1, 'GridOff', false);
hold(ax1, 'on');  yline(ax1, 0, '-', 'Color', func_fig_pal(6));

ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
b2  = bar(ax2, x, D.em_wankwh, 0.5, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');
set(ax2, 'XTick', x, 'XTickLabel', lab, 'XTickLabelRotation', 0);
ylabel(ax2, '紧急购电量（万 kWh）');
ylim(ax2, [0, max(D.em_wankwh)*1.22]);
func_fig_style(ax2, 'GridOff', false);
hold(ax2, 'on');  yline(ax2, 0, '-', 'Color', func_fig_pal(6));

% 柱顶标值（现场由 data.csv 计算）
for k = 1:numel(x)
    text(ax1, x(k), D.gap_wan(k) + max(D.gap_wan)*0.03, sprintf('%.0f', D.gap_wan(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
    text(ax2, x(k), D.em_wankwh(k) + max(D.em_wankwh)*0.03, sprintf('%.1f', D.em_wankwh(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);

annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', 'Noto Serif CJK SC', ...
    'String', { ...
        sprintf('视界 1 天 → 7 天：费用距理想下界的差距缩小 %.1f 万元，紧急购电降低 %.1f 万 kWh。', ...
                D.gap_wan(1)-D.gap_wan(2), D.em_wankwh(1)-D.em_wankwh(2)), ...
        sprintf('视界 7 天 → 30 / 90 / 全年：两项均不再改善（各档极差仅 %.2f 万元，相当于 %.3f%%）。', ...
                max(D.gap_wan(2:end))-min(D.gap_wan(2:end)), ...
                100*(max(D.cost_win(2:end))-min(D.cost_win(2:end)))/mean(D.cost_win(2:end)))});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
