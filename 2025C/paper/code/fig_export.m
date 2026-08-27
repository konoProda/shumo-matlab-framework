function fig_export(fig, fig_dir, name, dpi)
% 图形导出 PNG（300dpi 默认）与 EPS，导出后立即关闭释放内存
if nargin < 4, dpi = 300; end
print(fig, fullfile(fig_dir, [name '.png']), '-dpng', ['-r' num2str(dpi)]);
print(fig, fullfile(fig_dir, [name '.eps']), '-depsc');
close(fig);
end
