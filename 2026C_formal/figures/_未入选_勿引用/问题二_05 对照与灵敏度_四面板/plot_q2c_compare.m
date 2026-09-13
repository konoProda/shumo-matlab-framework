%% 四组口径的对照与灵敏度

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

%% 绘图参数
FIG_W = 20;  FIG_H = 20;
NAME  = '问题二 对照与灵敏度_四面板';
TITLE = '四组口径的对照与灵敏度';
POS   = [0.120 0.560 0.355 0.330;       % (a) 左上 / (b) 右上 / (c) 左下 / (d) 右下
         0.605 0.560 0.355 0.330;
         0.120 0.130 0.355 0.330;
         0.605 0.130 0.355 0.330];
XTIT  = 0.010;
WAN   = 1e4;                             % 元 → 万元（单位换算常数）
PN    = {'ladder', 'horizon', 'kscen', 'ablate'};    % 各面板对应的 panel 取值
SR    = {'cost', 'aux', 'aux', 'aux'};               % 各面板取用的 series
PT    = {'信息集阶梯', '视野长度', '情景数', '偏差校正消融'};
YL    = {'窗口费用（万元）', '日末储电量均值（kWh）', ...
         '窗口紧急购电量（kWh）', '窗口紧急购电量（kWh）'};
CID   = [1 3 2 2];                       % 取色：费用 / 储电量 / 紧急购电量（同一变量全图同色）
YT    = {0:400:1600, 0:2000:8000, 0:1e5:3e5, 0:1e5:3e5};    % 固定刻度，标签宽度可控
DIG   = [2 1 1 1];                       % 柱顶数值小数位：费用两位，电量一位（R=3 与 R=7 需区分）

%% 出图
f = figure('Units', 'centimeters', 'Position', [4 4 FIG_W FIG_H]);

for k = 1:numel(PN)
    M  = D(strcmp(D.panel, PN{k}) & strcmp(D.series, SR{k}), :);
    v  = M.value;
    if strcmp(SR{k}, 'cost')
        v = v / WAN;                     % 费用统一折万元
    end
    gp = cellstr(string(M.group));       % 组名按 data.csv 行序（与总览文档表 3—6 同序）
    x  = (1:numel(v)).';

    ax = axes(f, 'Units', 'normalized', 'Position', POS(k, :));
    hold(ax, 'on');
    bar(ax, x, v, 0.46, 'FaceColor', func_fig_pal(CID(k)), 'EdgeColor', 'none');

    xlim(ax, [0.5, numel(v) + 0.5]);
    ylim(ax, [0, YT{k}(end) * 1.12]);
    set(ax, 'XTick', x, 'XTickLabel', gp, 'XTickLabelRotation', 0, 'YTick', YT{k});
    ax.YAxis.Exponent = 0;               % 纵轴写全数字，不用 ×10^n

    ylabel(ax, YL{k});
    func_fig_style(ax);
    if k == 1
        func_fig_style(ax, 'Title', TITLE, 'TitleFigY', XTIT);    % 全图图名，图坐标定位
    end
    title(ax, PT{k}, 'FontSize', 22);

    % 逐柱标数据（每面板至多三根柱，柱顶标值不压字）
    for j = 1:numel(v)
        text(ax, x(j), v(j) + 0.030 * YT{k}(end), sprintf(['%.' num2str(DIG(k)) 'f'], v(j)), ...
             'HorizontalAlignment', 'center', 'FontSize', 22, 'Color', 'k');
    end
end

%% 导出
print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
