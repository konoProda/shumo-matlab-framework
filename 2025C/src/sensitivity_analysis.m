function sens = sensitivity_analysis(male, female, cfg, res1, res2, res3, res4)
% 灵敏度分析：λ（重搜切点，含分组边界稳定性）、η（固定切点）、ρ（类型判定）、
% σ 缩放（固定 γ 与切点重算 π）
% 输入: male/female preprocess 输出结构体、cfg 参数、res1~res4 各问结果
% 输出: sens 结构体: lam_t_opt/lam_edges/lam_total、eta_t_opt/eta_ok、
%       rho_type_cnt、sigma_t_opt
% 落盘: outputs/tables/sens_*.csv、figures/sens_*.png|eps

t_grid = cfg.t_grid;
K = cfg.K;
colors = [0.16 0.36 0.75; 0.85 0.33 0.30; 0.93 0.69 0.13; 0.30 0.65 0.35];

%% (1) λ 灵敏度: 问题二重搜切点（含分组边界稳定性）
lambda_list = cfg.lambda_grid;
n_lam = numel(lambda_list);
lam_t_opt = nan(K, n_lam);
lam_edges = nan(K + 1, n_lam);
lam_total = nan(n_lam, 1);
for li = 1:n_lam
    s_l = func_cutsearch(res2.bmi_s, res2.reach, t_grid, res2.cost, lambda_list(li), ...
        cfg.n_min, cfg.K, cfg.cut_step, NaN);
    lam_t_opt(:, li) = s_l.t_opt;
    lam_edges(:, li) = s_l.bmi_edges;
    lam_total(li) = s_l.total;
end
sens.lam_t_opt = lam_t_opt;
sens.lam_edges = lam_edges;
sens.lam_total = lam_total;
sens.lambda_list = lambda_list;

% λ 表与边界稳定性表
rows = {};
for li = 1:n_lam
    for g = 1:K
        rows(end+1, :) = {lambda_list(li), g, lam_t_opt(g, li), lam_total(li)};
    end
end
lam_tbl = cell2table(rows, 'VariableNames', {'λ', 'BMI组', '最佳时点', '总风险'});
writetable(lam_tbl, fullfile(cfg.tbl_dir, 'sens_lambda.csv'));
edge_tbl = array2table(lam_edges', 'VariableNames', ...
    arrayfun(@(k) sprintf('边界%d', k), 1:K+1, 'UniformOutput', false));
