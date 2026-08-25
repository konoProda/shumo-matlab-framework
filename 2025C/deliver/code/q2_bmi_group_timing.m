function res2 = q2_bmi_group_timing(male, cfg, sigma_resid)
% 问题二：BMI 分组与最佳 NIPT 时点（Q2-1~Q2-8）
% 输入: male  preprocess 输出的男胎结构体
%       cfg   主程序参数结构体（K/n_min/cut_step/t_grid/lambda_risk/c_risk/mc_iters）
%       sigma_resid 问题一最终主模型残差标准差（Q1-6，供蒙特卡洛扰动）
% 输出: res2 结构体: alpha（简化回归系数）、bmi_edges/t_opt/p_at/risk_min/eta_ok/
%       cuts/total/feasible_level、t_opt_mc 及均值/标准差/范围、λ 灵敏度结果
% 落盘: outputs/tables/q2_*.csv、figures/q2_*.png|eps

rec = male.rec;
subj = male.subj;
y = rec.y_conc;
t = rec.gest_week;
bmi = rec.bmi;
t_grid = cfg.t_grid;
nt = numel(t_grid);

%% (1) 简化回归（Q2-1）: 全部 1082 条记录，含 26~29 周
ok = all(isfinite([y, t, bmi]), 2);
mdl_alpha = func_ols([ones(nnz(ok), 1), t(ok), bmi(ok), t(ok) .* bmi(ok)], y(ok));
res2.alpha = mdl_alpha.beta;

