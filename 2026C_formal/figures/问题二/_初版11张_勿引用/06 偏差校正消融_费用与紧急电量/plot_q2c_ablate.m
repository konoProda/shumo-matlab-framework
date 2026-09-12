%% plot_q2c_ablate —— 问题二：偏差校正（B3）消融对照
% 图名:     问题二 偏差校正消融_费用与紧急电量
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（SAA-B3 与 SAA+B3 两臂的窗口费用与紧急电量）
% 论文位置: 问题二·结果分析
% 支撑结论: 保留校正使费用升 13.57 万（+0.92%）、紧急电量降 5,048.3 kWh，论文须写明该权衡

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 22.5;  FIG_H = 11.5;
NAME  = '问题二 偏差校正消融_费用与紧急电量';
TITLE = '偏差校正消融对照：费用与紧急购电量';
AX_L  = [0.090 0.310 0.355 0.545];
AX_R  = [0.585 0.310 0.355 0.545];
XTIT  = 0.022;
ANN   = [0.090 0.055 0.850 0.175];
BW    = 0.42;

% ---------- 出图 ----------
x  = (1:numel(D.arm)).';
AL = cellstr(string(D.arm));
cw = D.cost / 1e4;              % 元 → 万元
dc = cw(end) - cw(1);           % 保留校正 − 去掉校正（万元）
dpc = 100 * (D.cost(end) - D.cost(1)) / D.cost(1);
dE = D.em_kwh(end) - D.em_kwh(1);
dpe = 100 * dE / D.em_kwh(1);

f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% 左：窗口费用
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
bar(ax1, x, cw, BW, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
set(ax1, 'XTick', x, 'XTickLabel', AL, 'XTickLabelRotation', 0);
xlim(ax1, [0.4, numel(x) + 0.6]);
ylim(ax1, [0, max(cw) * 1.20]);
ylabel(ax1, '窗口费用（万元）');
func_fig_style(ax1);
for k = 1:numel(x)
    text(ax1, x(k), cw(k) + max(cw) * 0.035, sprintf('%.2f', cw(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 右：紧急购电量
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
bar(ax2, x, D.em_kwh, BW, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');
set(ax2, 'XTick', x, 'XTickLabel', AL, 'XTickLabelRotation', 0);
xlim(ax2, [0.4, numel(x) + 0.6]);
ylim(ax2, [0, max(D.em_kwh) * 1.22]);
ylabel(ax2, '紧急购电量（kWh）');
ax2.YAxis.Exponent = 0;
func_fig_style(ax2);
for k = 1:numel(x)
    text(ax2, x(k), D.em_kwh(k) + max(D.em_kwh) * 0.035, sprintf('%.0f', D.em_kwh(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 图名（整图下置）与权衡注释（坐标区外）
func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax1, 'XLabel'), 'FontName');
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('保留校正（SAA+B3）相对去掉校正（SAA-B3）：费用 %+.2f 万元（%+.2f%%），即更贵；', dc, dpc), ...
    sprintf('紧急购电量 %+.1f kWh（%+.2f%%），即更少。校正以费用略升换取向理想（无偏）运行靠近的应急缺口下降。', dE, dpe)});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
