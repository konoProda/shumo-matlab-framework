%% plot_q2_year —— 问题二：全年逐日购电量与弃光量
% 图名:     问题2 全年购电与弃光
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（与脚本同目录）
% 论文位置: 问题二·结果分析

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数（集中定义） ----------
FIG_W = 15;   FIG_H = 10.5;
NAME  = '全年购电与弃光';
TITLE = '全年逐日购电量与弃光量';
AXPOS = [0.115 0.255 0.775 0.60];
XTIT  = 0.018;
KEY   = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 购电量用面积、弃光量用面积叠加（同一 y 轴，单位一致）
area(ax, D.date, D.buy_kwh, 'FaceColor', func_fig_pal(1), 'FaceAlpha', 0.85, 'EdgeColor', 'none');
area(ax, D.date, D.curt_kwh, 'FaceColor', func_fig_pal(4), 'FaceAlpha', 0.75, 'EdgeColor', 'none');

% 关键日期（题面表3 指定的二分二至）竖线
for k = 1:numel(KEY)
    xline(ax, KEY(k), ':', 'Color', func_fig_pal(6), 'LineWidth', 1.2);
end

xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, max(D.buy_kwh) * 1.22]);
xtickformat(ax, 'MMM');
xlabel(ax, '月份');
ylabel(ax, '电量（kWh）');

func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
FN = get(get(ax,'XLabel'), 'FontName');
hl = [patch(ax, NaN, NaN, func_fig_pal(1), 'EdgeColor','none'), ...
      patch(ax, NaN, NaN, func_fig_pal(4), 'EdgeColor','none')];
lg = legend(ax, hl, {'计划购电量', '弃光量'}, 'Orientation', 'horizontal', ...
            'Location', 'northoutside');
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% 冻结日期轴（legend/xline 之后重设，避免被重置）
xlim(ax, [D.date(1), D.date(end)]);

% ---------- 导出 ----------
fig_dir = THIS_DIR;
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
close(f);
