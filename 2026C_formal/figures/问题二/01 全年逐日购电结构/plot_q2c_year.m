%% plot_q2c_year —— 问题二：全年逐日购电结构
% 图名:     问题二 全年逐日购电结构
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（逐日计划购电 / 已购未用 W / 弃光 V / 紧急购电，单位 kWh）
% 论文位置: 问题二·结果分析
% 支撑结论: 四类电量的逐日量级与季节分布，峰值集中在夏秋两季

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;   FIG_H = 12.5;
NAME  = '问题二 全年逐日购电结构';
TITLE = '全年逐日购电结构：计划购电、已购未用、弃光与紧急购电';
AXPOS = [0.115 0.300 0.841 0.550];      % 左边界按 6 位刻度值宽度留白，纵轴名“电量（kWh）”才不被挤出画布
XTIT  = 0.028;                          % 图名的图归一化纵坐标，图内不带图号
CID   = [1 5 4 2];                      % 四条序列取色：计划 / W / V / 紧急
ALPHA = [0.42 0.45 0.45 0.55];          % 面积透明度（自下而上依次叠加）
DPK   = 0.030;                          % 峰值标签纵向偏移（占纵轴范围）
KEYS  = [datetime(2025,3,20); datetime(2025,6,21);
         datetime(2025,9,23); datetime(2025,12,21)];      % 二分二至四个指定日

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [4 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 四条序列同为电量（kWh），共用纵轴：面积自零线起画、半透明叠加，另描实线轮廓
Y = [D.buy_kwh, D.waste_kwh, D.curt_kwh, D.em_kwh];
hA = gobjects(size(Y, 2), 1);
for k = 1:size(Y, 2)
    hA(k) = area(ax, D.date, Y(:, k), 'FaceColor', func_fig_pal(CID(k)), ...
                 'FaceAlpha', ALPHA(k), 'EdgeColor', 'none');
end
for k = 1:size(Y, 2)
    plot(ax, D.date, Y(:, k), '-', 'Color', func_fig_pal(CID(k)), 'LineWidth', 1.3);
end

% 四个指定日期（竖直点线，参考线）
for k = 1:numel(KEYS)
    xline(ax, KEYS(k), ':', 'Color', func_fig_pal(6), 'LineWidth', 1.1);
end

YMAX = max(Y(:)) * 1.16;
xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, YMAX]);
xtickformat(ax, 'MMM');
xlabel(ax, '月份');
ylabel(ax, '电量（kWh）');
ax.YAxis.Exponent = 0;
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

% 逐条序列的峰值数值标签（365 天过密，不做逐点标值）
ALN = {'right', 'left', 'left', 'right'};
for k = 1:size(Y, 2)
    [v, i] = max(Y(:, k));
    text(ax, D.date(i), v + DPK * YMAX, sprintf('%d', round(v)), ...
         'FontSize', 14, 'Color', func_fig_pal(CID(k)), 'HorizontalAlignment', ALN{k});
end

FN = get(get(ax, 'XLabel'), 'FontName');
hk = plot(ax, D.date(1:2), nan(2, 1), ':', 'Color', func_fig_pal(6), 'LineWidth', 1.1);
lg = legend(ax, [hA; hk], {'计划购电量', '已购未用 W', '弃光量 V', '紧急购电量', '二分二至'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');
xlim(ax, [D.date(1), D.date(end)]);     % 图例会重置日期轴，冻结一次

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
