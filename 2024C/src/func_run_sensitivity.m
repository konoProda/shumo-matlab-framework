function func_run_sensitivity(param, scen, u_q1, fig_dir)
% func_run_sensitivity —— 灵敏度分析（映射表 S1~S4，全部基于 LP，快速路径）
% S1 lambda 权衡曲线 {0, 0.1, 0.5}：期望收益 vs CVaR（Pareto 前沿）
% S2 灾害概率 {5%,10%,15%,20%}：观察露天->大棚种植结构转移
% S3 delta {0.05,0.10,0.15}：耕地利用率与总利润（Q1 拓扑固定 LP）
% S4 phi {0.85,0.90,0.95}：互补折减系数稳健性
% 产出: 图（300dpi PNG+EPS）+ outputs/sensitivity.csv
% 注意: S2 需重新生成情景；全部数值现场计算

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
pal = struct('blue', [0.35 0.55 0.75], 'green', [0.45 0.65 0.45], 'orange', [0.85 0.65 0.35], 'gray', [0.65 0.65 0.65]);


OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
N = numel(param.yield_i);
oi = param.omega_list(:, 1);

% ---- S1 lambda 权衡 ----
lam_list = [0 0.1 0.5];
s1_profit = zeros(numel(lam_list), 1);
s1_cvar = zeros(numel(lam_list), 1);
for k = 1:numel(lam_list)
    s = func_q2_saa(param, scen, u_q1, 0.95, lam_list(k), 'lp_fixed');
    s1_profit(k) = s.profit_mean_total;
    s1_cvar(k) = sum(s.cvar_by_year);
