%% plot_q2c_seg —— 问题二：2—4 月与 5—12 月的分段对照
% 图名:     问题二 分段对照_上下半年
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（两段的窗口费用与紧急购电量）
% 论文位置: 问题二·结果分析
% 支撑结论: 2—4 月 348.55 万元 / 紧急 5.96 万 kWh；5—12 月 1132.14 万元 / 紧急 20.96 万 kWh

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 20;   FIG_H = 11.5;
NAME  = '问题二 分段对照_上下半年';
TITLE = '2—4 月与 5—12 月：窗口费用与紧急购电量对照';
AX_L  = [0.095 0.310 0.345 0.545];
AX_R  = [0.590 0.310 0.345 0.545];
XTIT  = 0.022;
ANN   = [0.095 0.055 0.845 0.175];
BW    = 0.45;

% ---------- 出图 ----------
SL = cell(size(D, 1), 1);       % 分段标签：原表编码 → 论文口径
for k = 1:size(D, 1)
    if strcmp(D.seg{k}, 'Feb_Apr')
        SL{k} = '2—4 月';
    else
        SL{k} = '5—12 月';
    end
end
x  = (1:numel(SL)).';
cw = D.cost / 1e4;              % 元 → 万元

f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% 左：窗口费用
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
bar(ax1, x, cw, BW, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
set(ax1, 'XTick', x, 'XTickLabel', SL, 'XTickLabelRotation', 0);
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
set(ax2, 'XTick', x, 'XTickLabel', SL, 'XTickLabelRotation', 0);
xlim(ax2, [0.4, numel(x) + 0.6]);
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
    sprintf('2—4 月：费用 %.2f 万元、紧急购电 %.0f kWh（%.2f 万 kWh）。', cw(1), D.em_kwh(1), D.em_kwh(1) / 1e4), ...
    sprintf('5—12 月：费用 %.2f 万元、紧急购电 %.0f kWh（%.2f 万 kWh），紧急购电为前段的 %.1f 倍。', ...
            cw(2), D.em_kwh(2), D.em_kwh(2) / 1e4, D.em_kwh(2) / D.em_kwh(1))});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
