function res3 = q3_multifactor_timing(male, cfg, sigma_resid, res2)
% 问题三：多因素修正下的分组与时点优化（Q3-1~Q3-8）
% 输入: male  preprocess 输出的男胎结构体
%       cfg   主程序参数结构体
%       sigma_resid 问题一最终主模型残差标准差（Q1-6，进入达标概率 π）
%       res2  问题二结果（用于 Q2/Q3 分组与时点对比）
% 输出: res3 结构体: qual_q/qual_score/qual_w（等权与 PCA）、gamma_mdl/delta_mdl、
%       bmi_edges/t_opt/p_at/eta_ok/cuts/total（η=0.85 主结果）、
%       PCA 权重对比结果、a_s/b_s/pi_mat（供 σ 灵敏度复用）
% 落盘: outputs/tables/q3_*.csv、figures/q3_*.png|eps

rec = male.rec;
subj = male.subj;
y = rec.y_conc;
t = rec.gest_week;
bmi = rec.bmi;
t_grid = cfg.t_grid;
nt = numel(t_grid);

%% (1) 测序质量综合指标（Q3-2/Q3-3）: 正向化 + 等权；PCA 权重作对比
zs = @(x) (x - mean(x, 'omitnan')) / std(x, 'omitnan');
qL = zs(rec.raw_reads);
qM = zs(rec.map_rate);
qN = -zs(rec.dup_rate);
qO = zs(rec.unique_reads);
qAA = -zs(rec.filter_ratio);
qGC = -abs(rec.gc - mean(rec.gc, 'omitnan')) / std(rec.gc, 'omitnan');
qual_q = [qL, qM, qN, qO, qAA, qGC];
qual_w_eq = ones(6, 1) / 6;
qual_score = qual_q * qual_w_eq;

[coef_pca, ~, ~, ~, explained] = pca(qual_q);
qual_w_pca = abs(coef_pca(:, 1));
qual_w_pca = qual_w_pca / sum(qual_w_pca);
qual_score_pca = qual_q * qual_w_pca;
res3.qual_q = qual_q;
res3.qual_score = qual_score;
res3.qual_w_eq = qual_w_eq;
res3.qual_w_pca = qual_w_pca;
res3.qual_var_explained = explained(1);

%% (2) 多因素回归（Q3-1）: 记录层估计，含 IUI/IVF 哑变量与 t×BMI 交互项
age = rec.age;
grav = rec.gravidity;
par = rec.parity;
iui = rec.d_iui;
ivf = rec.d_ivf;
Xfull = [ones(height(rec), 1), t, bmi, age, grav, par, iui, ivf, qual_score, t .* bmi];
ok = all(isfinite(Xfull), 2) & isfinite(y);
mdl_gamma = func_ols(Xfull(ok, :), y(ok));
res3.gamma_mdl = mdl_gamma;
% 标准化系数（|γ|·std(x)/std(y)），用于多因素重要性图
res3.std_beta = abs(mdl_gamma.beta(2:end)) .* std(Xfull(ok, 2:end))' / std(y(ok));

% 身高体重对照模型（§6.2，仅比较解释力）
ok_d = all(isfinite([t, rec.height, rec.weight, age, qual_score]), 2) & isfinite(y);
mdl_delta = func_ols([ones(nnz(ok_d), 1), t(ok_d), rec.height(ok_d), ...
    rec.weight(ok_d), age(ok_d), qual_score(ok_d)], y(ok_d));
res3.delta_mdl = mdl_delta;

% 怀孕次数截断编码对照（'≥3' 主处理映射为 3，此处剔除 '≥3' 记录重估 γ）
ok_ge3 = rec.grav_ge3 == 0;
res3.gamma_ge3_mdl = func_ols(Xfull(ok & ok_ge3, :), y(ok & ok_ge3));

%% (3) 孕妇层变量（BMĪ/Q̄ 与固定协变量，按 BMĪ 升序）
[~, ~, grp] = unique(rec.subj_id, 'stable');
q_mean_all = splitapply(@(x) mean(x), qual_score, grp);   % 与 subj 行序一致
subj.q_mean = q_mean_all;
[~, sord] = sort(subj.bmi_mean);
bmi_s = subj.bmi_mean(sord);
age_s = subj.age(sord);
grav_s = subj.gravidity(sord);
par_s = subj.parity(sord);
iui_s = subj.d_iui(sord);
ivf_s = subj.d_ivf(sord);
q_s = subj.q_mean(sord);
n = numel(bmi_s);

%% (4) 个体达标概率 π（Q3-4）: 截距/斜率按孕妇层协变量构成
g = mdl_gamma.beta;
a_s = g(1) + g(3) * bmi_s + g(4) * age_s + g(5) * grav_s + g(6) * par_s + ...
      g(7) * iui_s + g(8) * ivf_s + g(9) * q_s;
