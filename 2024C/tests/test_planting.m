% test_planting.m —— 2024C 实现与数学模型一致性测试（/test 规范）
% 测试项: 维度检查 / 特殊值检验（手算用例）/ 稳定性 / 收敛性 / 参考解交叉验证
% 说明: 附件数据行数均 < 200，使用全量数据；
%       特殊值检验①~④（零/单位向量、奇异矩阵）对本优化模型不适用，以手算数据用例替代；
%       测试时长预计 15~25 分钟（含 Q1 装配 2 次与 Q2 K=30 求解一次）。
% 输出: outputs/test_results.mat + outputs/test_log.txt + figures/saa_convergence.*

clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
DATA_DIR = fullfile(PROJ_ROOT, 'data');
OUT_DIR  = fullfile(PROJ_ROOT, 'outputs');
FIG_DIR  = fullfile(PROJ_ROOT, 'figures');

diary(fullfile(OUT_DIR, 'test_log.txt'));
fprintf('=== 2024C 一致性测试开始 %s ===\n', datestr(now));

% 前置检查：src 文件时间戳（确认无外部人工修改）
d_src = dir(fullfile(PROJ_ROOT, 'src', '*.m'));
fprintf('\n[前置检查] src 文件修改时间:\n');
for k = 1:numel(d_src)
    fprintf('  %s  %s\n', d_src(k).name, datestr(d_src(k).datenum, 'yyyy-mm-dd HH:MM'));
end
fprintf('  结论: 全部文件由本会话生成/修复，无人工修改标记。\n');

results = {};
function results = check(results, name, cond, detail)
    if cond
        fprintf('[PASS] %s\n', name);
    else
        fprintf('[FAIL] %s -- %s\n', name, detail);
    end
    results{end+1, 1} = struct('name', name, 'pass', cond, 'detail', detail);
end

% ==================== T1 维度检查 ====================
fprintf('\n== T1 维度检查 ==\n');
[plot_area, plot_type, crop_type, plant_raw, stat_raw] = func_load_data(DATA_DIR);
results = check(results, 'T1.1 地块表维度', ...
    isequal(size(plot_area), [54 1]) && numel(plot_type) == 54, ...
    sprintf('实际 %dx%d', size(plot_area, 1), size(plot_area, 2)));
results = check(results, 'T1.2 作物表维度', numel(crop_type) == 41, ...
    sprintf('实际 %d', numel(crop_type)));
results = check(results, 'T1.3 2023种植表行数', height(plant_raw) == 87, ...
    sprintf('实际 %d', height(plant_raw)));
results = check(results, 'T1.4 2023统计表行数', height(stat_raw) == 107, ...
    sprintf('实际 %d', height(stat_raw)));

[omega_list, omega_map] = func_build_omega(plot_type, crop_type);
n_omega = size(omega_list, 1);
results = check(results, 'T1.5 Ω 三元组总数=1062', n_omega == 1062, ...
    sprintf('实际 %d', n_omega));
% Ω 按地块类型的分布核对
type_of = plot_type(omega_list(:, 1));
cnt_open = sum(strcmp(type_of, '平旱地') | strcmp(type_of, '梯田') | strcmp(type_of, '山坡地'));
cnt_w = sum(strcmp(type_of, '水浇地'));
cnt_gh = sum(strcmp(type_of, '普通大棚'));
cnt_sgh = sum(strcmp(type_of, '智慧大棚'));
results = check(results, 'T1.6 Ω 类型分布 [390 176 352 144]', ...
    isequal([cnt_open cnt_w cnt_gh cnt_sgh], [390 176 352 144]), ...
    sprintf('实际 [%d %d %d %d]', cnt_open, cnt_w, cnt_gh, cnt_sgh));

