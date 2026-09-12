%% plot_q2c_ladder —— 问题二：信息集阶梯的三层窗口费用对照
% 图名:     问题二 信息集阶梯_三层费用对照
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（三层口径的窗口费用与紧急购电量，与总览文档表 3 同源）
% 论文位置: 问题二·模型建立与结果分析
% 支撑结论: 理想 1222.71 万 → 正式 1480.69 万；其中仅 2.68 万来自视野短视，其余来自预测不确定性

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数（集中定义） ----------
FIG_W = 22.5;  FIG_H = 11.5;
NAME  = '问题二 信息集阶梯_三层费用对照';
TITLE = '信息集阶梯：三层口径的窗口费用与紧急购电量';
AX_L  = [0.085 0.310 0.360 0.545];
AX_R  = [0.580 0.310 0.360 0.545];
XTIT  = 0.022;
ANN   = [0.085 0.055 0.855 0.175];
BW    = 0.42;                   % 柱宽
TOL   = 0.5;                    % 紧急购电量低于此值（kWh）按 0 标注

% ---------- 出图 ----------
LV = cellstr(string(D.name));
x  = (1:numel(LV)).';
cw = D.cost / 1e4;              % 元 → 万元（仅单位换算；合计/占比一律由 data.csv 现算）

f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% 左：窗口费用
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
bar(ax1, x, cw, BW, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
set(ax1, 'XTick', x, 'XTickLabel', LV, 'XTickLabelRotation', 0);
xlim(ax1, [0.4, numel(LV) + 0.6]);
ylim(ax1, [0, max(cw) * 1.20]);
ylabel(ax1, '窗口费用（万元）');
func_fig_style(ax1);
for k = 1:numel(x)
    text(ax1, x(k), cw(k) + max(cw) * 0.035, sprintf('%.2f', cw(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 右：紧急购电量（前两层为 0，需在图上显式标出 0）
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
bar(ax2, x, D.em_kwh, BW, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');
set(ax2, 'XTick', x, 'XTickLabel', LV, 'XTickLabelRotation', 0);
xlim(ax2, [0.4, numel(LV) + 0.6]);
ylim(ax2, [0, max(D.em_kwh) * 1.25]);
ylabel(ax2, '紧急购电量（kWh）');
func_fig_style(ax2);
for k = 1:numel(x)
    if D.em_kwh(k) < TOL
        text(ax2, x(k), max(D.em_kwh) * 0.015, '0', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'bottom', 'FontSize', 14, 'Color', func_fig_pal(6));
    else
        text(ax2, x(k), D.em_kwh(k) + max(D.em_kwh) * 0.035, sprintf('%.0f', D.em_kwh(k)), ...
             'HorizontalAlignment', 'center', 'FontSize', 14);
    end
end

% 图名（整图下置）
func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);

% 结论注释（置于坐标区外）
FN = get(get(ax1, 'XLabel'), 'FontName');
gap_view = cw(2) - cw(1);
gap_unc  = cw(3) - cw(2);
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, ...
    'String', { ...
    sprintf('理想（全年联合完美信息）%.2f 万 → 逐日完美信息 %.2f 万 → 滚动 SAA 正式 %.2f 万元。', cw(1), cw(2), cw(3)), ...
    sprintf('总差额 %.2f 万元中：视野短视占 %.2f 万元（%.2f%%），预测不确定性占 %.2f 万元（%.2f%%）。', ...
            cw(3) - cw(1), gap_view, 100 * gap_view / (cw(3) - cw(1)), ...
            gap_unc, 100 * gap_unc / (cw(3) - cw(1)))});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