%% (2) 孕妇层排序与预测达标矩阵（Q2-2）
bmi_s = subj.bmi_mean;
[~, sord] = sort(bmi_s);
bmi_s = bmi_s(sord);
n = numel(bmi_s);
Yhat = mdl_alpha.beta(1) + mdl_alpha.beta(2) * t_grid' + ...
       mdl_alpha.beta(3) * bmi_s + mdl_alpha.beta(4) * (bmi_s * t_grid');
reach = Yhat >= cfg.thr_y;

%% (3) 时间风险（Q2-4）
cost = cost_fcn(t_grid, cfg.c_risk);

%% (4) 切点搜索与各组最佳时点（Q2-3/Q2-5/Q2-6/Q2-7）
sol = func_cutsearch(bmi_s, reach, t_grid, cost, cfg.lambda_risk, ...
    cfg.n_min, cfg.K, cfg.cut_step, NaN);
res2.bmi_edges = sol.bmi_edges;
res2.t_opt = sol.t_opt;
res2.p_at = sol.p_at;
res2.risk_min = sol.risk_min;
res2.eta_ok = sol.eta_ok;
res2.total = sol.total;
res2.cuts = sol.cuts;
res2.feasible_level = sol.feasible_level;
res2.n_g = sol.n_g;
res2.cost = cost;
res2.bmi_s = bmi_s;
res2.reach = reach;

%% (5) 蒙特卡洛误差扰动（Q2-8，N7: 固定 α 与切点，只扰动预测判据）
idx_st = [1, sol.cuts + 1];
idx_end = [sol.cuts, n];
res2.idx_st = idx_st;
res2.idx_end = idx_end;
rng(2025, 'twister');
t_opt_mc = nan(cfg.K, cfg.mc_iters);
for m = 1:cfg.mc_iters
    e = sigma_resid * randn(n, 1);
    reach_m = (Yhat + e) >= cfg.thr_y;
    for g = 1:cfg.K
        pg = mean(reach_m(idx_st(g):idx_end(g), :), 1);
        risk = cost + cfg.lambda_risk * (1 - pg);
        [~, tidx] = min(risk);
        t_opt_mc(g, m) = t_grid(tidx);
    end
end
res2.t_opt_mc = t_opt_mc;
res2.t_mc_mean = mean(t_opt_mc, 2);
res2.t_mc_std = std(t_opt_mc, 0, 2);
res2.t_mc_min = min(t_opt_mc, [], 2);
res2.t_mc_max = max(t_opt_mc, [], 2);

%% (6) λ 灵敏度（含分组边界稳定性）
lambda_list = cfg.lambda_grid;
n_lam = numel(lambda_list);
lam_t_opt = nan(cfg.K, n_lam);
lam_edges = nan(cfg.K + 1, n_lam);
lam_total = nan(n_lam, 1);
lam_feas = cell(n_lam, 1);
for li = 1:n_lam
    s_l = func_cutsearch(bmi_s, reach, t_grid, cost, lambda_list(li), ...
        cfg.n_min, cfg.K, cfg.cut_step, NaN);
    lam_t_opt(:, li) = s_l.t_opt;
    lam_edges(:, li) = s_l.bmi_edges;
    lam_total(li) = s_l.total;
    lam_feas{li} = s_l.feasible_level;
end
res2.lambda_list = lambda_list;
res2.lam_t_opt = lam_t_opt;
res2.lam_edges = lam_edges;
res2.lam_total = lam_total;

%% (7) 结果表与图件
write_q2_tables(res2, cfg);
plot_q2_figures(res2, cfg);
end

function write_q2_tables(res2, cfg)
K = numel(res2.t_opt);
edges = res2.bmi_edges;
int_str = cell(K, 1);
for g = 1:K
    int_str{g} = sprintf('[%.2f, %.2f)', edges(g), edges(g + 1));
end
cost_at = cost_fcn(res2.t_opt, cfg.c_risk);
main_tbl = table((1:K)', int_str, res2.n_g(:), res2.t_opt, res2.p_at, cost_at(:), res2.risk_min, ...
    'VariableNames', {'BMI组', 'BMI区间', '孕妇数', '最佳时点', '达标比例', '时间风险', '总风险'});
writetable(main_tbl, fullfile(cfg.tbl_dir, 'q2_group_result.csv'));

mc_tbl = table((1:K)', res2.t_mc_mean, res2.t_mc_std, res2.t_mc_min, res2.t_mc_max, ...
    'VariableNames', {'BMI组', '时点均值', '时点标准差', '时点最小', '时点最大'});
writetable(mc_tbl, fullfile(cfg.tbl_dir, 'q2_mc_table.csv'));

% λ 灵敏度表（长表）与边界表
rows = {};
for li = 1:numel(res2.lambda_list)
    for g = 1:K
        rows(end+1, :) = {res2.lambda_list(li), g, res2.lam_t_opt(g, li), res2.lam_total(li)};
    end
end
lam_tbl = cell2table(rows, 'VariableNames', {'λ', 'BMI组', '最佳时点', '总风险'});
writetable(lam_tbl, fullfile(cfg.tbl_dir, 'q2_lambda_sens.csv'));

edge_tbl = array2table(res2.lam_edges', 'VariableNames', ...
    arrayfun(@(k) sprintf('边界%d', k), 1:K+1, 'UniformOutput', false));
edge_tbl = [table(res2.lambda_list', 'VariableNames', {'λ'}), edge_tbl];
writetable(edge_tbl, fullfile(cfg.tbl_dir, 'q2_edges_lambda.csv'));
end

function plot_q2_figures(res2, cfg)
K = numel(res2.t_opt);
t_grid = cfg.t_grid;
colors = [0.16 0.36 0.75; 0.85 0.33 0.30; 0.93 0.69 0.13; 0.30 0.65 0.35];

% BMI 分组可视化: 孕妇 BMI 分布 + 分组边界
fig = figure('Visible', 'off');
histogram(res2.bmi_s, 30, 'FaceColor', [0.45 0.55 0.70], 'EdgeAlpha', 0.3);
hold on;
for g = 2:K
    xline(res2.bmi_edges(g), '--', sprintf('b%d=%.1f', g, res2.bmi_edges(g)), ...
        'Color', [0.6 0.25 0.25], 'LabelOrientation', 'horizontal');
end
xlabel('孕妇BMI均值'); ylabel('孕妇数');
title('BMI 分组结果');
fig_export(fig, cfg.fig_dir, 'q2_bmi_groups');

% 各组风险随检测时点变化曲线（Q2-6）
fig = figure('Visible', 'off');
for g = 1:K
    pg = mean(res2.reach(res2.idx_st(g):res2.idx_end(g), :), 1);
    risk = res2.cost + cfg.lambda_risk * (1 - pg);
    plot(t_grid, risk, '-', 'Color', colors(mod(g - 1, 4) + 1, :), 'LineWidth', 1.5);
    hold on;
end
xlabel('检测时点(周)'); ylabel('总风险');
legend(arrayfun(@(g) sprintf('组%d', g), 1:K, 'UniformOutput', false), 'Location', 'best');
title('各组风险随检测时点变化');
fig_export(fig, cfg.fig_dir, 'q2_risk_curves');

% 各组达标比例随检测时点变化曲线（Q2-2）
fig = figure('Visible', 'off');
for g = 1:K
    pg = mean(res2.reach(res2.idx_st(g):res2.idx_end(g), :), 1);
    plot(t_grid, pg, '-', 'Color', colors(mod(g - 1, 4) + 1, :), 'LineWidth', 1.5);
    hold on;
end
xlabel('检测时点(周)'); ylabel('预测达标比例');
legend(arrayfun(@(g) sprintf('组%d', g), 1:K, 'UniformOutput', false), 'Location', 'best');
title('各组预测达标比例随检测时点变化');
fig_export(fig, cfg.fig_dir, 'q2_p_reach_curves');
end

function cost = cost_fcn(t, c)
% Q2-4: t<13→c1, 13≤t<28→c2, t≥28→c3（返回 1×numel(t) 行向量，与达标比例行向量方向一致）
cost = ones(1, numel(t)) * c(1);
tr = t(:)';
cost(tr >= 13 & tr < 28) = c(2);
cost(tr >= 28) = c(3);
end
