%% plot_q2_soc_cmp —— 问题二：逐日策略与全年联合基准的储电量轨迹对照
% 图名:     问题2 两模型储电量轨迹
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（与脚本同目录）
% 论文位置: 问题二·结果分析（支撑两模型 0.23% 费用差）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 15;   FIG_H = 10;
NAME  = '储能_逐日与全年对照';
TITLE = '逐日策略与全年联合基准的储电量轨迹';
AXPOS = [0.135 0.275 0.800 0.575];
XTIT  = 0.018;
E_MIN = 1200;   E_MAX = 10800;

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 运行区间带：先铺底，避免遮挡数据线
patch(ax, [D.date(1) D.date(end) D.date(end) D.date(1)], ...
      [E_MIN E_MIN E_MAX E_MAX], func_fig_pal(6), ...
      'FaceAlpha', 0.10, 'EdgeColor', 'none');

p2 = plot(ax, D.date, D.E0_year_kwh,  '-', 'Color', func_fig_pal(1), 'LineWidth', 1.7);
p1 = plot(ax, D.date, D.E0_daily_kwh, '-', 'Color', func_fig_pal(4), 'LineWidth', 1.7);

xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, E_MAX * 1.12]);
xtickformat(ax, 'MMM');
xlabel(ax, '月份');
ylabel(ax, '0:00 储电量（kWh）');

func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax,'XLabel'), 'FontName');

% 平均水位参考线：放在数据线下方空白区，避免压住曲线；数值由绘图数据现场计算
mY = mean(D.E0_year_kwh);
plot(ax, [D.date(1) D.date(end)], [mY mY], '--', 'Color', func_fig_pal(1), 'LineWidth', 1.1);
text(ax, D.date(6), 2700, sprintf('全年联合均值 %.0f kWh', mY), ...
     'FontSize', 14, 'Color', func_fig_pal(1));

hl = [patch(ax, NaN, NaN, func_fig_pal(6), 'FaceAlpha', 0.25, 'EdgeColor','none'), p1, p2];
lg = legend(ax, hl, {'运行区间', '逐日策略', '全年联合'}, ...
            'Orientation', 'horizontal', 'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');
xlim(ax, [D.date(1), D.date(end)]);

% ---------- 导出 ----------
fig_dir = THIS_DIR;
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
close(f);
