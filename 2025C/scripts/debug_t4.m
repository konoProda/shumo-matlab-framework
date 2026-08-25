%% debug_t4.m — 临时诊断：T4 两项失败的实值（组内产物）
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
male_s = preprocess_data(male_sub, 'male', cfg);
res1 = q1_correlation_regression(male_s, cfg);
res2 = q2_bmi_group_timing(male_s, cfg, res1.sigma_resid);

fprintf('t_mc_std = '); fprintf('%.4f ', res2.t_mc_std); fprintf('\n');
fprintf('t_opt(主解) = '); fprintf('%.6f ', res2.t_opt); fprintf('\n');
fprintf('feasible_level = %s\n', res2.feasible_level);
fprintf('n_g = '); fprintf('%d ', res2.n_g); fprintf('\n');

t_opt_runs = nan(cfg.K, 10);
for ri = 1:10
    s_r = func_cutsearch(res2.bmi_s, res2.reach, cfg.t_grid, res2.cost, ...
        cfg.lambda_risk, cfg.n_min, cfg.K, cfg.cut_step, NaN);
    t_opt_runs(:, ri) = s_r.t_opt;
end
fprintf('10次运行唯一值: '); fprintf('%.6f ', unique(t_opt_runs(:))); fprintf('\n');
fprintf('每组10次: \n'); disp(t_opt_runs');
