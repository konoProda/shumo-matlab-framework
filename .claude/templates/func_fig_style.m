function func_fig_style(ax, varargin)
%func_fig_style 全局图件样式：字体/字号/坐标轴/图名下置（2026-09-05 编程手图件规范）
% 输入: ax      - 目标坐标轴
% 可选: 'Title'   字符 - 图名（置于图下方居中，楷体加粗，图内不带图号）
%       'GridOff' 逻辑 - 无网格（默认 false，浅灰网格）
% 用法: func_fig_style(gca, 'Title', '各方案七年总利润')
% 依赖: 配合 func_fig_pal.m 取色；图例样式见 plot 模板

% 字体常量（本机 Linux 出图前须 listfonts 确认，缺楷体先安装 simkai.ttf / AR PL UKai）
FONT_TITLE = 'KaiTi';             % 图名：楷体加粗
FONT_CN    = 'SimSun';            % 轴标签/图例：宋体
FONT_EN    = 'Times New Roman';   % 英文与数字

p = inputParser;
addParameter(p, 'Title', '');
addParameter(p, 'GridOff', false);
parse(p, varargin{:});
opt = p.Results;

% 字号：图内文字 ≥14pt；图名/轴标签 16–18pt；刻度/图例 14–16pt
set(ax, 'FontName', FONT_EN, 'FontSize', 15);
set(get(ax, 'XLabel'), 'FontName', FONT_CN, 'FontSize', 16);
set(get(ax, 'YLabel'), 'FontName', FONT_CN, 'FontSize', 16);
set(get(ax, 'ZLabel'), 'FontName', FONT_CN, 'FontSize', 16);

% 坐标轴：仅左/下轴，主线宽 1.5，浅灰网格
box(ax, 'off');
ax.LineWidth = 1.5;
if ~opt.GridOff
    grid(ax, 'on');
    ax.GridAlpha = 0.15;
    ax.GridColor = [0.85 0.85 0.85];
end

% 图名置于图下方居中（title 的 Position 下移至轴下方）
if ~isempty(opt.Title)
    t = title(ax, opt.Title);
    set(t, 'FontName', FONT_TITLE, 'FontWeight', 'bold', 'FontSize', 17);
    t.Units = 'normalized';
    t.Position(2) = -0.12;   % 负值：图下方；绝对值按图名字数微调
end
end