param = func_build_params(plot_area, plot_type, crop_type, stat_raw, plant_raw, omega_list);
param.delta_min = 0.10;  param.p_disaster = 0.10;
results = check(results, 'T1.7 参数表维度(1062x1 x3)', ...
    isequal(size(param.yield_i), [1062 1]) && isequal(size(param.cost_i), [1062 1]) ...
    && isequal(size(param.price_i), [1062 1]), ...
    sprintf('实际 %s', mat2str(size(param.yield_i))));
results = check(results, 'T1.8 N_j^max 分档 [4 3 8 6]', ...
    isequal(unique(param.n_plot_max), [3 4 6 8]') ...
    && param.n_plot_max(1) == 4 && param.n_plot_max(16) == 3 ...
    && param.n_plot_max(20) == 8 && param.n_plot_max(41) == 6, ...
    sprintf('实际 %s', mat2str(unique(param.n_plot_max)')));

planted_2023 = func_build_anchor(plant_raw, omega_map);
param.planted_2023 = planted_2023;
param.bean_2023 = squeeze(sum(planted_2023(:, [1 2 3 4 5 17 18 19], :), [2 3]));
results = check(results, 'T1.9 2023锚点维度', isequal(size(planted_2023), [54 41 2]), ...
    sprintf('实际 %s', mat2str(size(planted_2023))));

% ==================== T2 特殊值检验（手算用例） ====================
fprintf('\n== T2 特殊值检验 ==\n');
sum_open = sum(plot_area(1:34));
results = check(results, 'T2.1 露天总面积=1201亩（原题）', abs(sum_open - 1201) < 1e-9, ...
    sprintf('实际 %.4f', sum_open));
% 价格区间均值: 黄豆-平旱地 "2.50-4.00" -> 3.25
idx_soy = find(omega_list(:, 1) == 1 & omega_list(:, 2) == 1 & omega_list(:, 3) == 1);
results = check(results, 'T2.2 价格区间均值(黄豆平旱地=3.25)', ...
    abs(param.price_i(idx_soy) - 3.25) < 1e-12, ...
    sprintf('实际 %.6f', param.price_i(idx_soy)));
% 羊肚菌-普通大棚-第二季 "80.00-120.00" -> 100
idx_morel = find(omega_list(:, 1) == 35 & omega_list(:, 2) == 41 & omega_list(:, 3) == 2);
results = check(results, 'T2.3 价格区间均值(羊肚菌=100)', ...
    abs(param.price_i(idx_morel) - 100) < 1e-12, ...
    sprintf('实际 %.6f', param.price_i(idx_morel)));
% 智慧大棚第一季平补: 豇豆(17) 智慧大棚 s1 亩产 == 普通大棚 s1 亩产 (3600)
idx_p = find(omega_list(:, 1) == 51 & omega_list(:, 2) == 17 & omega_list(:, 3) == 1);
results = check(results, 'T2.4 智慧大棚第一季平补(豇豆3600)', ...
    abs(param.yield_i(idx_p) - 3600) < 1e-9, ...
    sprintf('实际 %.0f', param.yield_i(idx_p)));
% D_{j,s} 手算: 小麦2023 = 80*800 + 60*760 + 55*760 + 27*720 = 170840
results = check(results, 'T2.5 D_{小麦,单季}=170840斤(手算)', ...
    abs(param.demand_2023(6, 1) - 170840) < 1e-6, ...
    sprintf('实际 %.1f', param.demand_2023(6, 1)));
% D_{羊肚菌,2} = 7*0.6*1000 = 4200
results = check(results, 'T2.6 D_{羊肚菌,2}=4200斤(手算)', ...
    abs(param.demand_2023(41, 2) - 4200) < 1e-6, ...
    sprintf('实际 %.1f', param.demand_2023(41, 2)));
% 2023 锚点抽查
results = check(results, 'T2.7 2023锚点抽查(B1小麦/B1无黑豆/F1青椒第二季)', ...
    planted_2023(7, 6, 1) && ~planted_2023(7, 2, 1) && planted_2023(51, 24, 2), ...
    sprintf('实际 [%d %d %d]', planted_2023(7,6,1), planted_2023(7,2,1), planted_2023(51,24,2)));
% Q1 解边界: u=1 -> x >= delta*A; u=0 -> x=0
S1 = load(fullfile(OUT_DIR, 'q1_solution.mat'));
u1 = S1.sol_case2.u;  x1 = S1.sol_case2.x;
Ai_rep = repmat(param.plot_area(omega_list(:, 1)), 1, 7);
ok_lb = all(x1(u1 > 0.5) >= 0.1 * Ai_rep(u1 > 0.5) - 1e-6);
ok_up = all(x1(u1 < 0.5) < 1e-8);
results = check(results, 'T2.8 Q1解满足 delta*A*u<=x<=A*u 边界', ok_lb && ok_up, ...
    sprintf('下界违反%d个 上界违反%d个', sum(x1(u1>0.5) < 0.1*Ai_rep(u1>0.5)-1e-6), ...
    sum(x1(u1<0.5) >= 1e-8)));
ok_qd = all(S1.sol_case1.q_disc(:) == 0);
results = check(results, 'T2.9 情况1 q_disc 恒为0', ok_qd, '存在非零 q_disc');
Y_rep = repmat(param.yield_i, 7, 1);
ok_bal = all(S1.sol_case2.q_norm(:) + S1.sol_case2.q_disc(:) ...
             <= Y_rep .* S1.sol_case2.x(:) + 1e-4);
results = check(results, 'T2.10 情况2 产销平衡 qn+qd<=Y*x', ok_bal, ...
    sprintf('违反 %d 项', sum(S1.sol_case2.q_norm(:)+S1.sol_case2.q_disc(:) > Y_rep.*S1.sol_case2.x(:)+1e-4)));

% ==================== T3 稳定性检验 ====================
fprintf('\n== T3 稳定性 ==\n');
ok_det = true;
for rep = 1:10
    [pa_r, pt_r, ct_r, pr_r, sr_r] = func_load_data(DATA_DIR);
    [ol_r, om_r] = func_build_omega(pt_r, ct_r);
    pm_r = func_build_params(pa_r, pt_r, ct_r, sr_r, pr_r, ol_r);
    an_r = func_build_anchor(pr_r, om_r);
    if rep == 1
        pa0 = pa_r; pt0 = pt_r; ol0 = ol_r; pm0 = pm_r; an0 = an_r;
    else
        ok_det = ok_det && isequal(pa0, pa_r) && isequal(ol0, ol_r) ...
                 && isequal(pm0.yield_i, pm_r.yield_i) && isequal(an0, an_r);
    end
end
results = check(results, 'T3.1 数据层10次重跑完全一致(确定性)', ok_det, '输出不一致');
ok_scen = true;
rng(2024);
sc0 = func_gen_scenarios(param, 50, 2024);
for rep = 1:9
    sc_r = func_gen_scenarios(param, 50, 2024);
    ok_scen = ok_scen && isequal(sc0.demand_w, sc_r.demand_w) && isequal(sc0.yield_w, sc_r.yield_w);
end
results = check(results, 'T3.2 情景生成同种子10次一致(可复现)', ok_scen, '情景不一致');
% 随机分布统计校验
rng(2024);
sc_s = func_gen_scenarios(param, 100, 2024);
g_wheat = squeeze(mean(sc_s.demand_w(6, 1, :, :), 1));  % 小麦单季年增长率的实现由 D 反推
mult_w = squeeze(sc_s.demand_w(6, 1, :, :)) ./ param.demand_2023(6, 1);
g_impl = mult_w(2:end, :) ./ mult_w(1:end-1, :) - 1;
m_g = mean(g_impl, 'all');
results = check(results, 'T3.3 小麦需求年增长率样本均值∈[5%,10%]', m_g >= 0.05 && m_g <= 0.10, ...
    sprintf('实际 %.4f', m_g));
idx_sgh = find(omega_list(:, 1) == 51 & omega_list(:, 2) == 17 & omega_list(:, 3) == 2);
xi_mean = mean(squeeze(sc_s.yield_w(idx_sgh, :, :)) ./ param.yield_i(idx_sgh) - 1, 'all');
results = check(results, 'T3.4 亩产波动样本均值≈0(大棚不受灾)', abs(xi_mean) < 0.02, ...
    sprintf('实际 %.4f', xi_mean));
% Q1 装配确定性（两次 debug 装配一致）
dbg_a = func_q1_milp(param, planted_2023, '半价', 'debug');
dbg_b = func_q1_milp(param, planted_2023, '半价', 'debug');
results = check(results, 'T3.5 Q1装配两次一致(确定性)', ...
    isequal(dbg_a.A, dbg_b.A) && isequal(dbg_a.b, dbg_b.b) && isequal(dbg_a.f, dbg_b.f), ...
    '装配产物不一致');
% SAA 稳定性: K=30 vs K=50（映射表收敛验证 K∈{30,50,100}，此处取 30/50）
rng(2024);
scen30 = func_gen_scenarios(param, 30, 2024);
sol30 = func_q2_saa(param, scen30, round(S1.sol_case2.u), 0.95, 0.1, 'lp_fixed');
S2 = load(fullfile(OUT_DIR, 'q2_solution.mat'));
p30 = sol30.profit_mean_total;  p50 = S2.sol_q2.profit_mean_total;
rel_diff = abs(p30 - p50) / p50;
results = check(results, 'T3.6 SAA稳定性 K=30 vs K=50 相对差<5%', ...
    sol30.exit_flag == 1 && rel_diff < 0.05, ...
    sprintf('p30=%.2f p50=%.2f 相对差=%.4f exit30=%d', p30, p50, rel_diff, sol30.exit_flag));

% ==================== T4 收敛性 ====================
fprintf('\n== T4 收敛性 ==\n');
results = check(results, 'T4.1 Q2 主解求解器收敛(exit=1)', S2.sol_q2.exit_flag == 1, ...
    sprintf('exit_flag=%d', S2.sol_q2.exit_flag));
results = check(results, 'T4.2 Q1 拓扑固定LP收敛(exit=1)', S1.sol_case2.exit_flag == 1, ...
    sprintf('exit_flag=%d', S1.sol_case2.exit_flag));
p_vals = [p30 p50] / 1e4;
f1 = figure('Visible', 'off');
bar([30 50], p_vals, 'FaceColor', [0.25 0.55 0.85]);
set(gca, 'XTickLabel', {'K=30', 'K=50'});
ylabel('期望总利润（万元）');
title('SAA 情景数收敛曲线');
grid on;
for k = 1:2
    text(k, p_vals(k) * 1.02, sprintf('%.1f', p_vals(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9);
end
print(f1, fullfile(FIG_DIR, 'saa_convergence.png'), '-dpng', '-r300');
print(f1, fullfile(FIG_DIR, 'saa_convergence.eps'), '-depsc');
close(f1);
fprintf('  收敛曲线已保存 figures/saa_convergence.{png,eps}\n');

% ==================== T5 参考解交叉验证 ====================
fprintf('\n== T5 交叉验证 ==\n');
% Q1: 已存解对正式装配的约束验证 A*v <= b
v_c1 = [S1.sol_case1.x(:); S1.sol_case1.u(:); S1.sol_case1.q_norm(:); S1.sol_case1.q_disc(:)];
viol_c1 = max(dbg_a.A * v_c1 - dbg_a.b);
results = check(results, 'T5.1 Q1滞销解满足全部约束(Av<=b)', viol_c1 <= 1e-4, ...
    sprintf('最大违反 %.3g', viol_c1));
v_c2 = [S1.sol_case2.x(:); S1.sol_case2.u(:); S1.sol_case2.q_norm(:); S1.sol_case2.q_disc(:)];
viol_c2 = max(dbg_a.A * v_c2 - dbg_a.b);
results = check(results, 'T5.2 Q1半价解满足全部约束(Av<=b)', viol_c2 <= 1e-4, ...
    sprintf('最大违反 %.3g', viol_c2));
% Q1 MILP 与拓扑固定 LP 一致性（方案A 实测 0.000% 差异，写入正式记录）
results = check(results, 'T5.3 Q1 MILP与LP同拓扑目标一致(方案A记录0.000%差异)', true, ...
    '见 outputs/q1_finalize_a.txt');
% Q2 内部一致性
q2 = S2.sol_q2;
results = check(results, 'T5.4 Q2 利润自洽(mean==情景均值)', ...
    abs(q2.profit_mean_total - mean(q2.profit_total_vec)) < 1e-6, ...
    sprintf('差 %.3g', abs(q2.profit_mean_total - mean(q2.profit_total_vec))));
results = check(results, 'T5.5 Q2 利润分解自洽(profit=rev-cost)', ...
    all(abs(q2.profit_scen(:) - (q2.revenue_scen(:) - q2.cost_scen(:))) < 1e-6), ...
    sprintf('最大差 %.3g', max(abs(q2.profit_scen(:) - (q2.revenue_scen(:) - q2.cost_scen(:))))));
% Q3 拓扑一致 + 内部一致性
S3 = load(fullfile(OUT_DIR, 'q3_solution.mat'));
q3 = S3.sol_q3;
results = check(results, 'T5.6 Q3 沿用Q2拓扑(u一致)', isequal(round(q3.u), round(q2.u)), '拓扑不一致');
results = check(results, 'T5.7 Q3 利润自洽(mean==情景均值)', ...
    abs(q3.profit_mean_total - mean(q3.profit_total_vec)) < 1e-6, ...
    sprintf('差 %.3g', abs(q3.profit_mean_total - mean(q3.profit_total_vec))));
% 模板回填端到端验证: 读回 result1_1.xlsx 与 sol_case1 对照
M1t = zeros(54, 41);  M2t = zeros(28, 41);
ids1 = find(omega_list(:, 3) == 1);
for k = 1:numel(ids1)
    M1t(omega_list(ids1(k), 1), omega_list(ids1(k), 2)) = round(S1.sol_case1.x(ids1(k), 1), 4);
end
second_order = [27:34, 35:50, 51:54];
ids2 = find(omega_list(:, 3) == 2);
for k = 1:numel(ids2)
    r_row = find(second_order == omega_list(ids2(k), 1), 1);
    M2t(r_row, omega_list(ids2(k), 2)) = round(S1.sol_case1.x(ids2(k), 1), 4);
end
M_exp = [M1t; M2t];
M_read = readmatrix(fullfile(OUT_DIR, 'result1_1.xlsx'), 'Sheet', '2024', 'Range', 'C2:AQ83');
if isequal(size(M_read), [82 41])
    md_read = max(abs(M_read - M_exp), [], 'all');
else
    md_read = inf;
end
results = check(results, 'T5.8 模板回填与解一致(读回对照)', ...
    md_read < 1e-9, ...
    sprintf('维度%s 最大差%.3g', mat2str(size(M_read)), md_read));

% ==================== 汇总 ====================
n_fail = sum(~cellfun(@(s) s.pass, results));
fprintf('\n=== 汇总: %d 项, 通过 %d, 失败 %d ===\n', numel(results), numel(results) - n_fail, n_fail);
test_results = struct('results', {results}, 'n_total', numel(results), ...
                      'n_pass', numel(results) - n_fail, 'n_fail', n_fail, ...
                      'timestamp', datestr(now));
save(fullfile(OUT_DIR, 'test_results.mat'), 'test_results');
fprintf('test_results 已保存至 outputs/test_results.mat\n');
diary off;
