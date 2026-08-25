%% main_2025C.m — 2025C NIPT 时点选择与胎儿异常判定主程序
% 用途：串联数据读取、预处理、问题一~四建模与灵敏度分析，结果统一落盘
% 依赖子函数：load_data / preprocess / q1_correlation_regression /
%             q2_bmi_group_timing / q3_multifactor_timing /
%             q4_female_abnormal_judge / sensitivity_analysis
% 输出：outputs/final_results.mat、outputs/tables/*.csv、figures/*.png|eps

clear; close all; clc;

%% 路径与输出目录
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');  % 题目根目录
addpath(fullfile(PROJ_ROOT, 'src'));   % 子函数目录加入搜索路径
data_path = fullfile(PROJ_ROOT, 'data', '附件.xlsx');
tbl_dir   = fullfile(PROJ_ROOT, 'outputs', 'tables');
fig_dir   = fullfile(PROJ_ROOT, 'figures');
out_dir   = fullfile(PROJ_ROOT, 'outputs');
if ~exist(tbl_dir, 'dir'), mkdir(tbl_dir); end
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

%% 全局参数（编号对应 outputs/math_to_code_mapping.md）
cfg = struct();
cfg.thr_y       = 0.04;                        % P2   达标阈值 Y >= 0.04
cfg.c_risk      = [1, 5, 20];                  % Q2-4 时间风险 c1 < c2 < c3
cfg.lambda_risk = 10;                          % Q2-5 不达标惩罚系数 λ
cfg.K           = 4;                           % Q2-3 分组数 K = 4
cfg.n_min       = 20;                          % Q2-3 组最小孕妇数（不可行放宽至 10）
cfg.cut_step    = 2;                           % 切点搜索候选步长（1=全枚举，2=隔位加速）
cfg.t_grid      = (10:1/7:25)';                % Q2-7 候选检测时点按天枚举（106 点）
cfg.eta_target  = 0.85;                        % Q3-7 达标比例下限 η
cfg.mc_iters    = 500;                         % Q2-8 蒙特卡洛次数 M
cfg.rho_gc      = 1;                           % Q4-7 异常类型判定系数 ρ
cfg.recall_min  = 0.90;                        % Q4-6 偏召回补充阈值的召回率目标
cfg.lambda_grid = [5, 10, 20];                 % 灵敏度分析 λ 取值
cfg.eta_grid    = [0.80, 0.85, 0.90, 0.95];    % 灵敏度分析 η 取值
cfg.rho_grid    = [0.5, 1, 2];                 % 灵敏度分析 ρ 取值
cfg.sigma_scale = [0.5, 1, 2];                 % 灵敏度分析 σ 缩放倍数
cfg.tbl_dir = tbl_dir;  cfg.fig_dir = fig_dir;  cfg.out_dir = out_dir;

%% (1) 数据读取与预处理（P1~P6）
[male_raw, female_raw] = load_data(data_path);
male   = preprocess_data(male_raw,   'male',   cfg);
female = preprocess_data(female_raw, 'female', cfg);

%% (2) 问题一：Y 浓度相关特性与关系模型（Q1-1~Q1-6）
res1 = q1_correlation_regression(male, cfg);

%% (3) 问题二：BMI 分组与最佳 NIPT 时点（Q2-1~Q2-8）
res2 = q2_bmi_group_timing(male, cfg, res1.sigma_resid);

%% (4) 问题三：多因素修正下的分组与时点优化（Q3-1~Q3-8）
res3 = q3_multifactor_timing(male, cfg, res1.sigma_resid, res2);

%% (5) 问题四：女胎异常判定（Q4-1~Q4-9）
res4 = q4_female_abnormal_judge(female, cfg);

%% (6) 灵敏度分析（λ / η / ρ / σ）
sens = sensitivity_analysis(male, female, cfg, res1, res2, res3, res4);

%% (7) 结果落盘
save(fullfile(out_dir, 'final_results.mat'), 'cfg', 'res1', 'res2', 'res3', 'res4', 'sens');
fprintf('主程序运行完成，结果已保存至 %s\n', fullfile(out_dir, 'final_results.mat'));
