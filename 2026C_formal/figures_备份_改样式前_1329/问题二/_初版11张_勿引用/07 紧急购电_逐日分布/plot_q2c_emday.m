%% plot_q2c_emday —— 问题二：紧急购电量的逐日分布
% 图名:     问题二 紧急购电_逐日分布
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（逐日紧急购电量，由结果文件落盘）
% 论文位置: 问题二·结果分析
% 支撑结论: 175 天出现紧急购电，合计 269,240.9 kWh；5—12 月显著高于 2—4 月

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24.5;  FIG_H = 11.5;
NAME  = '问题二 紧急购电_逐日分布';
TITLE = '全年逐日紧急购电量';
AXPOS = [0.070 0.290 0.880 0.575];
XTIT  = 0.020;
ANN   = [0.070 0.045 0.880 0.185];
SPLIT = datetime(2025, 4, 30);  % 分段界：2—4 月 / 5—12 月
TOL   = 1e-6;                   % 计入"出现天数"的下限（kWh）

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

bar(ax, D.date, D.em_kwh, 0.9, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');

% 单日峰值标注（365 根柱只标峰值，全柱标值会彼此压字）
[pk, ipk] = max(D.em_kwh);
text(ax, D.date(ipk), pk * 1.04, sprintf('%s 峰值 %.0f kWh', ...
     char(D.date(ipk), 'MM-dd'), pk), 'HorizontalAlignment', 'center', 'FontSize', 14);

xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, pk * 1.16]);
xtickformat(ax, 'MMM');
xlabel(ax, '月份');
ylabel(ax, '紧急购电量（kWh）');
ax.YAxis.Exponent = 0;
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

% 冻结日期轴（避免被 text/xline 重置）
xlim(ax, [D.date(1), D.date(end)]);

% 结论注释（置于坐标区外；合计与占比由 data.csv 现算）
nDay = numel(D.em_kwh);
nEm  = nnz(D.em_kwh > TOL);
iEar = D.date <= SPLIT;         % 2—4 月（1 月无紧急购电）
vEar = sum(D.em_kwh(iEar));
vLat = sum(D.em_kwh(~iEar));
FN = get(get(ax, 'XLabel'), 'FontName');
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('全年合计 %.1f kWh，出现在 %d 天（占 %d 天的 %.0f%%）；单日最大 %.1f kWh。', ...
            sum(D.em_kwh), nEm, nDay, 100 * nEm / nDay, pk), ...
    sprintf('分段：2—4 月合计 %.1f 万 kWh、5—12 月合计 %.1f 万 kWh，后段为前段的 %.1f 倍。', ...
            vEar / 1e4, vLat / 1e4, vLat / vEar)});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