b_s = g(2) + g(10) * bmi_s;
Yhat3 = a_s + b_s * t_grid';
pi_mat = normcdf((Yhat3 - cfg.thr_y) / sigma_resid);

%% (5) 切点搜索（Q3-5~Q3-8，η=0.85）
cost = cost_fcn(t_grid, cfg.c_risk);
sol = func_cutsearch(bmi_s, pi_mat, t_grid, cost, cfg.lambda_risk, ...
    cfg.n_min, cfg.K, cfg.cut_step, cfg.eta_target);
res3.bmi_edges = sol.bmi_edges;
res3.t_opt = sol.t_opt;
res3.p_at = sol.p_at;
res3.risk_min = sol.risk_min;
res3.eta_ok = sol.eta_ok;
res3.total = sol.total;
res3.cuts = sol.cuts;
res3.feasible_level = sol.feasible_level;
res3.n_g = sol.n_g;
res3.idx_st = [1, sol.cuts + 1];
res3.idx_end = [sol.cuts, n];
res3.pi_mat = pi_mat;
res3.a_s = a_s;
res3.b_s = b_s;
res3.bmi_s = bmi_s;

%% (6) PCA 权重对比（Q 用 PCA 权重重建后重跑优化）
% 注: η 灵敏度统一由 sensitivity_analysis 输出（sens_eta），此处不重复
q_mean_pca = splitapply(@(x) mean(x), qual_score_pca, grp);   % 与 subj 行序一致
subj.q_mean_pca = q_mean_pca;
q_s_pca = subj.q_mean_pca(sord);
Xfull_pca = [ones(height(rec), 1), t, bmi, age, grav, par, iui, ivf, qual_score_pca, t .* bmi];
ok_pca = all(isfinite(Xfull_pca), 2) & isfinite(y);
mdl_gamma_pca = func_ols(Xfull_pca(ok_pca, :), y(ok_pca));
gp = mdl_gamma_pca.beta;
a_s_pca = gp(1) + gp(3) * bmi_s + gp(4) * age_s + gp(5) * grav_s + gp(6) * par_s + ...
          gp(7) * iui_s + gp(8) * ivf_s + gp(9) * q_s_pca;
