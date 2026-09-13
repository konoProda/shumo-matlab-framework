%% plot_q2_keydays —— 问题二：二分二至四日的购电与储能曲线
% 图名:     问题2 指定日期购电与储能
% 对应问题: 问题二
% 数据来源: 本目录 data.csv（与脚本同目录）
% 论文位置: 问题二·结果分析（配合论文表1、表2）
% 说明:     四幅子图共用同一坐标位置表，轴标签只画在外缘（左列留左轴标签、右列留右轴标签），
%           避免四组双轴标签互相挤压。

clear; close all; clc;
% 组织方式：本图件自包含于同一文件夹（脚本 + data.csv + PNG + PDF），便于人工查找与修改
THIS_DIR  = fileparts(mfilename('fullpath'));
PROJ_ROOT = fullfile(THIS_DIR, '..', '..', '..');
addpath(fullfile(PROJ_ROOT, 'src'));
D = readtable(fullfile(THIS_DIR, 'data.csv'));

% ---------- 绘图参数 ----------
FIG_W = 15;   FIG_H = 14;
NAME  = '指定日期_购电与储能';
TITLE = '指定日期（二分二至）的计划购电量与储电量';
XTIT  = 0.008;
% 左右列各留出双轴标签的空间：左列 [0.085,0.385]、右列 [0.615,0.915]
POS   = [0.085 0.585 0.285 0.255;      % 左上（右边缘 0.370）
         0.590 0.585 0.285 0.255;      % 右上（右边缘 0.875，右侧留轴标签）
         0.085 0.185 0.285 0.255;      % 左下
         0.590 0.185 0.285 0.255];     % 右下
TL    = {'0','6','12','18','24'};
XD    = unique(D.date);

% ---------- 出图 ----------
f = figure('Units', 'centimeters', 'Position', [5 4 FIG_W FIG_H]);
axs = gobjects(numel(XD), 1);
for k = 1:numel(XD)
    S  = D(D.date == XD(k), :);
    ax = axes(f, 'Units', 'normalized', 'Position', POS(k,:));
    axs(k) = ax;  hold(ax, 'on');

    XH = (2*S.slot - 1) / 12;                      % 槽中点 → 小时
    area(ax, XH, S.buy_kwh, 'FaceColor', func_fig_pal(1), 'FaceAlpha', 0.85, 'EdgeColor', 'none');

    yyaxis(ax, 'right');
    plot(ax, XH, S.E_kwh, '-', 'Color', func_fig_pal(2), 'LineWidth', 1.7);

    xlim(ax, [0 24]);
    xticks(ax, 0:6:24);  xticklabels(ax, TL);  ax.XTickLabelRotation = 0;

    yyaxis(ax, 'left');   ylim(ax, [0, max(S.buy_kwh) * 1.30]);
    if mod(k,2) == 1, ylabel(ax, '购电量（kWh）'); end
    yyaxis(ax, 'right');  ylim(ax, [0, 12500]);
    if mod(k,2) == 0, ylabel(ax, '储电量（kWh）'); end

    if k > 2, xlabel(ax, '时刻（小时）'); end
    func_fig_style(ax);
    title(ax, char(XD(k), 'yyyy-MM-dd'), 'FontSize', 15);
end

% 图名置于整图下方（图坐标，只画一次）
FN = get(get(axs(1),'XLabel'), 'FontName');
annotation(f, 'textbox', [0, XTIT, 1, 0.05], 'String', TITLE, ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
           'EdgeColor', 'none', 'FontName', FN, 'FontWeight', 'bold', 'FontSize', 17);

% 图例仅在第一幅图给出；手动定位到图顶，避免 'northoutside' 压缩首幅坐标轴
lg = legend(axs(1), {'计划购电量', '储电量'}, 'Orientation', 'horizontal');
lg.Units = 'normalized';
lg.Position = [0.30 0.945 0.40 0.032];
set(lg, 'FontName', FN, 'FontSize', 14, 'Box', 'off');

% ---------- 导出 ----------
fig_dir = THIS_DIR;
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
close(f);
