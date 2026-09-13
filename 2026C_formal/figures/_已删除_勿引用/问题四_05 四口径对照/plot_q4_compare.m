%% plot_q4_compare —— 问题四：正式口径与两类评价基准的对照
% 图名:     问题四 四口径对照
% 对应问题: 问题四
% 数据来源: 本目录 data.csv（long 表：panel / group / series / value）
% 论文位置: 问题四·结果分析 + 灵敏度分析
% 支撑结论: 电价随机建模带来费用下降；若提前知道真实电价还能进一步下降，其差额即价格不确定性的代价

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(fullfile(THIS_DIR, '..', '..', '..', 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 12;
NAME  = '问题四 四口径对照';
TITLE = '正式口径与评价基准的对照';
POS   = [0.088 0.230 0.386 0.560; 0.546 0.230 0.386 0.560];
XTIT  = 0.040;
WAN   = 1e4;
PN    = {'cost','em'};
YL    = {'窗口总费用（万元）','窗口紧急购电量（kWh）'};
DIG   = [1 0];

% ---------- 出图 ----------
f = figure('Units','centimeters','Position',[3 4 FIG_W FIG_H]);
for k = 1:numel(PN)
    M = D(strcmp(D.panel, PN{k}), :);
    v = M.value;
    if k == 1; v = v / WAN; end
    x = (1:numel(v)).';
    ax = axes(f,'Units','normalized','Position',POS(k,:));
    hold(ax,'on');
    bar(ax, x, v, 0.40, 'FaceColor', func_fig_pal(1), 'EdgeColor','none');
    xlim(ax, [0.5 numel(v)+0.5]);
    ylim(ax, [0, max(v)*1.22]);
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
