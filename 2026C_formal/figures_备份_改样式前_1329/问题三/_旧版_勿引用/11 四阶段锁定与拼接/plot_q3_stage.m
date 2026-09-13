%% plot_q3_stage —— 问题三：四阶段锁定与拼接的结构证据
% 图名:     问题3 四阶段锁定与拼接
% 对应问题: 问题三
% 数据来源: 本目录 data.csv（由 scripts/data_q3_stage.m 生成）
% 论文位置: 检验章（生效购电量确实按"最后一个覆盖该槽的阶段"拼装）

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 17.7;  FIG_H = 11.8;
NAME  = '四阶段锁定与拼接';
TITLE = '各时段的平均调整幅度：被锁定的时段不随后续预报改动';
AXPOS = [0.140 0.245 0.830 0.620];
XTIT  = 0.032;

x = D.stage;
y = D.mean_abs_dev_kwh;

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
hold(ax, 'on');
b = bar(ax, x, y, 0.60, 'EdgeColor', 'none');
b.FaceColor = 'flat';
b.CData = repmat(func_fig_pal(1), 4, 1);
b.CData(1,:) = func_fig_pal(6);               % 被锁定段以中性色

for k = 1:4
    text(ax, k, y(k) + max(y)*0.035, sprintf('%.1f', y(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
end

set(ax, 'XTick', x, 'XTickLabel', D.label);
ylabel(ax, '平均调整幅度（kWh/10 min）');
ylim(ax, [0, max(y)*1.22]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
