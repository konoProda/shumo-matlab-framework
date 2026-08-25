%% debug_q3.m — 临时诊断：定位问题三子集运行失败原因（组内产物）
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
cfg = struct();
cfg.thr_y = 0.04; cfg.c_risk = [1 5 20]; cfg.lambda_risk = 10;
cfg.K = 4; cfg.n_min = 20; cfg.cut_step = 2; cfg.t_grid = (10:1/7:25)';
cfg.eta_target = 0.85; cfg.mc_iters = 100; cfg.rho_gc = 1; cfg.recall_min = 0.90;
cfg.lambda_grid = [5 10]; cfg.eta_grid = [0.80 0.85 0.90];
cfg.rho_grid = [0.5 1]; cfg.sigma_scale = [0.5 1];
cfg.tbl_dir = fullfile(PROJ_ROOT, 'outputs', 'probe');
cfg.fig_dir = fullfile(PROJ_ROOT, 'outputs', 'probe');
cfg.n_rec_male = 200;

[male_raw, ~] = load_data(fullfile(PROJ_ROOT, 'data', '附件.xlsx'));
male_sub = male_raw(1:200, :);
cfg.n_subj_male = numel(unique(male_sub{:, 2}));
fprintf('子集孕妇数: %d\n', cfg.n_subj_male);
male_s = preprocess_data(male_sub, 'male', cfg);
res1 = q1_correlation_regression(male_s, cfg);
fprintf('sigma_resid = %.6g\n', res1.sigma_resid);

% 手工复现 q3 内部计算
rec = male_s.rec;
subj = male_s.subj;
y = rec.y_conc; t = rec.gest_week; bmi = rec.bmi;
zs = @(x) (x - mean(x, 'omitnan')) / std(x, 'omitnan');
qL = zs(rec.raw_reads); qM = zs(rec.map_rate); qN = -zs(rec.dup_rate);
qO = zs(rec.unique_reads); qAA = -zs(rec.filter_ratio);
qGC = -abs(rec.gc - mean(rec.gc, 'omitnan')) / std(rec.gc, 'omitnan');
qual_q = [qL qM qN qO qAA qGC];
qual_score = qual_q * ones(6, 1) / 6;
fprintf('qual_score NaN 数: %d, 范围 [%.4g %.4g]\n', ...
    sum(isnan(qual_score)), min(qual_score), max(qual_score));

Xfull = [ones(height(rec), 1), t, bmi, rec.age, rec.gravidity, rec.parity, ...
    rec.d_iui, rec.d_ivf, qual_score, t .* bmi];
ok = all(isfinite(Xfull), 2) & isfinite(y);
mdl = func_ols(Xfull(ok, :), y(ok));
g = mdl.beta;
fprintf('gamma beta: '); fprintf('%.6g ', g); fprintf('\n');
fprintf('beta 含 NaN/Inf: %d\n', any(~isfinite(g)));

[~, ~, grp] = unique(rec.subj_id, 'stable');
q_mean_all = splitapply(@(x) mean(x), qual_score, grp);
subj.q_mean = q_mean_all;
[~, sord] = sort(subj.bmi_mean);
bmi_s = subj.bmi_mean(sord);
q_s = subj.q_mean(sord);
a_s = g(1) + g(3) * bmi_s + g(4) * subj.age(sord) + g(5) * subj.gravidity(sord) + ...
      g(6) * subj.parity(sord) + g(7) * subj.d_iui(sord) + g(8) * subj.d_ivf(sord) + g(9) * q_s;
b_s = g(2) + g(10) * bmi_s;
fprintf('bmi_s NaN: %d, q_s NaN: %d\n', sum(isnan(bmi_s)), sum(isnan(q_s)));
fprintf('age NaN: %d, grav NaN: %d, par NaN: %d\n', sum(isnan(subj.age)), ...
    sum(isnan(subj.gravidity)), sum(isnan(subj.parity)));
fprintf('a_s NaN: %d, b_s NaN: %d\n', sum(isnan(a_s)), sum(isnan(b_s)));
Yhat3 = a_s + b_s * cfg.t_grid';
fprintf('Yhat3 NaN: %d\n', sum(isnan(Yhat3(:))));
pi_mat = normcdf((Yhat3 - cfg.thr_y) / res1.sigma_resid);
fprintf('pi_mat NaN 数: %d, 范围 [%.6g %.6g]\n', sum(isnan(pi_mat(:))), ...
    min(pi_mat(:)), max(pi_mat(:)));
bad_rows = find(any(isnan(Yhat3), 2));
fprintf('NaN 行数: %d, 行号: ', numel(bad_rows)); fprintf('%d ', bad_rows(1:min(20, end))); fprintf('\n');
cost = ones(1, numel(cfg.t_grid)) * cfg.c_risk(1);
tr = cfg.t_grid(:)';
cost(tr >= 13 & tr < 28) = cfg.c_risk(2);
sol = func_cutsearch(bmi_s, pi_mat, cfg.t_grid, cost, cfg.lambda_risk, ...
    cfg.n_min, cfg.K, cfg.cut_step, cfg.eta_target);
fprintf('cutsearch 结果: total=%.6g, feasible=%s\n', sol.total, sol.feasible_level);
