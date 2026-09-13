%% plot_q3b_keydate —— 问题三：四个指定日期的计划、最终生效计划与紧急购电
% 图名:     问题三 指定日期四阶段轨迹
% 对应问题: 问题三（第二版）
% 数据来源: 本目录 data.csv（四个指定日期逐槽：0:00 原计划、最终生效计划、紧急购电、负荷、光伏）
% 论文位置: 问题三·结果分析（题目指定日期）
% 支撑结论: 四阶段调整在日内预报与实际差异较大的日期显著改变最终生效计划
%
% 版面要点（本轮踩过的两个坑）：
%   ① **图级图名不能靠 `axes(f,...)` 新建坐标区来承载**——它会盖在第一个面板上，
%      表现为"左上角空面板 + 两套刻度"；改用 annotation 放在图幅底部。
%   ② 图例用 figure 级位置显式摆放，避免与面板标题互相挤压。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(THIS_DIR, '..', '..', '..', 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 30;  FIG_H = 20;
NAME  = '问题三 指定日期四阶段轨迹';
TITLE = '四个指定日期的计划与紧急购电';
POS   = [0.080 0.560 0.365 0.300; 0.555 0.560 0.365 0.300; ...
         0.080 0.135 0.365 0.300; 0.555 0.135 0.365 0.300];
LGPOS = [0.250 0.930 0.500 0.040];            % 图例（figure 归一化坐标，置于图幅顶部）
TITLEY = 0.015;                                % 图名 y（底部）
HW    = 1/6;                                   % 每槽小时数
DATES = unique(D.date_str, 'stable');          % readtable 会把该列解析成 datetime

% ---------- 出图 ----------
f = figure('Units','centimeters','Position',[2 2 FIG_W FIG_H]);
for k = 1:numel(DATES)
    % date_str 被 readtable 解析为 datetime，必须用 == 比较（strcmp 对 datetime 恒为 false）
    M = D(D.date_str == DATES(k), :);
    t = (M.slot - 1) * HW;
    ax = axes(f, 'Units','normalized', 'Position', POS(k,:));
    hold(ax,'on');
    area(ax, t, M.load_kw, 'FaceColor', func_fig_pal(6), 'FaceAlpha', 0.25, 'EdgeColor','none');
    plot(ax, t, M.pv_kw,       '-', 'LineWidth', 1.3, 'Color', func_fig_pal(3));
    plot(ax, t, M.plan_kwh/HW, '-', 'LineWidth', 1.5, 'Color', func_fig_pal(2));
    plot(ax, t, M.final_kwh/HW,'-', 'LineWidth', 1.5, 'Color', func_fig_pal(1));
    bar(ax, t, M.em_kwh/HW, HW*0.9, 'FaceColor', func_fig_pal(4), 'EdgeColor','none');

    ytop = max([M.load_kw; M.plan_kwh/HW; M.final_kwh/HW; M.em_kwh/HW; 1]);
    xlim(ax, [0 24]);  ylim(ax, [0, ytop*1.22]);
    set(ax, 'XTick', 0:4:24);
    ax.YAxis.Exponent = 0;
    xlabel(ax, '时刻（时）'); ylabel(ax, '功率（kW）');
    func_fig_style(ax);
    title(ax, datestr(DATES(k), 'yyyy-mm-dd'), 'FontSize', 15);
    set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
    if k == 1
        lg = legend(ax, {'负荷','光伏','0:00 原计划','最终生效计划','紧急购电'}, ...
                    'Orientation','horizontal', 'Box','off', 'FontSize', 13);
        lg.Units = 'normalized';  lg.Position = LGPOS;
    end
end

% 图级图名：用 annotation 放在图幅底部，**不要新建坐标区**
annotation(f, 'textbox', [0 TITLEY 1 0.035], 'String', TITLE, ...
           'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
           'EdgeColor','none', 'FontWeight','bold', 'FontSize', 18);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
