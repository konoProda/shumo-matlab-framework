function func_fig_style(ax, varargin)
% 图件统一外观：白底黑字、字体、图名下置
%
% 输入  ax  目标坐标轴
% 可选参数
%   'Title'     图名（放在图幅下方居中，楷体加粗，图内不带图号）
%   'TitleFigY' 图名的图归一化纵坐标（默认 0.02，图幅矮或刻度标签长时调小）
%
% 外观约定
%   图例、刻度、轴标签   宋体 22
%   图名                 楷体 24 加粗
%   背景                 纯白；所有文字与坐标轴一律黑色
%
% 用法  func_fig_style(gca, 'Title', '典型日计划购电策略')

FS_BODY  = 22;
FS_TITLE = 24;

p = inputParser;
addParameter(p, 'Title', '');
addParameter(p, 'TitleFigY', 0.02);
parse(p, varargin{:});
opt = p.Results;

% 背景与文字颜色都要显式指定：只把底色刷白、不指定字色的话，
% 深色主题会把刻度与轴名渲染成浅灰，出图后是灰字白底。
fh = ancestor(ax, 'figure');
set(fh, 'Color', 'w', 'InvertHardcopy', 'off');
set(ax, 'Color', 'w');

set(ax, 'FontName', 'SimSun', 'FontSize', FS_BODY);
set(ax, 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k');
set(get(ax, 'XLabel'), 'FontName', 'SimSun', 'FontSize', FS_BODY, 'Color', 'k');
set(get(ax, 'YLabel'), 'FontName', 'SimSun', 'FontSize', FS_BODY, 'Color', 'k');
set(get(ax, 'ZLabel'), 'FontName', 'SimSun', 'FontSize', FS_BODY, 'Color', 'k');
set(get(ax, 'Title'),  'FontName', 'SimSun', 'FontSize', FS_BODY, 'Color', 'k');

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
               'EdgeColor', 'none', 'Color', 'k', 'FontName', 'KaiTi', ...
               'FontWeight', 'bold', 'FontSize', FS_TITLE);
end
end
