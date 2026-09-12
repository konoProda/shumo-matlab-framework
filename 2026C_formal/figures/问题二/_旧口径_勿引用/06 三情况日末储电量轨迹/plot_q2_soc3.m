%% plot_q2_soc3 —— 问题二：三种情况的日末储电量轨迹
% 图名:     问题2 三情况日末储电量轨迹
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（由 scripts/data_q2_soc3.m 生成）
% 论文位置: 问题二·结果分析 / 模型评价（储能备用电量的形成）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF）
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 22;   FIG_H = 10;
NAME  = '三情况日末储电量轨迹';
TITLE = '三种情况的日末储电量';
AXPOS = [0.098 0.30 0.862 0.56];
XTIT  = 0.010;
ANN   = [0.098 0.055 0.862 0.19];
E_MIN = 1200;  E_MAX = 10800;
FEB1  = datetime(2025,2,1);

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');

% 先画三条曲线，坐标轴才切换为时间轴，之后的参考线才能按日期落位
p1 = plot(ax, D.date, D.E_ideal, '-',  'Color', func_fig_pal(2), 'LineWidth', 2.4);
p2 = plot(ax, D.date, D.E_nocorr, '-', 'Color', func_fig_pal(6), 'LineWidth', 1.1);
p3 = plot(ax, D.date, D.E_corr, '-',   'Color', func_fig_pal(1), 'LineWidth', 1.1);

% 上下界参考线与报送窗口起点（同变量同色：灰）
yline(ax, E_MAX, '--', 'Color', func_fig_pal(6), 'LineWidth', 1.2);
yline(ax, E_MIN, '--', 'Color', func_fig_pal(6), 'LineWidth', 1.2);
xline(ax, FEB1, ':', 'Color', func_fig_pal(6), 'LineWidth', 1.4);

ylabel(ax, '日末储电量（kWh）');
xlim(ax, [D.date(1), D.date(end)]);
ylim(ax, [0, E_MAX*1.10]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
legend(ax, [p1 p2 p3], {'① 理想（完美信息）', '② 无纠偏带预测', '③ 有纠偏带预测'}, ...
       'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);

ri = D.date >= FEB1;
annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', 'Noto Serif CJK SC', ...
    'String', { ...
        sprintf('报送窗口日末储电量均值（kWh）：理想 %.0f、无纠偏 %.0f、有纠偏 %.0f。', ...
                mean(D.E_ideal(ri)), mean(D.E_nocorr(ri)), mean(D.E_corr(ri))), ...
        sprintf('三者同量级：备用电量由跨日调配内生形成，而非人为设定。')});

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
