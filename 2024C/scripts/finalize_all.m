% finalize_all.m —— /report 收尾：生成论文图件 + 打包 final_results.mat
% 依赖：三问解、q3_stats、sensitivity.csv 均已存在
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
OUT_DIR = fullfile(PROJ_ROOT, 'outputs');

% ---- 1. 论文图件（含灵敏度 CSV 合规重绘） ----
run(fullfile(PROJ_ROOT, 'scripts', 'gen_paper_figures.m'));

% ---- 2. 打包 final_results.mat ----
S1 = load(fullfile(OUT_DIR, 'q1_solution.mat'));
S2 = load(fullfile(OUT_DIR, 'q2_solution.mat'));
S3 = load(fullfile(OUT_DIR, 'q3_solution.mat'));
ST = load(fullfile(OUT_DIR, 'q3_stats.mat'));
sens_tbl = readtable(fullfile(OUT_DIR, 'sensitivity.csv'));

final_results = struct( ...
    'sol_q1_case1', S1.sol_case1, 'sol_q1_case2', S1.sol_case2, ...
    'sol_q2', S2.sol_q2, 'sol_q3', S3.sol_q3, ...
    'rho_sp', S3.rho_sp, 'clusters', S3.clusters, ...
    'sensitivity', sens_tbl, ...
    'packaged', datestr(now));
save(fullfile(OUT_DIR, 'final_results.mat'), 'final_results');
fprintf('final_results.mat 打包完成\n');
