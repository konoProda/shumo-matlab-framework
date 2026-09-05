%% plot_template：图件模板（复制为 <题目>/src/plot_qX_<图名>.m，文件名与输出同名）
% 一图一文件，独立可运行（只读 outputs/final_results.mat 与 data/），人工改图后单独重跑
%
% 图名:      （待填，与文件名、图内图名一致）
% 对应问题:  （待填，问题一/二/三/四）
% 数据来源:  outputs/final_results.mat 中变量（待填）
% 论文位置:  （待填，如 5.2 结果分析）

clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');   % 题目根目录
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results.mat'), '<变量名>');  % 按需修改

% ---------- 绘图参数（集中定义，无魔法数） ----------
FIG_W = 15;              % 全宽 15cm 印刷尺寸；半宽图改 7.5
FIG_H = 9.5;             % 高度（图名下置需多留底部空间）
NAME  = '<qX_图名>';     % 输出文件名，与脚本名一致
TITLE = '<图名>';        % 图内图名（置于图下方，不带图号）

% ---------- 出图（图型按 /code 决策表选；样式统一走 func_fig_style） ----------
f  = figure('Units', 'centimeters', 'Position', [5 5 FIG_W FIG_H]);
ax = axes(f);
% ...绘图主体：数据来自 S，颜色用 func_fig_pal(k)，标注按分层策略（见 /code）...

func_fig_style(ax, 'Title', TITLE);
% 图例（若需）：
% lg = legend(ax, {...}, 'Location', 'best');
% set(lg, 'FontName', 'SimSun', 'FontSize', 14, 'Box', 'off');

% ---------- 导出：300dpi PNG（入论文）+ PDF（矢量存档）；EPS 仅模板要求时 ----------
fig_dir = fullfile(PROJ_ROOT, 'figures');
print(f, fullfile(fig_dir, [NAME '.png']), '-dpng', '-r300');
print(f, fullfile(fig_dir, [NAME '.pdf']), '-dpdf');
close(f);   % 立即释放图形内存（3GB 环境）

% 导出前目检：轴含义+单位 / 图例归属 / 标签不重叠且不被轴裁切 / 连线按 x 排序 /
%            灰度可区分 / LaTeX 已渲染 / 放大到论文页宽文字可读
