%% plot_q2c_soc —— 问题二：日末储电量轨迹与日内波动范围
% 图名:     问题二 日末储电量轨迹
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（逐日 E_end / 日内最小 / 日内最大，由结果文件落盘）
% 论文位置: 问题二·结果分析
% 支撑结论: 日末均值 7,046 kWh；窗口内 1,190 槽触底，验证滚动视野的正常最优行为

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24.5;  FIG_H = 11.5;
NAME  = '问题二 日末储电量轨迹';
TITLE = '日末储电量轨迹与日内波动范围（2025 年 365 天）';
AXPOS = [0.075 0.280 0.875 0.585];
XTIT  = 0.020;
ANN   = [0.075 0.045 0.875 0.180];
E_MIN = 1200;  E_MAX = 10800;
W0    = datetime(2025, 2, 1);   % 报送窗口起点（窗口外为 1 月）

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 日内波动范围（最小—最大）以浅色带表示，日末值以实线叠加
xb = [D.date; flipud(D.date)];
yb = [D.E_day_min; flipud(D.E_day_max)];
hband = fill(ax, xb, yb, func_fig_pal(6), 'FaceAlpha', 0.22, 'EdgeColor', 'none');
hline = plot(ax, D.date, D.E_end, '-', 'Color', func_fig_pal(1), 'LineWidth', 1.8);

% 储电量上/下限点线
yline(ax, E_MIN, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
yline(ax, E_MAX, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.1);
text(ax, D.date(4), E_MAX * 1.015, sprintf('上限 %s', addcomma(E_MAX)), ...
     'FontSize', 14, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'bottom');
text(ax, D.date(4), E_MIN * 1.06, sprintf('下限 %s', addcomma(E_MIN)), ...
     'FontSize', 14, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'bottom');
xline(ax, W0, ':', 'Color', func_fig_pal(4), 'LineWidth', 1.4);
text(ax, W0 + days(4), E_MAX * 0.80, '02-01 窗口起点', 'FontSize', 14, 'Color', func_fig_pal(4));

xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, E_MAX * 1.08]);
xtickformat(ax, 'MMM');
xlabel(ax, '月份');
ylabel(ax, '储电量（kWh）');
ax.YAxis.Exponent = 0;
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

FN = get(get(ax, 'XLabel'), 'FontName');
lg = legend(ax, [hband hline], {'日内波动范围（最小—最大）', '日末储电量'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% 冻结日期轴（legend/xline 之后重设，避免被重置）
xlim(ax, [D.date(1), D.date(end)]);

% 结论注释（置于坐标区外；统计量由 data.csv 现算）
iw  = D.date >= W0;
E_w = D.E_end(iw);
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', FN, 'String', { ...
    sprintf('报送窗口（02-01 起 %d 天）日末均值 %.0f kWh；窗口内日末最小 %.0f、最大 %.0f kWh。', ...
            nnz(iw), mean(E_w), min(E_w), max(E_w)), ...
    sprintf('1 月（31 天）不在报送窗口内，日末值恒为 8,550 kWh；点线为储电量上、下限。')});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);

function s = addcomma(v)
% 千位分隔（仅用于坐标区外的文字标注，5 位以内）
s = sprintf('%d', v);
if numel(s) > 3
    s = [s(1:end-3) ',' s(end-2:end)];
end
end
