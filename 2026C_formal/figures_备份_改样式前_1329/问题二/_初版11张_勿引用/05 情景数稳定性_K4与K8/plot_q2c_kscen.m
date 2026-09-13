%% plot_q2c_kscen —— 问题二：情景数 K=4 与 K=8 的稳定性对照
% 图名:     问题二 情景数稳定性_K4与K8
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（正式 K=4 与加密 K=8 两组运行的窗口费用与紧急电量）
% 论文位置: 问题二·灵敏度分析
% 支撑结论: 费用相对差 −1.962%（在 5% 内），但紧急电量差 −14.56%（对情景数较敏感）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 22.5;  FIG_H = 11.5;
NAME  = '问题二 情景数稳定性_K4与K8';
TITLE = '情景数 K=4 与 K=8 的窗口费用与紧急购电量对照';
AX_L  = [0.090 0.310 0.355 0.545];
AX_R  = [0.585 0.310 0.355 0.545];
XTIT  = 0.022;
ANN   = [0.090 0.055 0.850 0.175];
BW    = 0.42;
DX    = 0.16;                   % 相对差标注相对柱顶的抬高量（占 y 轴满量程比例）
XLIM  = [0.4, 2.9];             % 右侧留白，容纳费用面板的相对差文字标注

% ---------- 出图 ----------
x  = (1:numel(D.K)).';
KL = cellstr(compose('K=%d', D.K));
cw = D.cost / 1e4;              % 元 → 万元
dc = 100 * (D.cost(end) - D.cost(1)) / D.cost(1);
de = 100 * (D.em_kwh(end) - D.em_kwh(1)) / D.em_kwh(1);

f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% 左：窗口费用
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
bar(ax1, x, cw, BW, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
set(ax1, 'XTick', x, 'XTickLabel', KL, 'XTickLabelRotation', 0);
xlim(ax1, XLIM);
ylim(ax1, [0, max(cw) * 1.42]);
ylabel(ax1, '窗口费用（万元）');
func_fig_style(ax1);
for k = 1:numel(x)
    text(ax1, x(k), cw(k) + max(cw) * 0.035, sprintf('%.2f', cw(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end
% 费用面板的相对差标注（K=8 相对 K=4）
text(ax1, x(end), cw(end) + max(cw) * DX, sprintf('相对 K=4：%+.3f%%', dc), ...
     'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', func_fig_pal(4));

% 右：紧急购电量
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
bar(ax2, x, D.em_kwh, BW, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');
set(ax2, 'XTick', x, 'XTickLabel', KL, 'XTickLabelRotation', 0);
xlim(ax2, XLIM);
ylim(ax2, [0, max(D.em_kwh) * 1.22]);
ylabel(ax2, '紧急购电量（kWh）');
ax2.YAxis.Exponent = 0;
func_fig_style(ax2);
for k = 1:numel(x)
    text(ax2, x(k), D.em_kwh(k) + max(D.em_kwh) * 0.035, sprintf('%.0f', D.em_kwh(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 图名（整图下置）与结论注释（坐标区外）
func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax1, 'XLabel'), 'FontName');
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('相对差（K=8 比 K=4）：费用 %+.3f%%（在 5%% 以内）、紧急购电量 %+.2f%%。', dc, de), ...
    '费用对情景数不敏感；紧急购电量对情景数明显更敏感，是该口径的主要不确定性来源。'});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
