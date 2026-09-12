%% plot_q2c_emhour —— 问题二：紧急购电的逐时分布
% 图名:     问题二 紧急购电_逐时分布
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（24 个时段各自的紧急购电量与出现槽数，窗口内统计）
% 论文位置: 问题二·结果分析
% 支撑结论: 主峰在第 21 时段（时钟 20:00—21:00），次峰在 08:00—11:00，中午至傍晚基本为 0

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
% 时段口径：第 h 段 = 时钟 (h−1):00 — h:00，横轴刻度标各段起点
FIG_W = 28;   FIG_H = 12.5;
NAME  = '问题二 紧急购电_逐时分布';
TITLE = '紧急购电的逐时分布：全年合计与出现槽数';
AX_L  = [0.110 0.290 0.364 0.545];      % 左边界按 6 位刻度值宽度留白，纵轴名不被挤出画布
AX_R  = [0.556 0.290 0.416 0.545];
XTIT  = 0.026;
BW    = 0.52;                            % 柱宽
ROT   = 90;                              % 柱顶数值标签旋转角（柱密，竖排避免压字）
TOL   = 1e-6;                            % 低于此值按 0 处理、不标数值（kWh）

% ---------- 出图 ----------
x   = D.hour(:);
XT  = 1:3:22;                            % 每隔 3 小时一个刻度，标签不挤
XTL = cellstr(compose('%d:00', XT - 1));

f  = figure('Units', 'centimeters', 'Position', [3 5 FIG_W FIG_H]);

% 左：各时段紧急购电量
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
bar(ax1, x, D.em_kwh, BW, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');
MX1 = max(D.em_kwh) * 1.42;              % 留出竖排数值标签的高度
set(ax1, 'XTick', XT, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax1, [0.5, 24.5]);
ylim(ax1, [0, MX1]);
xlabel(ax1, '时段起点（时）');
ylabel(ax1, '紧急购电量（kWh）');
ax1.YAxis.Exponent = 0;
func_fig_style(ax1);
% 只标足够高的柱：低于最大值 4% 的柱逐根标值会堆出一排竖排数字
for k = 1:numel(x)
    if D.em_kwh(k) > 0.04 * max(D.em_kwh)
        text(ax1, x(k), D.em_kwh(k) + 0.012 * MX1, sprintf('%.0f', D.em_kwh(k)), ...
             'Rotation', ROT, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
             'FontSize', 14);
    end
end

% 右：各时段紧急购电出现的槽数（窗口 334 天 × 每小时 6 槽）
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
bar(ax2, x, D.n_slot, BW, 'FaceColor', func_fig_pal(1), 'EdgeColor', 'none');
MX2 = max(D.n_slot) * 1.42;
set(ax2, 'XTick', XT, 'XTickLabel', XTL, 'XTickLabelRotation', 0);
xlim(ax2, [0.5, 24.5]);
ylim(ax2, [0, MX2]);
xlabel(ax2, '时段起点（时）');
ylabel(ax2, '出现槽数（个）');
ax2.YAxis.Exponent = 0;
func_fig_style(ax2);
% 同上：过小的柱不标数值
for k = 1:numel(x)
    if D.n_slot(k) > 0.04 * max(D.n_slot)
        text(ax2, x(k), D.n_slot(k) + 0.012 * MX2, sprintf('%d', D.n_slot(k)), ...
             'Rotation', ROT, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
             'FontSize', 14);
    end
end

func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
