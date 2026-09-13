function func_fig_style(ax, varargin)
% 图件统一外观：白底、字体、图名下置
%
% 输入  ax  目标坐标轴
% 可选参数
%   'Title'     图名（放在图幅下方居中，楷体加粗，图内不带图号）
%   'TitleFigY' 图名的图归一化纵坐标（默认 0.02，图幅矮或刻度标签长时调小）
%
% 外观约定（与人修图对齐）
%   图例、刻度、轴标签   宋体 22
%   图名                 楷体 24 加粗
%   背景                 纯白（显式指定，不随 MATLAB 主题变化）
%
% 本机未装 SimSun / KaiTi，按同风格字体替代：
%   宋体 → Noto Serif CJK SC    楷体 → AR PL UKai CN
%
% 用法  func_fig_style(gca, 'Title', '典型日计划购电策略')

FONT_KAI = pick_font({'KaiTi', 'AR PL UKai CN', 'AR PL UKai TW', 'STKaiti'}, 'AR PL UKai CN');
FONT_SONG = pick_font({'SimSun', 'Noto Serif CJK SC', 'AR PL UMing CN', 'STSong'}, 'Noto Serif CJK SC');
FS_BODY = 22;
FS_TITLE = 24;

p = inputParser;
addParameter(p, 'Title', '');
addParameter(p, 'TitleFigY', 0.02);
parse(p, varargin{:});
opt = p.Results;

% 白底：图窗与坐标区都显式指定，并关掉打印时的底色反相，
% 否则在深色主题下导出会得到黑底（2026-09-13 踩过）。
fh = ancestor(ax, 'figure');
set(fh, 'Color', 'w', 'InvertHardcopy', 'off');
set(ax, 'Color', 'w');

set(ax, 'FontName', FONT_SONG, 'FontSize', FS_BODY);
set(get(ax, 'XLabel'), 'FontName', FONT_SONG, 'FontSize', FS_BODY);
set(get(ax, 'YLabel'), 'FontName', FONT_SONG, 'FontSize', FS_BODY);
set(get(ax, 'ZLabel'), 'FontName', FONT_SONG, 'FontSize', FS_BODY);

box(ax, 'off');
ax.LineWidth = 1.2;
grid(ax, 'off');

if ~isempty(opt.Title)
    % 把横轴名往上收：22 号刻度标签把默认位置压得很低，会与图幅底部的图名叠在一起。
    % 只在要放图名时才收，避免影响其它版面。
    xl = get(ax, 'XLabel');
    u0 = xl.Units;
    xl.Units = 'normalized';
    xl.Position(2) = -0.26;
    xl.Units = u0;

    annotation(fh, 'textbox', [0, opt.TitleFigY, 1, 0.06], 'String', opt.Title, ...
               'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
               'EdgeColor', 'none', 'FontName', FONT_KAI, ...
               'FontWeight', 'bold', 'FontSize', FS_TITLE);
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