end
f1 = figure('Visible', 'off');
plot(s1_cvar / 1e4, s1_profit / 1e4, 's', 'MarkerSize', 10, 'MarkerFaceColor', pal.blue, 'MarkerEdgeColor', pal.blue);
for k = 1:numel(lam_list)
    text(s1_cvar(k) / 1e4, s1_profit(k) / 1e4 + max(s1_profit / 1e4) * 0.01, sprintf('\\lambda=%.1f', lam_list(k)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
end
xlabel('CVaR 尾部损失（万元）');  ylabel('期望总利润（万元）');
title('风险厌恶系数 \lambda 权衡曲线');
grid on;
print(f1, fullfile(fig_dir, 'sens_lambda.png'), '-dpng', '-r300');
print(f1, fullfile(fig_dir, 'sens_lambda.eps'), '-depsc');
close(f1);

% ---- S2 灾害概率 ----
p_list = [0.05 0.10 0.15 0.20];
s2_profit = zeros(numel(p_list), 1);
s2_open_share = zeros(numel(p_list), 1);     % 露天面积占比
for k = 1:numel(p_list)
    p2 = param;  p2.p_disaster = p_list(k);
    sc2 = func_gen_scenarios(p2, scen.K, 2024);
    s = func_q2_saa(p2, sc2, u_q1, 0.95, 0.1, 'lp_fixed');
    s2_profit(k) = s.profit_mean_total;
    s2_open_share(k) = sum(s.x(oi <= 34, :), 'all') / sum(s.x, 'all') * 100;
end
f2 = figure('Visible', 'off');
yyaxis left;
plot(p_list * 100, s2_profit / 1e4, 's', 'MarkerSize', 10, 'MarkerFaceColor', pal.blue, 'MarkerEdgeColor', pal.blue);
ylabel('期望总利润（万元）');
yyaxis right;
plot(p_list * 100, s2_open_share, 'o', 'MarkerSize', 8, 'MarkerFaceColor', pal.orange, 'MarkerEdgeColor', pal.orange);
ylabel('露天耕地面积占比（%）');
xlabel('灾害年触发概率（%）');
title('灾害概率敏感性：露天向大棚转移倾向');
grid on;
print(f2, fullfile(fig_dir, 'sens_disaster.png'), '-dpng', '-r300');
print(f2, fullfile(fig_dir, 'sens_disaster.eps'), '-depsc');
close(f2);

% ---- S3 delta 扰动（Q1 拓扑固定 LP，修改 delta 后重新装配） ----
S1 = load(fullfile(OUT_DIR, 'q1_solution.mat'));
delta_list = [0.05 0.10 0.15];
s3_profit = zeros(numel(delta_list), 1);
s3_util = zeros(numel(delta_list), 1);
u_fix = round(S1.sol_case2.u(:));
for k = 1:numel(delta_list)
    p3 = param;  p3.delta_min = delta_list(k);
    dbg = func_q1_milp(p3, param.planted_2023, '半价', 'debug');
    N7 = dbg.n_blocks;
    col_x = 1:N7;  col_u = N7 + 1:2 * N7;  col_q = 2 * N7 + 1:4 * N7;
    A_red = dbg.A(:, [col_x col_q]);
    b_red = dbg.b - dbg.A(:, col_u) * u_fix;
    f_red = dbg.f([col_x col_q]);
    lb_red = dbg.lb([col_x col_q]);  ub_red = dbg.ub([col_x col_q]);
    opts_lp = optimoptions('linprog', 'Display', 'off');
    [v_lp, ~, ~] = linprog(f_red, A_red, b_red, [], [], lb_red, ub_red, opts_lp);
    x_lp = reshape(v_lp(1:N7), N, 7);
    v_full = zeros(4 * N7, 1);
    v_full([col_x col_q]) = v_lp;
    v_full(col_u) = u_fix;
    s3_profit(k) = -dbg.f' * v_full;                  % W = -f'v（恢复原变量顺序）
    s3_util(k) = sum(x_lp, 'all') / sum(param.plot_area) * 100;
end
f3 = figure('Visible', 'off');
yyaxis left;
plot(delta_list, s3_profit / 1e4, 's', 'MarkerSize', 10, 'MarkerFaceColor', pal.blue, 'MarkerEdgeColor', pal.blue);
ylabel('总利润（万元）');
yyaxis right;
plot(delta_list, s3_util, 'o', 'MarkerSize', 8, 'MarkerFaceColor', pal.orange, 'MarkerEdgeColor', pal.orange);
ylabel('耕地利用率（%）');
xlabel('最小种植比例 \delta');
title('最小种植比例 \delta 扰动检验');
grid on;
print(f3, fullfile(fig_dir, 'sens_delta.png'), '-dpng', '-r300');
print(f3, fullfile(fig_dir, 'sens_delta.eps'), '-depsc');
close(f3);

% ---- S4 phi 敏感性（Q3 LP） ----
S3 = load(fullfile(OUT_DIR, 'q3_solution.mat'));
phi_list = [0.85 0.90 0.95];
s4_profit = zeros(numel(phi_list), 1);
for k = 1:numel(phi_list)
    ext.rho_sp = S3.rho_sp;  ext.clusters = S3.clusters;  ext.phi = phi_list(k);
    s = func_q2_saa(param, S3.sol_q3.scen, u_q1, 0.95, 0.1, 'lp_fixed', ext);
    s4_profit(k) = s.profit_mean_total;
end
f4 = figure('Visible', 'off');
plot(phi_list, s4_profit / 1e4, 's', 'MarkerSize', 10, 'MarkerFaceColor', pal.blue, 'MarkerEdgeColor', pal.blue);
for k = 1:numel(phi_list)
    text(phi_list(k), s4_profit(k) / 1e4 + max(s4_profit / 1e4) * 0.01, sprintf('%.1f', s4_profit(k) / 1e4), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
end
xlabel('互补折减系数 \phi');  ylabel('Q3 期望总利润（万元）');
title('\phi 折减系数敏感性');
grid on;
print(f4, fullfile(fig_dir, 'sens_phi.png'), '-dpng', '-r300');
print(f4, fullfile(fig_dir, 'sens_phi.eps'), '-depsc');
close(f4);

% ---- 汇总 CSV ----
tbl = table([lam_list nan p_list nan delta_list nan phi_list]', ...
    [s1_profit/1e4; nan; s2_profit/1e4; nan; s3_profit/1e4; nan; s4_profit/1e4], ...
    'VariableNames', {'参数取值', '指标_万元'});
writetable(tbl, fullfile(OUT_DIR, 'sensitivity.csv'));
end
