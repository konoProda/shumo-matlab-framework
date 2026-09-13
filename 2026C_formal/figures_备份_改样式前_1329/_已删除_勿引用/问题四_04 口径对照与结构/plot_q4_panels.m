%% plot_q4_panels —— 问题四：口径对照与购电结构（四面板）
% 图名:     问题四 口径对照与结构
% 对应问题: 问题四
% 数据来源: 本目录 data.csv（long 表：panel / group / series / value）
% 论文位置: 问题四·结果分析 + 灵敏度分析
% 支撑结论: (a)(b) 电价随机建模与日内价格更新的价值；(c)(d) 购电结构与套利行为的变化
%
% 版面说明：前一版把"四口径对照""购电结构对照""低价充电/高价放电"拆成三张各只有
%           四根柱的小图，数据量太小、彼此重复；本版合并为一张四面板，密度更高。

clear; close all; clc;
THIS_DIR  = fileparts(mfilename('fullpath'));
addpath(fullfile(THIS_DIR, '..', '..', '..', 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'), 'Encoding', 'UTF-8');

% ---------- 绘图参数 ----------
FIG_W = 28;  FIG_H = 17;
NAME  = '问题四 口径对照与结构';
TITLE = '口径对照与购电结构';
POS   = [0.088 0.578 0.372 0.330; 0.556 0.578 0.372 0.330; ...
         0.088 0.128 0.372 0.330; 0.556 0.128 0.372 0.330];
XTIT  = 0.020;
WAN   = 1e4;
PN    = {'cost','em','struct','arbi'};
PT    = {'口径费用对照','口径紧急购电对照','购电结构（Q4-2 与 Q4-3）','低价充电与高价放电'};
YL    = {'窗口费用（万元）','紧急购电量（kWh）','电量（万 kWh）','电量（万 kWh）'};
SR    = {{'cost'}, {'em'}, {'plan','up','dn','em'}, {'chg_lo','dis_hi','chg_all','dis_all'}};
SL    = {{'窗口费用'}, {'紧急购电量'}, {'计划购电','调增','调减','紧急购电'}, ...
         {'低价时段充电','高价时段放电','总充电','总放电'}};

% ---------- 出图 ----------
f = figure('Units','centimeters','Position',[3 3 FIG_W FIG_H]);
for k = 1:numel(PN)
    M = D(strcmp(D.panel, PN{k}), :);
    gps = unique(M.group, 'stable');
    if isempty(gps); continue; end
    v = zeros(numel(gps), numel(SR{k}));
    for gi = 1:numel(gps)
        for si = 1:numel(SR{k})
            r = M(strcmp(M.group, gps(gi)) & strcmp(M.series, SR{k}{si}), :);
            if ~isempty(r); v(gi, si) = r.value(1); end
        end
    end
    if k <= 2; v = v / WAN; end                  % 费用 / 电量换算成万
    ax = axes(f,'Units','normalized','Position',POS(k,:));
    hold(ax,'on');
    b = bar(ax, (1:numel(gps)).', v, 0.72, 'grouped', 'EdgeColor','none');
    for si = 1:min(numel(b), 4); b(si).FaceColor = func_fig_pal(si); end
    xlim(ax, [0.5, numel(gps)+0.5]);
    ylim(ax, [0, max(v(:))*1.24]);
    set(ax, 'XTick', 1:numel(gps), 'XTickLabel', gps, 'XTickLabelRotation', 0);
    ax.YAxis.Exponent = 0;
    ylabel(ax, YL{k});
    func_fig_style(ax);
    set(ax, 'FontName', get(get(ax,'XLabel'),'FontName'));
    title(ax, PT{k}, 'FontSize', 15);
    if k >= 3                                  % 多序列面板加图例（置于坐标区外）
        legend(ax, SL{k}, 'Location','northoutside', 'Orientation','horizontal', ...
               'Box','off', 'FontSize', 12);
    end
    % 逐柱标数据：柱数少（≤8），全部标出
    for gi = 1:numel(gps)
        for si = 1:size(v,2)
            if v(gi,si) <= 0; continue; end
            dx = (si - (size(v,2)+1)/2) * (0.72/size(v,2));
            text(ax, gi + dx, v(gi,si) + 0.026*max(v(:)), sprintf('%.1f', v(gi,si)), ...
                 'HorizontalAlignment','center', 'FontSize', 11, 'Rotation', 90);
        end
    end
end
func_fig_style(axes(f,'Units','normalized','Position',POS(1,:)), 'Title', TITLE, 'TitleFigY', XTIT);

print(f, fullfile(THIS_DIR, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(THIS_DIR, [NAME '.pdf']), '-dpdf');
close(f);
fprintf('已出图：%s\n', fullfile(THIS_DIR, [NAME '.png']));
