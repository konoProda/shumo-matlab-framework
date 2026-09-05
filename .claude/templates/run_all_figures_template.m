%% run_all_figures：汇总驱动全部 plot_qX_*.m（复制为 <题目>/src/run_all_figures.m）
% 用法：人工修图后重跑本文件即可重生成整套论文图；按需增删行
% 注意：3GB 环境单 MATLAB 会话铁律——顺序执行，每图导出后已 close

plot_q1_xxx;
plot_q2_xxx;
% ...

disp('全部图件已重生成，请对照图件清单表核对。');
