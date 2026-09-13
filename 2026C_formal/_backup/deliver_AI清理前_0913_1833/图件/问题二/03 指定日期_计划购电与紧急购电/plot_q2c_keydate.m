%% 二分二至四个指定日期的计划购电量与紧急购电量（逐 10 分钟）
% 改图只需改本文件顶部的参数区。

% 读同目录 data.csv，输出 PNG 与 PDF。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% --- 参数 ---
FIG_W = 20;  FIG_H = 24;
NAME  = '问题二 指定日期_计划购电与紧急购电';
TITLE = '二分二至四个指定日期的计划购电量与紧急购电量（逐 10 分钟）';
POS   = [0.130 0.575 0.325 0.300;       % 左上 / 右上 / 左下 / 右下
         0.605 0.575 0.325 0.300;
         0.130 0.150 0.325 0.300;
         0.605 0.150 0.325 0.300];
XTIT  = 0.010;                           % 图名贴底，给下排横轴名"时刻"让位
TOL   = 1e-6;                            % 判定"无紧急购电"的下限（kWh）
TL    = compose('%d:00', 0:6:24);        % 整点刻度标签

% --- 画图 ---
f    = figure('Units', 'centimeters', 'Position', [5 4 FIG_W FIG_H]);
DS   = string(D.date_str);
DAYS = unique(DS, 'stable');
axs  = gobjects(numel(DAYS), 1);
hB   = gobjects(numel(DAYS), 1);         % 计划购电曲线句柄
hE   = gobjects(numel(DAYS), 1);         % 紧急购电曲线句柄

for k = 1:numel(DAYS)
    S  = D(DS == DAYS(k), :);
    XH = (S.slot - 0.5) / 6;             % 槽中点 → 小时
    PK = max([S.buy_kwh; S.em_kwh]);

    ax = axes(f, 'Units', 'normalized', 'Position', POS(k, :));
    axs(k) = ax;
    hold(ax, 'on');
    hB(k) = plot(ax, XH, S.buy_kwh, '-', 'Color', func_fig_pal(1), 'LineWidth', 1.5);
    % 紧急购电用连线而非柱：该量绝大多数时段为 0、只在个别时段跳起，柱形在此量级下几乎看不见
    hE(k) = plot(ax, XH, S.em_kwh, '-', 'Color', func_fig_pal(2), 'LineWidth', 1.8);

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

    % 出现紧急购电的日期：在峰值处标数值
    [vE, iE] = max(S.em_kwh);
    if vE > TOL
        text(ax, XH(iE), vE + 0.035 * PK, sprintf('%.0f', round(vE)), ...
             'HorizontalAlignment', 'center', 'FontSize', 22, 'Color', 'k');
    end

    func_fig_style(ax);
    title(ax, char(DAYS(k)), 'FontSize', 22);
end

% 整图图名（图坐标，全图只画一次）
func_fig_style(axs(1), 'Title', TITLE, 'TitleFigY', XTIT);

% 图例置于全图顶部、坐标区之外
FN = get(get(axs(1), 'XLabel'), 'FontName');
lg = legend(axs(1), [hB(1), hE(1)], {'计划购电量', '紧急购电量'}, 'Orientation', 'horizontal', 'FontSize', 22, 'TextColor', 'k');
lg.Units = 'normalized';
lg.Position = [0.290 0.928 0.420 0.034];
set(lg, 'FontName', FN, 'FontSize', 22, 'Box', 'off', 'TextColor', 'k');

% --- 保存 ---
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');

fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
