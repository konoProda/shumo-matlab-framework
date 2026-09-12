%% plot_q2c_keydate —— 问题二：四个指定日期的计划购电与紧急购电
% 图名:     问题二 指定日期_计划购电与紧急购电
% 对应问题: 问题二（Q2c 现行口径：7 日滚动 SAA + 两阶段 MILP）
% 数据来源: 本目录 data.csv（四个指定日期逐 10 分钟的计划购电与紧急购电，单位 kWh）
% 论文位置: 问题二·结果分析（四个指定日期）
% 支撑结论: 09-23 出现紧急购电，其余三个指定日期为 0

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 18;   FIG_H = 16.5;
NAME  = '问题二 指定日期_计划购电与紧急购电';
TITLE = '二分二至四个指定日期的计划购电量与紧急购电量（逐 10 分钟）';
POS   = [0.133 0.585 0.320 0.255;       % 左上 / 右上 / 左下 / 右下
         0.600 0.585 0.320 0.255;
         0.133 0.206 0.320 0.255;
         0.600 0.206 0.320 0.255];
XTIT  = 0.020;                           % 图名压低，给下排横轴名“时刻”让位
BW    = 0.15;                            % 紧急购电柱宽（小时）
TOL   = 1e-6;                            % 判定"无紧急购电"的下限（kWh）
TL    = compose('%d:00', 0:6:24);        % 整点刻度标签

% ---------- 出图 ----------
f    = figure('Units', 'centimeters', 'Position', [5 4 FIG_W FIG_H]);
DS   = string(D.date_str);
DAYS = unique(DS, 'stable');
axs  = gobjects(numel(DAYS), 1);
hB   = gobjects(numel(DAYS), 1);         % 计划购电曲线句柄
hE   = gobjects(numel(DAYS), 1);         % 紧急购电柱句柄

for k = 1:numel(DAYS)
    S  = D(DS == DAYS(k), :);
    XH = (S.slot - 0.5) / 6;             % 槽中点 → 小时
    PK = max([S.buy_kwh; S.em_kwh]);

    ax = axes(f, 'Units', 'normalized', 'Position', POS(k, :));
    axs(k) = ax;
    hold(ax, 'on');
    hB(k) = plot(ax, XH, S.buy_kwh, '-', 'Color', func_fig_pal(1), 'LineWidth', 1.5);
    hE(k) = bar(ax, XH, S.em_kwh, BW, 'FaceColor', func_fig_pal(2), 'EdgeColor', 'none');

    xlim(ax, [0, 24]);
    ylim(ax, [0, PK * 1.30]);
    xticks(ax, 0:6:24);
    xticklabels(ax, TL);
    ax.YAxis.Exponent = 0;
    if mod(k, 2) == 1
        ylabel(ax, '电量（kWh / 10 min）');      % 左列给纵轴名
    end
    if k > 2
        xlabel(ax, '时刻');                       % 下排给横轴名
    end

    % 出现紧急购电的日期：在最高一根柱上标数值
    [vE, iE] = max(S.em_kwh);
    if vE > TOL
        text(ax, XH(iE), vE + 0.035 * PK, sprintf('%.0f', round(vE)), ...
             'HorizontalAlignment', 'center', 'FontSize', 14);
    end

    func_fig_style(ax);
    title(ax, char(DAYS(k)), 'FontSize', 15);
end

% 整图图名（图坐标，全图只画一次）
func_fig_style(axs(1), 'Title', TITLE, 'TitleFigY', XTIT);

% 图例置于全图顶部、坐标区之外
FN = get(get(axs(1), 'XLabel'), 'FontName');
lg = legend(axs(1), [hB(1), hE(1)], {'计划购电量', '紧急购电量'}, 'Orientation', 'horizontal');
lg.Units = 'normalized';
lg.Position = [0.290 0.928 0.420 0.034];
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
