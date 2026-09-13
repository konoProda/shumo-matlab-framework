%% plot_q3b_sets —— 问题三：四个预报时点组合的对照
% 图名:     问题三 四时点组合对照
% 对应问题: 问题三（第二版）
% 数据来源: 本目录 data.csv（long 表：panel / group / series / value）
% 论文位置: 问题三·结果分析（"是否需要引入其他时刻的光伏预报"）
% 支撑结论: 加入 6:00 预报收益最大，12:00 与 18:00 的边际收益递减

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(fullfile(THIS_DIR, '..', '..', '..', 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 12;
NAME  = '问题三 四时点组合对照';
TITLE = '四个预报时点组合的对照';
POS   = [0.088 0.230 0.258 0.560; 0.385 0.230 0.258 0.560; ...
         0.682 0.230 0.258 0.560];
XTIT  = 0.045;
PN    = {'cost','em','soc'};
YL    = {'窗口总费用（万元）','窗口紧急购电量（kWh）','日末储电量均值（kWh）'};
DIG   = [1 0 0];

% ---------- 出图 ----------
f = figure('Units','centimeters','Position',[3 4 FIG_W FIG_H]);
for k = 1:numel(PN)
    M = D(strcmp(D.panel, PN{k}), :);
    v = M.value;
    if k == 1; v = v / 1e4; end                 % 元 → 万元
    x = (1:numel(v)).';
    ax = axes(f,'Units','normalized','Position',POS(k,:));
    hold(ax,'on');
    bar(ax, x, v, 0.46, 'FaceColor', func_fig_pal(1), 'EdgeColor','none');
    xlim(ax, [0.5, numel(v)+0.5]);
    ylim(ax, [0, max(v)*1.20]);
    set(ax, 'XTick', x, 'XTickLabel', M.group, 'XTickLabelRotation', 0);
    ax.YAxis.Exponent = 0;
    ylabel(ax, YL{k});
    func_fig_style(ax);
    set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
    for j = 1:numel(v)
        text(ax, x(j), v(j) + 0.030*max(v), sprintf(['%.' num2str(DIG(k)) 'f'], v(j)), ...
             'HorizontalAlignment','center', 'FontSize', 14);
    end
end
func_fig_style(axes(f,'Units','normalized','Position',POS(1,:)), 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