edge_tbl = [table(lambda_list', 'VariableNames', {'λ'}), edge_tbl];
writetable(edge_tbl, fullfile(cfg.tbl_dir, 'sens_edges_lambda.csv'));

fig = figure('Visible', 'off');
b = bar(lam_t_opt');
xticks(1:K);
xticklabels(arrayfun(@(g) sprintf('组%d', g), 1:K, 'UniformOutput', false));
ylabel('最佳时点(周)');
legend(arrayfun(@(l) sprintf('λ=%d', l), lambda_list, 'UniformOutput', false), 'Location', 'best');
title('不同λ下的各组最佳时点');
for bi = 1:n_lam
    for g = 1:K
        text(g + (bi - (n_lam + 1) / 2) * 0.2, lam_t_opt(g, bi) + 0.15, ...
            sprintf('%.1f', lam_t_opt(g, bi)), 'HorizontalAlignment', 'center', 'FontSize', 8);
    end
end
fig_export(fig, cfg.fig_dir, 'sens_lambda');

%% (2) η 灵敏度: 固定问题三切点，仅重选时点
eta_list = cfg.eta_grid;
n_eta = numel(eta_list);
eta_t_opt = nan(K, n_eta);
eta_ok = true(K, n_eta);
eta_p_at = nan(K, n_eta);
for ei = 1:n_eta
    [eta_t_opt(:, ei), eta_p_at(:, ei), eta_ok(:, ei)] = select_t_under_eta( ...
        res3.pi_mat, res3.idx_st, res3.idx_end, t_grid, res2.cost, cfg.lambda_risk, eta_list(ei));
end
sens.eta_t_opt = eta_t_opt;
sens.eta_ok = eta_ok;
sens.eta_list = eta_list;

rows = {};
for ei = 1:n_eta
    for g = 1:K
        rows(end+1, :) = {eta_list(ei), g, eta_t_opt(g, ei), eta_p_at(g, ei), eta_ok(g, ei)};
    end
end
eta_tbl = cell2table(rows, 'VariableNames', {'η', 'BMI组', '推荐时点', '达标比例', '是否满足η'});
writetable(eta_tbl, fullfile(cfg.tbl_dir, 'sens_eta.csv'));

fig = figure('Visible', 'off');
b = bar(eta_t_opt');
xticks(1:K);
xticklabels(arrayfun(@(g) sprintf('组%d', g), 1:K, 'UniformOutput', false));
ylabel('推荐时点(周)');
legend(arrayfun(@(e) sprintf('η=%.2f', e), eta_list, 'UniformOutput', false), 'Location', 'best');
title('不同η下的各组推荐时点');
for bi = 1:n_eta
    for g = 1:K
        text(g + (bi - (n_eta + 1) / 2) * 0.2, eta_t_opt(g, bi) + 0.15, ...
            sprintf('%.1f', eta_t_opt(g, bi)), 'HorizontalAlignment', 'center', 'FontSize', 8);
    end
end
fig_export(fig, cfg.fig_dir, 'sens_eta');

%% (3) ρ 灵敏度: 异常类型判定
rho_list = cfg.rho_grid;
n_rho = numel(rho_list);
type_names = ["T13", "T18", "T21", "T13T18", "T13T21", "T18T21", "T13T18T21"];
rho_cnt = nan(numel(type_names), n_rho);
for ri = 1:n_rho
    tp_r = type_judge(res4.nz13, res4.nz18, res4.nz21, ...
        res4.ngc13, res4.ngc18, res4.ngc21, rho_list(ri), res4.pred_abn);
    for ti = 1:numel(type_names)
        rho_cnt(ti, ri) = sum(tp_r == type_names(ti));
    end
end
sens.rho_cnt = rho_cnt;
sens.rho_list = rho_list;
rho_tbl = array2table(rho_cnt, 'VariableNames', ...
    arrayfun(@(r) sprintf('ρ=%.1f', r), rho_list, 'UniformOutput', false));
rho_tbl = [table(type_names', 'VariableNames', {'预测类型'}), rho_tbl];
writetable(rho_tbl, fullfile(cfg.tbl_dir, 'sens_rho.csv'));

%% (4) σ 缩放灵敏度: 固定 γ 与切点，重算 π 与推荐时点
sigma_scale = cfg.sigma_scale;
n_sg = numel(sigma_scale);
sigma_t_opt = nan(K, n_sg);
sigma_p_at = nan(K, n_sg);
for si = 1:n_sg
    sig_s = res1.sigma_resid * sigma_scale(si);
    pi_s = normcdf((res3.a_s + res3.b_s * t_grid' - cfg.thr_y) / sig_s);
    [sigma_t_opt(:, si), sigma_p_at(:, si), ~] = select_t_under_eta( ...
        pi_s, res3.idx_st, res3.idx_end, t_grid, res2.cost, cfg.lambda_risk, cfg.eta_target);
end
sens.sigma_scale = sigma_scale;
sens.sigma_t_opt = sigma_t_opt;

rows = {};
for si = 1:n_sg
    for g = 1:K
        rows(end+1, :) = {sigma_scale(si), g, sigma_t_opt(g, si), sigma_p_at(g, si)};
    end
end
sg_tbl = cell2table(rows, 'VariableNames', {'σ缩放', 'BMI组', '推荐时点', '达标比例'});
writetable(sg_tbl, fullfile(cfg.tbl_dir, 'sens_sigma.csv'));

fig = figure('Visible', 'off');
b = bar(sigma_t_opt');
xticks(1:K);
xticklabels(arrayfun(@(g) sprintf('组%d', g), 1:K, 'UniformOutput', false));
ylabel('推荐时点(周)');
legend(arrayfun(@(s) sprintf('σ×%.1f', s), sigma_scale, 'UniformOutput', false), 'Location', 'best');
title('不同检测误差σ下的各组推荐时点');
for bi = 1:n_sg
    for g = 1:K
        text(g + (bi - (n_sg + 1) / 2) * 0.2, sigma_t_opt(g, bi) + 0.15, ...
            sprintf('%.1f', sigma_t_opt(g, bi)), 'HorizontalAlignment', 'center', 'FontSize', 8);
    end
end
fig_export(fig, cfg.fig_dir, 'sens_sigma');
end

function [t_opt, p_at, okv] = select_t_under_eta(pi_mat, idx_st, idx_end, t_grid, cost, lambda, eta)
% 固定分组下按 η 约束选每组最优时点（Q3-7，含 N4 不可行处理）
K = numel(idx_st);
t_opt = nan(K, 1);
p_at = nan(K, 1);
okv = true(K, 1);
for g = 1:K
    pg = mean(pi_mat(idx_st(g):idx_end(g), :), 1);
    risk = cost + lambda * (1 - pg);
    feas = find(pg >= eta);
    if isempty(feas)
        [~, tidx] = max(pg);
        okv(g) = false;
    else
        [~, tpos] = min(risk(feas));
        tidx = feas(tpos);
    end
    t_opt(g) = t_grid(tidx);
    p_at(g) = pg(tidx);
end
end

function type_pred = type_judge(nz13, nz18, nz21, ngc13, ngc18, ngc21, rho, abn_mask)
% Q4-7: 对已判异常样本做类型判定，S_second ≥ 0.8·S_max 报复合异常
S13 = nz13 + rho * ngc13;
S18 = nz18 + rho * ngc18;
S21 = nz21 + rho * ngc21;
n = numel(S13);
type_pred = repmat("", n, 1);
for i = find(abn_mask)'
    [sv, so] = sort([S13(i), S18(i), S21(i)], 'descend');
    names = ["T13", "T18", "T21"];
    if sv(1) > 0 && sv(3) >= 0.8 * sv(1)
        type_pred(i) = strjoin(names(sort(so)), "");
    elseif sv(1) > 0 && sv(2) >= 0.8 * sv(1)
        type_pred(i) = strjoin(names(sort(so(1:2))), "");
    else
        type_pred(i) = names(so(1));
    end
end
end
