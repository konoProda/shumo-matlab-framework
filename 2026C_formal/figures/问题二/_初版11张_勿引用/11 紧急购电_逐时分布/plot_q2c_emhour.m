%% plot_q2c_emhour —— 问题二：紧急购电量的逐时分布
% 图名:     问题二 紧急购电_逐时分布
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（逐时段汇总的紧急购电量与出现槽数）
% 论文位置: 问题二·结果分析
% 支撑结论: 逐时分布出现两个峰：第 21 时段最高（152,365.9 kWh、384 个槽）、次峰在第 9—11 时段；
%           第 13—19 时段为 0。（时段序号口径：第 h 时段 = [(h−1):00, h:00)，横轴刻度为区间起点）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 26;   FIG_H = 12;
NAME  = '问题二 紧急购电_逐时分布';
TITLE = '紧急购电的逐时分布：全年合计与出现槽数';
AX_L  = [0.075 0.300 0.375 0.550];
AX_R  = [0.575 0.300 0.375 0.550];
XTIT  = 0.022;
ANN   = [0.075 0.045 0.875 0.190];
BW    = 0.55;
TOL   = 1e-6;                   % 柱顶标值的下限（kWh）
MORN  = 9:11;                   % 次峰时段（第 9—11 时段）

% ---------- 出图 ----------
x = D.hour;
[~, ipk] = max(D.em_kwh);
vM = sum(D.em_kwh(MORN));

f  = figure('Units', 'centimeters', 'Position', [4 5 FIG_W FIG_H]);

% 左：各时段紧急购电量
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
bar(ax1, x, D.em_kwh, BW, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');
XTL = cellstr(compose('%d:00', (1:2:23) - 1));     % 刻度为各时段起点
set(ax1, 'XTick', 1:2:23, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax1, [0.5, 24.5]);
ylim(ax1, [0, max(D.em_kwh) * 1.20]);
xlabel(ax1, '时刻（小时）');
ylabel(ax1, '紧急购电量（kWh）');
ax1.YAxis.Exponent = 0;
func_fig_style(ax1);
for k = 1:numel(x)
    if D.em_kwh(k) > TOL
        text(ax1, x(k), D.em_kwh(k) + max(D.em_kwh) * 0.03, sprintf('%.0f', D.em_kwh(k)), ...
             'HorizontalAlignment', 'center', 'FontSize', 14);
    end
end

% 右：各时段出现槽数（全年 365 天 × 144 槽范围内）
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
bar(ax2, x, D.n_slot, BW, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
set(ax2, 'XTick', 1:2:23, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax2, [0.5, 24.5]);
ylim(ax2, [0, max(D.n_slot) * 1.22]);
xlabel(ax2, '时刻（小时）');
ylabel(ax2, '出现槽数（个）');
func_fig_style(ax2);
for k = 1:numel(x)
    if D.n_slot(k) > 0
        text(ax2, x(k), D.n_slot(k) + max(D.n_slot) * 0.03, sprintf('%d', D.n_slot(k)), ...
             'HorizontalAlignment', 'center', 'FontSize', 14);
    end
end

% 图名（整图下置）与结论注释（坐标区外；数值由 data.csv 现算）
func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax1, 'XLabel'), 'FontName');
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('全年合计 %.1f kWh；主峰在第 %d 时段（%02d:00—%02d:00）：%.0f kWh、%d 个槽，占全年 %.1f%%。', ...
            sum(D.em_kwh), ipk, ipk - 1, ipk, D.em_kwh(ipk), D.n_slot(ipk), ...
            100 * D.em_kwh(ipk) / sum(D.em_kwh)), ...
    sprintf('次峰在第 9—11 时段（08:00—11:00）合计 %.1f kWh；第 13—19 时段为 0，第 12 时段仅 %.1f kWh。', ...
            vM, D.em_kwh(12))});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
