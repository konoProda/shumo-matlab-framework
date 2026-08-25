%% smoke_full.m — 全量数据冒烟：数据装配 + 问题一跑通并落盘（组内产物，不交付）
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
cfg = struct();
cfg.thr_y = 0.04; cfg.c_risk = [1 5 20]; cfg.lambda_risk = 10;
cfg.K = 4; cfg.n_min = 20; cfg.cut_step = 2; cfg.t_grid = (10:1/7:25)';
cfg.eta_target = 0.85; cfg.mc_iters = 500; cfg.rho_gc = 1; cfg.recall_min = 0.90;
cfg.lambda_grid = [5 10 20]; cfg.eta_grid = [0.80 0.85 0.90 0.95];
cfg.rho_grid = [0.5 1 2]; cfg.sigma_scale = [0.5 1 2];
cfg.tbl_dir = fullfile(PROJ_ROOT, 'outputs', 'tables');
cfg.fig_dir = fullfile(PROJ_ROOT, 'figures');
cfg.out_dir = fullfile(PROJ_ROOT, 'outputs');
if ~exist(cfg.tbl_dir, 'dir'), mkdir(cfg.tbl_dir); end

[male_raw, female_raw] = load_data(fullfile(PROJ_ROOT, 'data', '附件.xlsx'));
male = preprocess_data(male_raw, 'male', cfg);
female = preprocess_data(female_raw, 'female', cfg);
fprintf('[冒烟] 男 %d 条/%d 人, 女 %d 条/%d 人, ≥3编码标志 男%d 女%d\n', ...
    height(male.rec), height(male.subj), height(female.rec), ...
    numel(unique(female.rec.subj_id)), sum(male.rec.grav_ge3), sum(female.rec.grav_ge3));
res1 = q1_correlation_regression(male, cfg);
fprintf('[冒烟] 问题一完成: 主模型=%s, sigma=%.6f, r(t)=%.4f, r(BMI)=%.4f, R2(int)=%.4f\n', ...
    res1.model_selected, res1.sigma_resid, res1.corr_vec(1), res1.corr_vec(2), res1.int.r2);
disp('[冒烟] 问题一表格与图件已落盘，冒烟通过');
