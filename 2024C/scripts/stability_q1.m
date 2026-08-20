% stability_q1.m —— Q1 求解稳定性检验（针对 exit_flag=2 遗留问题）
% 方法：不同求解器配置重复求解两情形，比较目标值与种植结构。
% 判据（/test 规范）：确定性算法目标值相对标准差 < 1% 视为稳定；
%       若超过，建议延长 MaxTime 重新求解。
% 配置1 复用 outputs/q1_solution.mat 的 900s 基准解；配置2/3 现场重算（各 600s）。
% 结果写入 outputs/stability_q1.txt

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

opts_base = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 900);
opts_gap  = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 600, ...
                         'RelativeGapTolerance', 1e-3);
opts_node = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 900, ...
                         'MaxNodes', 200000);
configs = {'默认900s(基准)', opts_base; '600s+宽松间隙', opts_gap; '900s+节点上限', opts_node};
S = load(fullfile(OUT_DIR, 'q1_solution.mat'));

fid = fopen(fullfile(OUT_DIR, 'stability_q1.txt'), 'w', 'n', 'UTF-8');
for cm = {'滞销', '半价'}
    fprintf(fid, '\n===== 情形: %s =====\n', cm{1});
    profits = zeros(size(configs, 1), 1);
    us = cell(size(configs, 1), 1);
    for k = 1:size(configs, 1)
        if k == 1
            sol = S.(['sol_case', num2str(find(strcmp({'滞销','半价'}, cm{1})))]);
        else
            sol = func_q1_milp(param, planted_2023, cm{1}, '', configs{k, 2});
        end
        profits(k) = sol.profit_total;
        us{k} = sol.u;
        fprintf(fid, '[%s] 总利润=%.2f exit_flag=%d\n', configs{k, 1}, sol.profit_total, sol.exit_flag);
    end
    fprintf(fid, '利润均值=%.2f 相对标准差=%.3f%% 相对极差=%.3f%%\n', ...
        mean(profits), 100 * std(profits) / mean(profits), ...
        100 * (max(profits) - min(profits)) / mean(profits));
    for a = 1:numel(us)
        for b = a + 1:numel(us)
            ov = mean(us{a}(:) == us{b}(:));
            fprintf(fid, '种植结构一致率(%s vs %s): %.1f%%\n', configs{a, 1}, configs{b, 1}, 100 * ov);
        end
    end
end
fclose(fid);
fprintf('稳定性检验完成，结果见 outputs/stability_q1.txt\n');
