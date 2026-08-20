% main_planting.m —— 2024C 农作物的种植策略 主程序
% 功能：编排三问求解——问题1 确定性MILP（两种情况）、问题2 SAA-CVaR两阶段随机规划、
%       问题3 统计+替代/互补拓展，并将结果回填附件3模板。
% 用法：修改 QUESTION 后直接运行；Q2 需先运行 Q1（读取 outputs/q1_solution.mat），
%       Q3 需先运行 Q1、Q2（读取 outputs/q2_solution.mat）。

clear; close all; clc;

%% ==================== 0. 路径定义 ====================
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');  % 题目根目录 2024C/
DATA_DIR  = fullfile(PROJ_ROOT, 'data');
OUT_DIR   = fullfile(PROJ_ROOT, 'outputs');
FIG_DIR   = fullfile(PROJ_ROOT, 'figures');

%% ==================== 1. 运行控制 ====================
QUESTION = 1;    % 运行哪一问：1 / 2 / 3 / 4（4=灵敏度分析 S1~S4，需先运行 Q2）
RNG_SEED = 2024; % 随机数种子（P2 抽样可复现）

%% ==================== 2. 模型参数集中定义 ====================
K_SCEN      = 50;          % S0-8 情景数 K（基准 50，稳定性检验取 {30,50,100}）
DELTA_MIN   = 0.10;        % P1-6 最小种植比例 δ
ALPHA_CVAR  = 0.95;        % Q2 CVaR 置信度 α
LAMBDA_RISK = 0.1;         % Q2 风险厌恶系数 λ（敏感性 {0, 0.1, 0.5}）
PHI_COMP    = 0.90;        % C3-3 互补折减系数 φ（Δc = 1-φ = 0.10）
THETA_RULE  = 'abs_rho';   % C3-2 需求转移系数规则 θ = |ρ|（B7 默认值）
P_DISASTER  = 0.10;        % P2-4 露天耕地灾害年触发概率（敏感性 5%~20%）
% P1-7 分散度上限 N_j^max 在 func_build_params 内按作物类别赋值：
%   粮食类 j=1..15 → 4；水稻 j=16 → 3；蔬菜瓜果 j=17..37 → 8；食用菌 j=38..41 → 6

%% ==================== 3. 数据加载与预处理（D1~D4） ====================
[plot_area, plot_type, crop_type, plant_raw, stat_raw] = func_load_data(DATA_DIR);
[omega_list, omega_map] = func_build_omega(plot_type, crop_type); % S0-7 适宜种植集合 Ω
param = func_build_params(plot_area, plot_type, crop_type, stat_raw, plant_raw, omega_list);
param.delta_min  = DELTA_MIN;          % P1-6 注入主程序参数
param.p_disaster = P_DISASTER;         % P2-4 注入主程序参数
planted_2023 = func_build_anchor(plant_raw, omega_map);           % P1-8 2023 种植锚点
param.planted_2023 = planted_2023;     % 连作/前茬锚点（Q2/Q3 复用）
param.bean_2023 = squeeze(sum(planted_2023(:, [1 2 3 4 5 17 18 19], :), [2 3])); % 各2023年豆类种植指示

%% ==================== 4. 分问题求解 ====================
switch QUESTION
    case 1
        % ---- 问题1：确定性 MILP（C1-1~C1-8），两种超产处理 ----
        sol_case1 = func_q1_milp(param, planted_2023, '滞销');   % 情况(1)：γ=0，q_disc≡0
        sol_case2 = func_q1_milp(param, planted_2023, '半价');   % 情况(2)：γ=0.5
        func_write_result(OUT_DIR, 'result1_1.xlsx', sol_case1); % D5 回填模板
        func_write_result(OUT_DIR, 'result1_2.xlsx', sol_case2);
        save(fullfile(OUT_DIR, 'q1_solution.mat'), 'sol_case1', 'sol_case2');

    case 2
        % ---- 问题2：SAA-CVaR 两阶段随机规划（P2-1~P2-4） ----
        scen = func_gen_scenarios(param, K_SCEN, RNG_SEED);      % 随机参数情景生成
        S1 = load(fullfile(OUT_DIR, 'q1_solution.mat'));         % 依赖 Q1 的 u*
        sol_q2 = func_q2_saa(param, scen, S1.sol_case2.u, ...
                             ALPHA_CVAR, LAMBDA_RISK, 'lp_fixed'); % 主路径：拓扑固定法
        func_write_result(OUT_DIR, 'result2.xlsx', sol_q2);
        save(fullfile(OUT_DIR, 'q2_solution.mat'), 'sol_q2', 'scen');

    case 3
        % ---- 问题3：统计 + 替代/互补拓展（S3-1~S3-3, C3-1~C3-4） ----
        S2 = load(fullfile(OUT_DIR, 'q2_solution.mat'));
        S1 = load(fullfile(OUT_DIR, 'q1_solution.mat'));
        [rho_sp, clusters] = func_q3_stats(param, S2.sol_q2);    % jbtest/Spearman/K-means
        sol_q3 = func_q3_extend(param, S2.scen, S2.sol_q2.u, ...
                                rho_sp, clusters, PHI_COMP, THETA_RULE);
        save(fullfile(OUT_DIR, 'q3_solution.mat'), 'sol_q3', 'rho_sp', 'clusters');
        func_compare_q(S1.sol_case1, S1.sol_case2, S2.sol_q2, sol_q3, FIG_DIR); % 三问对比

    case 4
        % ---- 灵敏度分析（S1~S4） ----
        S2 = load(fullfile(OUT_DIR, 'q2_solution.mat'));
        func_run_sensitivity(param, S2.scen, S2.sol_q2.u, FIG_DIR);

    otherwise
        error('QUESTION 取值须为 1、2、3 或 4');
end
