%% plot_q2_season —— 问题二：光伏与负载的月度规律
% 图名:     问题2 光伏与负载的月度规律
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（由 scripts/data_q2_season.m 生成）
% 论文位置: 问题二·结果分析（光伏季节规律 → 净负荷 → 紧急购电 的链条起点）

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF）
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 24;   FIG_H = 11;
NAME  = '光伏与负载的月度规律';
TITLE = '光伏发电量与小区负载的月度规律';
AXPOS = [0.070 0.28 0.895 0.58];
XTIT  = 0.010;
ANN   = [0.070 0.045 0.895 0.19];

lab = compose('%d月', D.month);
x   = 1:numel(lab);
Y   = [D.pv_wankwh, D.load_wankwh];

% ---------- 出图 ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f, 'Units', 'normalized', 'Position', AXPOS);
b  = bar(ax, x, Y, 0.78, 'EdgeColor', 'none');
b(1).FaceColor = func_fig_pal(3);    % 光伏：绿
b(2).FaceColor = func_fig_pal(5);    % 负载：紫

set(ax, 'XTick', x, 'XTickLabel', lab, 'XTickLabelRotation', 0);
ylabel(ax, '月度电量（万 kWh）');
ylim(ax, [0, max(Y(:))*1.22]);
func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);
hold(ax, 'on');  yline(ax, 0, '-', 'Color', func_fig_pal(6));
legend(ax, b, {'光伏发电量', '小区负载'}, 'Location', 'northwest', 'Box', 'off', 'FontSize', 14);

% 光伏占比标在柱上方（现场由 data.csv 计算）
for k = 1:numel(x)
    text(ax, x(k), D.pv_wankwh(k) + max(Y(:))*0.02, sprintf('%.0f%%', D.pv_share_pct(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', func_fig_pal(6));
end

annotation(f, 'textbox', ANN, 'Units', 'normalized', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontName', 'Noto Serif CJK SC', ...
    'String', { ...
        sprintf('柱上灰字为光伏占负载的比例：由 5 月的 %.1f%% 降至 12 月的 %.1f%%，全年平均 %.1f%%。', ...
                max(D.pv_share_pct), min(D.pv_share_pct), mean(D.pv_share_pct)), ...
        sprintf('光伏发电量最高月（%d 月）为最低月（%d 月）的 %.2f 倍；负载的季节波动远小于此。', ...
                D.month(D.pv_wankwh==max(D.pv_wankwh)), D.month(D.pv_wankwh==min(D.pv_wankwh)), ...
                max(D.pv_wankwh)/min(D.pv_wankwh))});

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
