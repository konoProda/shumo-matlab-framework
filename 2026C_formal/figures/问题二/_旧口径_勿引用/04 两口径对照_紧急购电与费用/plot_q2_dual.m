%% plot_q2_dual —— 问题二：两种执行口径的紧急购电对照
% 图名:     问题2 两口径对照_紧急购电与费用
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（与脚本同目录，由 scripts/data_q2_dual.m 生成）
% 论文位置: 问题二·第二部分结果分析 / 模型评价（对比消融口径与正式口径）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 16;   FIG_H = 14;
NAME  = '两口径对照_紧急购电与费用';
TITLE = '两种执行口径的紧急购电对照';
AXPOS = [0.10 0.34 0.86 0.54];      % 坐标轴：底部留出标注框与图名
XTIT  = 0.008;                      % 图名（楷体，图下方居中）
ANN   = [0.10 0.075 0.86 0.20];     % 口径摘要标注框（图归一化）
Z1_WIN = 12210827.42;    % 完美信息基准窗口总费用（元），出处 outputs/q2_daily.csv 合计

% ---------- 摘要量（由 data.csv 现场计算，不硬编码）----------
tot = [sum(D.em_kwh_plan),  sum(D.em_kwh_corr)];      % 全年紧急购电量 kWh
fee = [sum(D.em_yuan_plan), sum(D.em_yuan_corr)];     % 全年紧急购电费 元
prc = fee ./ tot;                                     % 电量加权单价 元/kWh
voi = 100*([sum(D.tot_yuan_plan), sum(D.tot_yuan_corr)] - Z1_WIN)/Z1_WIN;

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
b  = bar(ax, [D.em_kwh_plan, D.em_kwh_corr]/1e4, 0.78, 'EdgeColor', 'none');
b(1).FaceColor = func_fig_pal(6);    % 照计划执行：消融对照 → 灰
b(2).FaceColor = func_fig_pal(1);    % 实时纠偏：正式口径 → 主蓝

% 刻度标签显式置零旋转：默认自动旋转在多类别中文标签下会倾斜，影响可读性
set(ax, 'XTick', 1:11, 'XTickLabel', compose('%d月', D.month), 'XTickLabelRotation', 0);
ylim(ax, [0, max([D.em_kwh_plan; D.em_kwh_corr])/1e4 * 1.30]);
ylabel(ax, '紧急购电量（万 kWh）');    % 刻度已含月份，不再另设 x 轴标签

hold(ax, 'on');
yline(ax, 0, '-', 'Color', func_fig_pal(6));    % y 轴含 0 基线
% 图例置于轴内左上（2、3 月柱极矮，该处留白），并显式绑定柱对象以排除 0 基线
legend(ax, b, {'照计划执行（消融对照）', '日内实时纠偏（正式口径）'}, ...
       'Location', 'northwest', 'Box', 'off', 'FontSize', 14);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

annotation(f, 'textbox', ANN, 'Units', 'normalized', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'left', 'FontSize', 14, ...
    'FontName', 'Noto Serif CJK SC', ...
    'String', { ...
        sprintf('报送窗口紧急购电量：%.1f → %.1f 万 kWh（%+.0f%%）', tot(1)/1e4, tot(2)/1e4, 100*(tot(2)-tot(1))/tot(1)), ...
        sprintf('报送窗口紧急购电费：%.1f → %.1f 万元（%+.1f%%）',   fee(1)/1e4, fee(2)/1e4, 100*(fee(2)-fee(1))/fee(1)), ...
        sprintf('电量加权单价：%.2f → %.2f 元/kWh', prc(1), prc(2)), ...
        sprintf('信息价值 VoI：%.1f%% → %.1f%%（基准为完美信息）', voi(1), voi(2))});

% ---------- 导出 ----------
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
