%% plot_q2c_keydate —— 问题二：二分二至四个指定日期的计划购电与紧急购电
% 图名:     问题二 指定日期_计划购电与紧急购电
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（四个指定日期逐槽的计划购电量与紧急购电量）
% 论文位置: 问题二·结果分析（四个指定日期）
% 支撑结论: 四个指定日期的计划购电与紧急购电形态；仅 09-23 出现紧急购电 5,351.69 kWh
% 说明:     四幅子图共用坐标位置表，轴标签只画在外缘（左列留 y 轴标签、下排留 x 轴标签），
%           避免四组标签互相挤压；图例只给首幅。

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 17;   FIG_H = 15;
NAME  = '问题二 指定日期_计划购电与紧急购电';
TITLE = '二分二至四个指定日期的计划购电量与紧急购电量（逐 10 分钟）';
XTIT  = 0.016;
POS   = [0.100 0.580 0.340 0.275;      % 左上
         0.570 0.580 0.340 0.275;      % 右上
         0.100 0.180 0.340 0.275;      % 左下
         0.570 0.180 0.340 0.275];     % 右下
TL    = compose('%d:00', 0:6:24);
TOL   = 1e-6;                           % 判定"当日无紧急购电"的下限（kWh）

% ---------- 出图 ----------
f    = figure('Units', 'centimeters', 'Position', [5 4 FIG_W FIG_H]);
DS   = string(D.date_str);
DAYS = unique(DS, 'stable');
axs  = gobjects(numel(DAYS), 1);

for k = 1:numel(DAYS)
    S  = D(DS == DAYS(k), :);
    ax = axes(f, 'Units', 'normalized', 'Position', POS(k, :));
    axs(k) = ax;
    hold(ax, 'on');

    XH = (S.slot - 0.5) / 6;                    % 槽中点 → 小时
    plot(ax, XH, S.buy_kwh, '-', 'Color', func_fig_pal(1), 'LineWidth', 1.5);
    bar(ax, XH, S.em_kwh, 0.15, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');

    MX = max([S.buy_kwh; S.em_kwh]);
    xlim(ax, [0, 24]);
    ylim(ax, [0, MX * 1.35]);
    xticks(ax, 0:6:24);
    xticklabels(ax, TL);
    ax.XTickLabelRotation = 0;
    ax.YAxis.Exponent = 0;
    if mod(k, 2) == 1, ylabel(ax, '电量（kWh/10 min）'); end
    if k > 2,          xlabel(ax, '时刻（小时）');       end

    % 当日紧急购电合计（由本图 data.csv 现算）
    vE = sum(S.em_kwh);
    if vE > TOL
        text(ax, 0.6, MX * 1.20, sprintf('当日紧急购电 %.1f kWh', vE), ...
             'FontSize', 14, 'Color', func_fig_pal(2));
    else
        text(ax, 0.6, MX * 1.20, '当日无紧急购电', 'FontSize', 14, 'Color', func_fig_pal(6));
    end

    func_fig_style(ax);
    title(ax, char(DAYS(k)), 'FontSize', 15);
end

% 整图图名（图坐标，只画一次）
FN = get(get(axs(1), 'XLabel'), 'FontName');
annotation(f, 'textbox', [0, XTIT, 1, 0.05], 'String', TITLE, ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
           'EdgeColor', 'none', 'FontName', FN, 'FontWeight', 'bold', 'FontSize', 17);

% 图例只给首幅，手动定位到图顶，避免 'northoutside' 压缩首幅坐标轴
lg = legend(axs(1), {'计划购电量', '紧急购电量'}, 'Orientation', 'horizontal');
lg.Units = 'normalized';
lg.Position = [0.30 0.935 0.40 0.032];
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
