% rerun_q1_long.m —— 延长时限重解 Q1（稳定性检验结论：滞销不稳定，半价稳定）
% 滞销: 两次 1800s（默认间隙 / 1e-3 间隙），取利润较优者
% 半价: 一次 1800s 确认
% 结果更新 outputs/q1_solution.mat 与 result1_1/result1_2.xlsx，
% 对比过程写入 outputs/q1_rerun_long.txt

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

opts_def = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 1800);
opts_gap = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 1800, ...
                        'RelativeGapTolerance', 1e-3);

fid = fopen(fullfile(OUT_DIR, 'q1_rerun_long.txt'), 'w', 'n', 'UTF-8');
fprintf(fid, '开始时间 %s\n', datestr(now));

% ---- 滞销：两次长时限，取较优 ----
sol_c1_a = func_q1_milp(param, planted_2023, '滞销', '', opts_def);
fprintf(fid, '[滞销-1800s默认] 利润=%.2f exit_flag=%d\n', sol_c1_a.profit_total, sol_c1_a.exit_flag);
sol_c1_b = func_q1_milp(param, planted_2023, '滞销', '', opts_gap);
fprintf(fid, '[滞销-1800s+间隙1e-3] 利润=%.2f exit_flag=%d\n', sol_c1_b.profit_total, sol_c1_b.exit_flag);
if sol_c1_b.profit_total > sol_c1_a.profit_total
    sol_case1 = sol_c1_b;
else
    sol_case1 = sol_c1_a;
end
fprintf(fid, '[滞销] 采用较优解: 利润=%.2f\n', sol_case1.profit_total);

% ---- 半价：一次长时限确认 ----
sol_case2 = func_q1_milp(param, planted_2023, '半价', '', opts_def);
fprintf(fid, '[半价-1800s默认] 利润=%.2f exit_flag=%d\n', sol_case2.profit_total, sol_case2.exit_flag);

% ---- 更新产物 ----
save(fullfile(OUT_DIR, 'q1_solution.mat'), 'sol_case1', 'sol_case2');
func_write_result(OUT_DIR, 'result1_1.xlsx', sol_case1);
func_write_result(OUT_DIR, 'result1_2.xlsx', sol_case2);
fprintf(fid, 'q1_solution.mat / result1_1 / result1_2 已更新\n');
fprintf(fid, '结束时间 %s\n', datestr(now));
fclose(fid);
fprintf('Q1 长时限重解完成\n');
