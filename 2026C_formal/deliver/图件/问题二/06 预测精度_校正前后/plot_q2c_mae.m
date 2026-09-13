%% 偏差校正前后的预测误差：MAE 与 RMSE
% 画的是 data.csv 里的逐条记录，数据与图放在同一个文件夹。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% --- 参数 ---
FIG_W = 20;  FIG_H = 10;
NAME  = '问题二 预测精度_校正前后';
TITLE = '偏差校正前后的预测误差：MAE 与 RMSE';
AX_L  = [0.080 0.300 0.360 0.550];
AX_R  = [0.590 0.300 0.360 0.550];
XTIT  = 0.008;
BW    = 0.80;                            % 整组柱宽：组内两柱间距须容下柱顶数值标签
IT    = {'负荷', '光伏', '净负荷'};       % 横轴三个对象
KD    = {'原始', '校正后'};               % 组内两根柱

% ---------- 数据整形（按 item / kind 取数，不依赖行序） ----------
MAE = zeros(numel(IT), numel(KD));
RMS = zeros(numel(IT), numel(KD));
for i = 1:numel(IT)
    for k = 1:numel(KD)
        m = strcmp(D.item, IT{i}) & strcmp(D.kind, KD{k});
        MAE(i, k) = D.mae(m);
        RMS(i, k) = D.rmse(m);
    end
end

% --- 画图 ---
x  = (1:numel(IT)).';
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);

% 左：MAE
ax1 = axes(f, 'Units', 'normalized', 'Position', AX_L);
hold(ax1, 'on');
b1 = bar(ax1, x, MAE, BW);
b1(1).FaceColor = func_fig_pal(6);
b1(2).FaceColor = func_fig_pal(1);
set(b1, 'EdgeColor', 'none');
ylim(ax1, [0, max(MAE(:)) * 1.22]);
xlim(ax1, [0.4, numel(IT) + 0.6]);
set(ax1, 'XTick', x, 'XTickLabel', IT, 'XTickLabelRotation', 0);
ylabel(ax1, 'MAE（kW）');
func_fig_style(ax1, 'Title', TITLE, 'TitleFigY', XTIT);
for k = 1:numel(b1)
    text(ax1, b1(k).XEndPoints, b1(k).YEndPoints + 0.030 * max(MAE(:)), ...
         cellstr(compose('%.1f', b1(k).YEndPoints)), ...
         'HorizontalAlignment', 'center', 'FontSize', 22);
end

% 右：RMSE
ax2 = axes(f, 'Units', 'normalized', 'Position', AX_R);
hold(ax2, 'on');
b2 = bar(ax2, x, RMS, BW);
b2(1).FaceColor = func_fig_pal(6);
b2(2).FaceColor = func_fig_pal(1);
set(b2, 'EdgeColor', 'none');
ylim(ax2, [0, max(RMS(:)) * 1.22]);
xlim(ax2, [0.4, numel(IT) + 0.6]);
set(ax2, 'XTick', x, 'XTickLabel', IT, 'XTickLabelRotation', 0);
ylabel(ax2, 'RMSE（kW）');
func_fig_style(ax2);
for k = 1:numel(b2)
    text(ax2, b2(k).XEndPoints, b2(k).YEndPoints + 0.030 * max(RMS(:)), ...
         cellstr(compose('%.1f', b2(k).YEndPoints)), ...
         'HorizontalAlignment', 'center', 'FontSize', 22);
end

% 图例置于坐标区之外（图归一化坐标固定，避免压缩坐标轴）
CNF = get(get(ax1, 'XLabel'), 'FontName');
set(ax1, 'FontName', CNF);               % 横轴刻度为中文，整轴改用中文字体
set(ax2, 'FontName', CNF);
lg = legend(ax1, b1, KD, 'Orientation', 'horizontal');
lg.Units = 'normalized';
lg.Position = [0.360 0.912 0.280 0.038];
set(lg, 'FontName', CNF, 'FontSize', 22, 'Box', 'off');

% --- 保存 ---
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
