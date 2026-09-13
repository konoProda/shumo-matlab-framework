%% plot_q2c_horizon —— 问题二：滚动视野长度对费用与储能利用的影响
% 图名:     问题二 视野对照_费用与储能利用
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（R=1/3/7 三组运行的窗口费用与日末储电量均值）
% 论文位置: 问题二·灵敏度分析
% 支撑结论: R=1 日末均值仅 1,961 kWh（储能不被跨日利用）；R=3 与 R=7 只差 28 元

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 22.5;  FIG_H = 11.5;
NAME  = '问题二 视野对照_费用与储能利用';
TITLE = '滚动视野长度 R 对窗口费用与日末储电量的影响';
AX_L  = [0.090 0.310 0.355 0.545];
AX_R  = [0.585 0.310 0.355 0.545];
XTIT  = 0.022;
ANN   = [0.090 0.055 0.850 0.175];
BW    = 0.42;
HL    = 1;                      % 需强调的处理位置（R=1，短视对照）

% ---------- 出图 ----------
x  = (1:numel(D.R)).';
RL = cellstr(compose('R=%d', D.R));
cw = D.cost / 1e4;              % 元 → 万元
Ee = D.Eend_mean;

f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% 左：窗口费用
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
b1 = bar(ax1, x, cw, BW, 'FaceColor', 'flat', 'EdgeColor', 'none');
b1.CData = repmat(func_fig_pal(1), numel(x), 1);
b1.CData(HL, :) = func_fig_pal(4);
set(ax1, 'XTick', x, 'XTickLabel', RL, 'XTickLabelRotation', 0);
xlim(ax1, [0.4, numel(x) + 0.6]);
ylim(ax1, [0, max(cw) * 1.20]);
ylabel(ax1, '窗口费用（万元）');
func_fig_style(ax1);
for k = 1:numel(x)
    text(ax1, x(k), cw(k) + max(cw) * 0.035, sprintf('%.2f', cw(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 右：日末储电量均值
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
b2 = bar(ax2, x, Ee, BW, 'FaceColor', 'flat', 'EdgeColor', 'none');
b2.CData = repmat(func_fig_pal(1), numel(x), 1);
b2.CData(HL, :) = func_fig_pal(4);
set(ax2, 'XTick', x, 'XTickLabel', RL, 'XTickLabelRotation', 0);
xlim(ax2, [0.4, numel(x) + 0.6]);
ylim(ax2, [0, max(Ee) * 1.22]);
ylabel(ax2, '日末储电量均值（kWh）');
ax2.YAxis.Exponent = 0;
func_fig_style(ax2);
for k = 1:numel(x)
    text(ax2, x(k), Ee(k) + max(Ee) * 0.035, sprintf('%.0f', Ee(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

% 图名（整图下置）与结论注释（坐标区外）
func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax1, 'XLabel'), 'FontName');
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('R=1（红柱）：日末均值仅 %.0f kWh，储能未被跨日利用；费用比 R=3 高 %.2f 万元。', Ee(HL), cw(HL) - cw(2)), ...
    sprintf('R=3 → R=7：费用仅再降 %.0f 元、日末均值再升 %.1f kWh，可见视野 3 天已基本足够。', ...
            D.cost(2) - D.cost(3), Ee(3) - Ee(2))});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
