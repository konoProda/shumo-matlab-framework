% compare_pricing.m — 问题2 方案A(主模型) vs 方案B(对比) 对比脚本（Q4裁定）
% 用途: 论文"定价策略对比"章节 —— 输出对比表与利润对比图
% 运行: matlab -batch "run('scripts/compare_pricing.m')"（在 shumo/2023c/ 下任意目录均可）
% 依赖: src/ 各函数已生成, outputs/ 预处理 CSV 已存在（缺省时自动重跑预处理）

clear; close all; clc;

%% 0. 路径
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
FIG_DIR = fullfile(PROJ_ROOT, 'figures');
addpath(fullfile(PROJ_ROOT, 'src'));                  % 函数路径

%% 1. 若预处理产物缺失则先执行预处理与问题1
if ~exist(fullfile(OUT_DIR, 'product_info.csv'), 'file')
    prod_info = func_preprocess(PROJ_ROOT);
else
    opts = detectImportOptions(fullfile(OUT_DIR, 'product_info.csv'), 'TextType', 'string');
    opts.VariableNames = {'prod_code', 'prod_name', 'class_code', 'class_name', 'loss'};
    opts.VariableTypes = {'string', 'string', 'string', 'string', 'double'};
    prod_info = readtable(fullfile(OUT_DIR, 'product_info.csv'), opts);
end
stats_q1 = func_q1_statistics(prod_info, PROJ_ROOT);
result_q2 = func_q2_category_lp(stats_q1, prod_info, PROJ_ROOT);

%% 2. 对比表 (方案A vs 方案B)
fprintf('\n===== 问题2 方案A/B 对比 (Q4裁定: 主模型A) =====\n');
fprintf('方案A(固定加成, LP):  7天总利润 %.2f 元\n', result_q2.profit_A);
fprintf('方案B(价格离散, MILP): 7天总利润 %.2f 元\n', result_q2.profit_B);
fprintf('方案B相对A提升: %.2f%%\n', ...
        (result_q2.profit_B - result_q2.profit_A) / max(result_q2.profit_A, eps) * 100);

cmp_tbl = table({'方案A(主模型)'; '方案B(对比)'}, ...
                [result_q2.profit_A; result_q2.profit_B], ...
    'VariableNames', {'方案', '7天总利润元'});
writetable(cmp_tbl, fullfile(OUT_DIR, 'q2_compare_AB.csv'), 'Encoding', 'UTF-8');
fprintf('对比表已保存: outputs/q2_compare_AB.csv\n');
