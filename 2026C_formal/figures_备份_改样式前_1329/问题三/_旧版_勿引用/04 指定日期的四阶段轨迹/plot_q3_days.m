%% plot_q3_days —— 问题三：四个指定日期的"计划—生效—执行"轨迹
% 图名:     问题3 指定日期的四阶段轨迹
% 对应问题: 问题三
% 数据来源: 本目录 data_2025-03-20.csv 等 4 个（由 scripts/data_q3_days.m 生成）
% 论文位置: 问题三·结果分析（配合论文表 1/表 2 的指定日期结果）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));

% ---------- 绘图参数 ----------
FIG_W = 24.8;  FIG_H = 17.7;
NAME  = '指定日期的四阶段轨迹';
TITLE = '四个指定日期的购电计划、生效值与紧急购电（10 分钟粒度）';
XTIT  = 0.032;
FILES = {'data_2025-03-20.csv', 'data_2025-06-21.csv', 'data_2025-09-23.csv', 'data_2025-12-21.csv'};
AXP = {[0.090 0.580 0.390 0.295], [0.545 0.580 0.390 0.295], ...
       [0.090 0.130 0.390 0.295], [0.545 0.130 0.390 0.295]};

f = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
tlab = {'2025-03-20（春分）', '2025-06-21（夏至）', '2025-09-23（秋分）', '2025-12-21（冬至）'};

for k = 1:4
    D = readtable(fullfile(THIS_DIR, FILES{k}));
    ax = axes(f, 'Units', 'normalized', 'Position', AXP{k});
    hold(ax, 'on');
    % 阶段分界（6:00 / 12:00 / 18:00）
    for sb = [37 73 109]
        xline(ax, sb - 0.5, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.9);
    end
    b = bar(ax, D.slot, D.em_kwh, 1.0, 'FaceColor', func_fig_pal(4), 'EdgeColor', 'none');
    p1 = plot(ax, D.slot, D.plan_kwh, '-', 'Color', func_fig_pal(6), 'LineWidth', 1.6);
    p2 = plot(ax, D.slot, D.adj_kwh, '-', 'Color', func_fig_pal(1), 'LineWidth', 1.8);

    if k <= 2                              % 上排不重复横轴标签，避免与下排面板标题相撞
        set(ax, 'XTick', [1 37 73 109 144], 'XTickLabel', []);
    else
        set(ax, 'XTick', [1 37 73 109 144], 'XTickLabel', {'0:00','6:00','12:00','18:00','24:00'});
    end
    if mod(k, 2) == 1                      % 仅左列标注纵轴，避免与右列面板重叠
        ylabel(ax, '电量（kWh/10 min）');
    end
    xlim(ax, [0.5, 144.5]);
    ylim(ax, [0, max([D.plan_kwh; D.adj_kwh])*1.18]);
    title(ax, {tlab{k}, sprintf('全天生效购电 %.0f kWh', sum(D.adj_kwh))}, ...
          'FontSize', 14, 'FontName', 'Noto Serif CJK SC');
    func_fig_style(ax);
    if k == 1
        legend(ax, [p1 p2 b], {'0:00 原计划', '最终生效', '紧急购电'}, ...
               'Location', 'northoutside', 'Orientation', 'horizontal', ...
               'Box', 'off', 'FontSize', 13);
    end
end
annotation(f, 'textbox', [0 0.030 1 0.055], 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'FontSize', 17, 'FontWeight', 'bold', ...
    'FontName', 'AR PL UKai CN', 'String', TITLE);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
