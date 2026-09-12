%% plot_q2c_year —— 问题二：全年逐日计划购电、已购未用与弃光
% 图名:     问题二 全年逐日购电与弃光
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（逐日结果，由结果文件落盘）
% 论文位置: 问题二·结果分析
% 支撑结论: 计划购电、已购未用 W、弃光 V 的量级与季节分布

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24.5;  FIG_H = 11.5;
NAME  = '问题二 全年逐日购电与弃光';
TITLE = '全年逐日计划购电量、已购未用电量与弃光量';
AXPOS = [0.070 0.290 0.880 0.575];
XTIT  = 0.020;
ANN   = [0.070 0.045 0.880 0.185];
KEY   = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];
TOL   = 1e-3;                  % 计入"出现天数"的下限（kWh）

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 三条曲线同为电量（kWh），共用 y 轴：购电量在下、已购未用与弃光叠加在上
area(ax, D.date, D.buy_kwh,   'FaceColor', func_fig_pal(1), 'FaceAlpha', 0.85, 'EdgeColor', 'none');
area(ax, D.date, D.waste_kwh, 'FaceColor', func_fig_pal(5), 'FaceAlpha', 0.75, 'EdgeColor', 'none');
area(ax, D.date, D.curt_kwh,  'FaceColor', func_fig_pal(4), 'FaceAlpha', 0.70, 'EdgeColor', 'none');

% 二分二至四个指定日期（竖直点线）
for k = 1:numel(KEY)
    xline(ax, KEY(k), ':', 'Color', func_fig_pal(6), 'LineWidth', 1.2);
end

xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, max(D.buy_kwh) * 1.22]);
xtickformat(ax, 'MMM');
xlabel(ax, '月份');
ylabel(ax, '电量（kWh）');
ax.YAxis.Exponent = 0;          % 刻度用整数显示，不用 ×10⁴ 指数标
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

FN = get(get(ax, 'XLabel'), 'FontName');
hl = [patch(ax, NaN, NaN, func_fig_pal(1), 'EdgeColor', 'none'), ...
      patch(ax, NaN, NaN, func_fig_pal(5), 'EdgeColor', 'none'), ...
      patch(ax, NaN, NaN, func_fig_pal(4), 'EdgeColor', 'none')];
lg = legend(ax, hl, {'计划购电量', '已购未用 W', '弃光量 V'}, 'Orientation', 'horizontal', ...
            'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% 冻结日期轴（legend/xline 之后重设，避免被重置）
xlim(ax, [D.date(1), D.date(end)]);

% 结论注释（置于坐标区外）
tos = @(v) v / 1e4;             % kWh → 万 kWh
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('全年计划购电 %.2f 万 kWh；已购未用 W %.2f 万 kWh（%d 天出现）、弃光 V %.2f 万 kWh（%d 天出现）。', ...
            tos(sum(D.buy_kwh)), tos(sum(D.waste_kwh)), nnz(D.waste_kwh > TOL), ...
            tos(sum(D.curt_kwh)), nnz(D.curt_kwh > TOL)), ...
    sprintf('竖直点线为二分二至四个指定日期（03-20、06-21、09-23、12-21）。')});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
