%% plot_q4_struct —— 问题四：两份交付口径的购电结构对照
% 图名:     问题四 购电结构对照
% 对应问题: 问题四
% 数据来源: 本目录 data.csv（long 表：panel / group / series / value）
% 论文位置: 问题四·结果分析
% 支撑结论: 引入日内价格预测更新后，计划购电量下降、调整量出现，紧急购电量显著减少

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(fullfile(THIS_DIR, '..', '..', '..', 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 26;  FIG_H = 12;
NAME  = '问题四 购电结构对照';
TITLE = '两份交付口径的购电结构';
POS   = [0.088 0.230 0.386 0.560; 0.546 0.230 0.386 0.560];
XTIT  = 0.040;
WAN   = 1e4;                                   % kWh → 万 kWh
PN    = {'plan','up','dn','em'};
PL    = {'计划购电','调增','调减','紧急购电'};
DIG   = [1 1 1 1];

% ---------- 出图 ----------
f = figure('Units','centimeters','Position',[3 4 FIG_W FIG_H]);
for k = 1:2
    nm = D.group(1 + (k-1)*4);                 % Q4-2 / Q4-3
    M  = D(strcmp(D.group, nm), :);
    % 表中顺序即 panel 顺序，取 M 的行序与 PN 一致
    v = zeros(numel(PN),1);
    for j = 1:numel(PN)
        r = M(strcmp(M.panel, PN{j}), :);
        if ~isempty(r); v(j) = r.value(1); end
    end
    x = (1:numel(v)).';
    ax = axes(f,'Units','normalized','Position',POS(k,:));
    hold(ax,'on');
    bar(ax, x, v/WAN, 0.42, 'FaceColor', func_fig_pal(1), 'EdgeColor','none');
    xlim(ax, [0.5 numel(v)+0.5]);
    ylim(ax, [0, max(v/WAN)*1.22]);
    set(ax, 'XTick', x, 'XTickLabel', PL, 'XTickLabelRotation', 0);
    ax.YAxis.Exponent = 0;
    ylabel(ax, '电量（万 kWh）');
    func_fig_style(ax);
    set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
    title(ax, nm, 'FontSize', 16);
    for j = 1:numel(v)
        text(ax, x(j), v(j)/WAN + 0.030*max(v/WAN), sprintf('%.1f', v(j)/WAN), ...
             'HorizontalAlignment','center', 'FontSize', 14);
    end
end
func_fig_style(axes(f,'Units','normalized','Position',POS(1,:)), 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
