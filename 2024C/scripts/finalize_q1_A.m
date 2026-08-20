% finalize_q1_A.m —— 方案A：Q1 收尾
% 滞销: 600s MILP 重解（间隙1e-3）-> 固定 u 拓扑 -> 纯 LP 精化（linprog 有最优性证明）
% 半价: 稳定性已通过，直接对已存解做拓扑固定 LP 精化
% 产物更新: outputs/q1_solution.mat、result1_1.xlsx、result1_2.xlsx
% 过程写入 outputs/q1_finalize_a.txt

clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
DATA_DIR  = fullfile(PROJ_ROOT, 'data');
OUT_DIR   = fullfile(PROJ_ROOT, 'outputs');
addpath(fullfile(PROJ_ROOT, 'src'));

[plot_area, plot_type, crop_type, plant_raw, stat_raw] = func_load_data(DATA_DIR);
[omega_list, omega_map] = func_build_omega(plot_type, crop_type);
param = func_build_params(plot_area, plot_type, crop_type, stat_raw, plant_raw, omega_list);
param.delta_min = 0.10;   param.p_disaster = 0.10;
planted_2023 = func_build_anchor(plant_raw, omega_map);

fid = fopen(fullfile(OUT_DIR, 'q1_finalize_a.txt'), 'w', 'n', 'UTF-8');
fprintf(fid, '开始 %s\n', datestr(now));

% ---- 滞销：600s MILP 重解 ----
opts_mip = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 600, ...
                        'RelativeGapTolerance', 1e-3);
sol_mip1 = func_q1_milp(param, planted_2023, '滞销', '', opts_mip);
fprintf(fid, '[滞销-MILP600s] 利润=%.2f exit_flag=%d\n', sol_mip1.profit_total, sol_mip1.exit_flag);
sol_case1 = refine_lp(param, planted_2023, '滞销', sol_mip1, fid, '滞销');

% ---- 半价：对已存稳定解做拓扑固定 LP 精化 ----
S = load(fullfile(OUT_DIR, 'q1_solution.mat'));
sol_case2 = refine_lp(param, planted_2023, '半价', S.sol_case2, fid, '半价');

% ---- 更新产物 ----
save(fullfile(OUT_DIR, 'q1_solution.mat'), 'sol_case1', 'sol_case2');
func_write_result(OUT_DIR, 'result1_1.xlsx', sol_case1);
func_write_result(OUT_DIR, 'result1_2.xlsx', sol_case2);
fprintf(fid, 'q1_solution.mat / result1_1 / result1_2 已更新\n');
fprintf(fid, '结束 %s\n', datestr(now));
fclose(fid);
fprintf('方案A Q1 收尾完成\n');

function sol_lp = refine_lp(param, planted_2023, mode, sol0, fid, tag)
% 拓扑固定精化：固定 u = round(sol0.u)，纯 LP 重优化 x/q_norm/q_disc
% 约束移项: A_q·q + A_x·x <= b - A_u·u_fix；linprog 给出该拓扑下全局最优（有证明）
dbg = func_q1_milp(param, planted_2023, mode, 'debug');
N = 1062;  N7 = N * 7;
col_x = 1:N7;  col_u = N7 + 1:2 * N7;  col_q = 2 * N7 + 1:4 * N7;
u_fix = round(sol0.u(:));
A_red = dbg.A(:, [col_x col_q]);
b_red = dbg.b - dbg.A(:, col_u) * u_fix;
f_red = dbg.f([col_x col_q]);
lb_red = dbg.lb([col_x col_q]);
ub_red = dbg.ub([col_x col_q]);
opts_lp = optimoptions('linprog', 'Display', 'off');
[v_lp, ~, exit_lp] = linprog(f_red, A_red, b_red, [], [], lb_red, ub_red, opts_lp);
sol_lp = sol0;
sol_lp.x = reshape(v_lp(1:N7), N, 7);
sol_lp.q_norm = reshape(v_lp(N7 + 1:2 * N7), N, 7);
sol_lp.q_disc = reshape(v_lp(2 * N7 + 1:3 * N7), N, 7);
gamma = 0.5;
if strcmp(mode, '滞销'), gamma = 0; end
profit_by_year = zeros(7, 1);
for t = 1:7
    profit_by_year(t) = sum(param.price_i .* sol_lp.q_norm(:, t) ...
                          + gamma * param.price_i .* sol_lp.q_disc(:, t) ...
                          - param.cost_i .* sol_lp.x(:, t));
end
sol_lp.profit_total = sum(profit_by_year);
sol_lp.profit_by_year = profit_by_year;
sol_lp.exit_flag = exit_lp;
fprintf(fid, '[%s-拓扑固定LP] 原利润=%.2f -> 精化=%.2f (提升%.3f%%), linprog exit=%d\n', ...
    tag, sol0.profit_total, sol_lp.profit_total, ...
    100 * (sol_lp.profit_total / sol0.profit_total - 1), exit_lp);
end
