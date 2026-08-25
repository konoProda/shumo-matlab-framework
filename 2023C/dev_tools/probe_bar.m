% probe_bar.m — 探针: 实测本环境 bar() 对 2×7 与 7×2 矩阵的渲染语义 + 真实数据维度
% 2×7 矩阵
Y27 = [1 2 3 4 5 6 7; 10 20 30 40 50 60 70];
f1 = figure('Visible', 'off');
b1 = bar(Y27);
fprintf('bar(2x7): 序列数(每组的柱数)=%d, 组数=%d\n', numel(b1), numel(b1(1).XEndPoints));
close(f1);
% 7×2 矩阵
Y72 = Y27';
f2 = figure('Visible', 'off');
b2 = bar(Y72);
fprintf('bar(7x2): 序列数(每组的柱数)=%d, 组数=%d\n', numel(b2), numel(b2(1).XEndPoints));
close(f2);
% 真实数据: 从 q2 结果 CSV 读取并推算每日利润维度
sf = mfilename('fullpath');
if ~startsWith(sf, filesep), sf = fullfile(pwd, sf); end
PROJ = fileparts(fileparts(sf));
opts = detectImportOptions(fullfile(PROJ, 'outputs', 'q2_strategy_A.csv'), 'TextType', 'string');
T = readtable(fullfile(PROJ, 'outputs', 'q2_strategy_A.csv'), opts);
fprintf('q2_strategy_A.csv 尺寸: %s\n', mat2str(size(T)));
disp(head(T, 2));
