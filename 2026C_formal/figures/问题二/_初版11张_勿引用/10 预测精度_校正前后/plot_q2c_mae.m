%% plot_q2c_mae —— 问题二：偏差校正前后的预测精度（MAE / RMSE）
% 图名:     问题二 预测精度_校正前后
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（负荷/光伏/净负荷的逐点误差统计，校正前 vs 校正后）
% 论文位置: 问题二·模型检验
% 支撑结论: 校正后负荷/光伏/净负荷的 MAE 与 RMSE 均下降，而总费用反而上升——两图并置说明"更准 ≠ 更省"

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 22.5;  FIG_H = 11.5;
NAME  = '问题二 预测精度_校正前后';
TITLE = '偏差校正前后的预测误差：MAE 与 RMSE';
AX_L  = [0.095 0.310 0.345 0.545];
AX_R  = [0.590 0.310 0.345 0.545];
XTIT  = 0.022;
ANN   = [0.095 0.055 0.845 0.175];
BW    = 0.62;                   % 组内柱宽（整组占 0.8）
KIND  = {'原始预测', '校正后预测'};

% ---------- 出图 ----------
IT = unique(string(D.item), 'stable');          % 三个对象：负荷 / 光伏 / 净负荷
nI = numel(IT);
% 逐对象两行（原始、校正后）→ nI×2 分组矩阵
MAE = reshape(D.mae,  2, nI).';
RMS = reshape(D.rmse, 2, nI).';
x   = (1:nI).';
ITL = cellstr(IT);

f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% 左：MAE
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
b1 = bar(ax1, x, MAE, BW);
b1(1).FaceColor = func_fig_pal(6);
b1(2).FaceColor = func_fig_pal(1);
set(b1, 'EdgeColor', 'none');
set(ax1, 'XTick', x, 'XTickLabel', ITL, 'XTickLabelRotation', 0);
xlim(ax1, [0.4, nI + 0.6]);
ylim(ax1, [0, max(MAE(:)) * 1.22]);
ylabel(ax1, 'MAE（kW）');
func_fig_style(ax1);
for k = 1:numel(b1)
    text(ax1, b1(k).XEndPoints, b1(k).YEndPoints + max(MAE(:)) * 0.03, ...
         cellstr(compose('%.1f', b1(k).YEndPoints)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 右：RMSE
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
b2 = bar(ax2, x, RMS, BW);
b2(1).FaceColor = func_fig_pal(6);
b2(2).FaceColor = func_fig_pal(1);
set(b2, 'EdgeColor', 'none');
set(ax2, 'XTick', x, 'XTickLabel', ITL, 'XTickLabelRotation', 0);
xlim(ax2, [0.4, nI + 0.6]);
ylim(ax2, [0, max(RMS(:)) * 1.22]);
ylabel(ax2, 'RMSE（kW）');
func_fig_style(ax2);
for k = 1:numel(b2)
    text(ax2, b2(k).XEndPoints, b2(k).YEndPoints + max(RMS(:)) * 0.03, ...
         cellstr(compose('%.1f', b2(k).YEndPoints)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 图名（整图下置）、图例与结论注释
func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax1, 'XLabel'), 'FontName');
lg = legend(ax1, b1, KIND, 'Orientation', 'horizontal', 'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% 分项降幅由 data.csv 现算
dM = MAE(:, 1) - MAE(:, 2);
dR = RMS(:, 1) - RMS(:, 2);
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('校正后 MAE 降幅：负荷 %.1f、光伏 %.1f、净负荷 %.1f kW。', dM(1), dM(2), dM(3)), ...
    sprintf('校正后 RMSE 降幅：负荷 %.1f、光伏 %.1f、净负荷 %.1f kW；三组对象误差一致下降。', dR(1), dR(2), dR(3))});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
