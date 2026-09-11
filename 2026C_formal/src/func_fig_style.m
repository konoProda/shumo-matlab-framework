function func_fig_style(ax, varargin)
%func_fig_style 全局图件样式：字体/字号/坐标轴/图名下置
% 输入: ax      - 目标坐标轴
% 可选: 'Title'       字符 - 图名（置于图下方居中，楷体加粗，图内不带图号）
%       'TitleFigY'   数值 - 图名的图归一化纵坐标（默认 0.02；图幅矮或刻度标签长时调小）
%       'GridOff'     逻辑 - 无网格（默认 false，浅灰网格）
%
% 图名用 annotation 以图坐标定位：置于坐标轴之外，不与刻度标签、轴标签争位
% 用法: func_fig_style(gca, 'Title', '典型日计划购电策略')
%
% 字体：本机无楷体/宋体/Times New Roman，按候选表回退到同风格开源字体
% 字号：图内文字 ≥14pt；图名/轴标签 16–18pt（硬约束，不因字体回退而放宽）

FONT_TITLE = pick_font({'KaiTi','AR PL UKai CN','AR PL UKai TW','STKaiti'}, 'AR PL UKai CN');
FONT_CN    = pick_font({'SimSun','Noto Serif CJK SC','AR PL UMing CN','STSong'}, 'Noto Serif CJK SC');
FONT_EN    = pick_font({'Times New Roman','Nimbus Roman','Liberation Serif','DejaVu Serif'}, 'DejaVu Serif');

p = inputParser;
addParameter(p, 'Title', '');
addParameter(p, 'TitleFigY', 0.02);
addParameter(p, 'GridOff', false);
parse(p, varargin{:});
opt = p.Results;

set(ax, 'FontName', FONT_EN, 'FontSize', 15);
set(get(ax, 'XLabel'), 'FontName', FONT_CN, 'FontSize', 16);
set(get(ax, 'YLabel'), 'FontName', FONT_CN, 'FontSize', 16);
set(get(ax, 'ZLabel'), 'FontName', FONT_CN, 'FontSize', 16);

box(ax, 'off');
ax.LineWidth = 1.5;
if ~opt.GridOff
    grid(ax, 'on');
    ax.GridAlpha = 0.15;
    ax.GridColor = [0.85 0.85 0.85];
end

if ~isempty(opt.Title)
    fh = ancestor(ax, 'figure');
    annotation(fh, 'textbox', [0, opt.TitleFigY, 1, 0.05], 'String', opt.Title, ...
               'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
               'EdgeColor', 'none', 'FontName', FONT_TITLE, ...
               'FontWeight', 'bold', 'FontSize', 17);
end
end

function nm = pick_font(cands, fallback)
% 按候选表取本机可用字体：先精确匹配，再包含匹配，全不中则用兜底名
persistent cache
if isempty(cache)
    cache = listfonts;
end
for k = 1:numel(cands)
    hit = find(strcmpi(cache, cands{k}), 1);
    if ~isempty(hit); nm = cache{hit}; return; end
end
for k = 1:numel(cands)
    hit = find(contains(cache, cands{k}, 'IgnoreCase', true), 1);
    if ~isempty(hit); nm = cache{hit}; return; end
end
nm = fallback;
end