b_s_pca = gp(2) + gp(10) * bmi_s;
pi_mat_pca = normcdf((a_s_pca + b_s_pca * t_grid' - cfg.thr_y) / sigma_resid);
sol_pca = func_cutsearch(bmi_s, pi_mat_pca, t_grid, cost, cfg.lambda_risk, ...
    cfg.n_min, cfg.K, cfg.cut_step, cfg.eta_target);
res3.gamma_pca = gp;
res3.t_opt_pca = sol_pca.t_opt;
res3.bmi_edges_pca = sol_pca.bmi_edges;

%% (8) 与问题二对比（§6.6）
write_q3_tables(res3, res2, cfg);
plot_q3_figures(res3, res2, cfg);
end

function write_q3_tables(res3, res2, cfg)
K = numel(res3.t_opt);
edges = res3.bmi_edges;
int_str = cell(K, 1);
remark = cell(K, 1);
for g = 1:K
    int_str{g} = sprintf('[%.2f, %.2f)', edges(g), edges(g + 1));
    if res3.eta_ok(g)
        remark{g} = '';
    else
        remark{g} = '未达到η约束';
    end
end
main_tbl = table((1:K)', int_str, res3.n_g(:), res3.t_opt, res3.p_at, res3.risk_min, remark, ...
    'VariableNames', {'BMI组', 'BMI区间', '孕妇数', '推荐时点', '预测达标比例', '总风险', '备注'});
writetable(main_tbl, fullfile(cfg.tbl_dir, 'q3_group_result.csv'));

% 质量指标权重表（Q3-3）
qual_names = {'原始读段数', '比对比例', '重复读段比例(取反)', '唯一比对读段数', ...
    '过滤比例(取反)', 'GC中心偏离(取反)'};
w_tbl = table(qual_names', res3.qual_w_eq, res3.qual_w_pca, ...
    'VariableNames', {'指标', '等权权重', 'PCA权重'});
w_tbl2 = table(res3.qual_var_explained, 'VariableNames', {'第一主成分方差解释率'});
writetable(w_tbl, fullfile(cfg.tbl_dir, 'q3_quality_weights.csv'));

% 回归系数表（Q3-1 与对照模型）
gamma_names = {'截距', '孕周', 'BMI', '年龄', '怀孕次数', '生产次数', 'IUI', 'IVF', '质量指标Q', 't×BMI'};
gm = res3.gamma_mdl;
reg_rows = cell(numel(gamma_names), 6);
for ci = 1:numel(gamma_names)
    reg_rows(ci, :) = {'主模型', gamma_names{ci}, gm.beta(ci), gm.se(ci), gm.t_stat(ci), gm.p_val(ci)};
end
delta_names = {'截距', '孕周', '身高', '体重', '年龄', '质量指标Q'};
dm = res3.delta_mdl;
for ci = 1:numel(delta_names)
    reg_rows(end+1, :) = {'身高体重对照', delta_names{ci}, dm.beta(ci), dm.se(ci), dm.t_stat(ci), dm.p_val(ci)};
end
reg_tbl = cell2table(reg_rows, 'VariableNames', {'模型', '变量', '系数', '标准误', 't值', 'p值'});
writetable(reg_tbl, fullfile(cfg.tbl_dir, 'q3_reg_table.csv'));

% 怀孕次数截断编码对照表（'≥3'→3 全样本 vs 剔除 '≥3' 记录）
gm2 = res3.gamma_ge3_mdl;
ge3_rows = cell(numel(gamma_names), 4);
for ci = 1:numel(gamma_names)
    ge3_rows(ci, :) = {gamma_names{ci}, gm.beta(ci), gm2.beta(ci), gm2.p_val(ci)};
end
ge3_tbl = cell2table(ge3_rows, 'VariableNames', {'变量', '全样本系数(≥3映射为3)', '剔除≥3系数', '剔除后p值'});
writetable(ge3_tbl, fullfile(cfg.tbl_dir, 'q3_grav_ge3_contrast.csv'));

% 与问题二对比表（§6.6）
cmp_rows = cell(K, 6);
edges2 = res2.bmi_edges;
for g = 1:K
    cmp_rows(g, :) = {g, sprintf('[%.2f, %.2f)', edges2(g), edges2(g + 1)), res2.t_opt(g), ...
        int_str{g}, res3.t_opt(g), res3.t_opt(g) - res2.t_opt(g)};
end
cmp_tbl = cell2table(cmp_rows, 'VariableNames', ...
    {'BMI组', '问题二BMI区间', '问题二时点', '问题三BMI区间', '问题三时点', '时点变化'});
writetable(cmp_tbl, fullfile(cfg.tbl_dir, 'q3_compare_q2.csv'));

% PCA 对比表
pca_tbl = table((1:K)', res3.t_opt, res3.t_opt_pca, res3.t_opt_pca - res3.t_opt, ...
    'VariableNames', {'BMI组', '等权Q推荐时点', 'PCA权重Q推荐时点', '时点变化'});
writetable(pca_tbl, fullfile(cfg.tbl_dir, 'q3_pca_contrast.csv'));
end

function plot_q3_figures(res3, res2, cfg)
K = numel(res3.t_opt);
colors = [0.16 0.36 0.75; 0.85 0.33 0.30; 0.93 0.69 0.13; 0.30 0.65 0.35];

% 问题二/三推荐时点对比（柱状+数值标注）
fig = figure('Visible', 'off');
b = bar([res2.t_opt, res3.t_opt]);
b(1).FaceColor = [0.45 0.55 0.70];
b(2).FaceColor = [0.85 0.55 0.25];
xticks(1:K);
xticklabels(arrayfun(@(g) sprintf('组%d', g), 1:K, 'UniformOutput', false));
ylabel('最佳时点(周)');
legend({'问题二', '问题三'}, 'Location', 'best');
title('问题二与问题三推荐时点对比');
for bi = 1:2
    for g = 1:K
        text(g + (bi - 1.5) * 0.22, b(bi).YData(g) + 0.15, ...
            sprintf('%.1f', b(bi).YData(g)), 'HorizontalAlignment', 'center', 'FontSize', 8);
    end
end
fig_export(fig, cfg.fig_dir, 'q3_compare_q2');

% 多因素重要性条形图（标准化系数 |γ|·std(x)/std(y)，在回归处计算）
std_beta = res3.std_beta;
fig = figure('Visible', 'off');
b = bar(std_beta);
b.FaceColor = [0.30 0.60 0.45];
xticks(1:9);
xticklabels({'孕周', 'BMI', '年龄', '怀孕次数', '生产次数', 'IUI', 'IVF', '质量Q', 't×BMI'});
xtickangle(45);
ylabel('|标准化系数|');
title('多因素重要性');
for i = 1:9
    text(i, std_beta(i) + 0.01 * max(std_beta), sprintf('%.3f', std_beta(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
end
fig_export(fig, cfg.fig_dir, 'q3_importance');
end

function cost = cost_fcn(t, c)
% Q2-4: t<13→c1, 13≤t<28→c2, t≥28→c3（返回 1×numel(t) 行向量，与达标比例行向量方向一致）
cost = ones(1, numel(t)) * c(1);
tr = t(:)';
cost(tr >= 13 & tr < 28) = c(2);
cost(tr >= 28) = c(3);
end
