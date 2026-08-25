%% probe_toy.m — 小规模探针（组内产物，不交付）
% 用途：用微型合成数据（男 24 孕妇×3 记录、女 10 孕妇×4 记录）跑通
%       数据装配与全部求解链路，验证主流程无致命错误后再上全量数据
% 运行: matlab -batch "run('scripts/probe_toy.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));   % 子函数目录加入搜索路径
probe_dir = fullfile(PROJ_ROOT, 'outputs', 'probe');
if ~exist(probe_dir, 'dir'), mkdir(probe_dir); end

rng(1);

%% 微型数据（列结构与 load_data 输出契约一致：数值列 double、文本列 string）
fprintf('[探针] 构造微型数据...\n');
male_raw = build_male_toy();
female_raw = build_female_toy();

%% 参数（小规模：K=2、粗网格、少量 MC）
cfg = struct();
cfg.thr_y = 0.04;  cfg.c_risk = [1 5 20];  cfg.lambda_risk = 10;
cfg.K = 2;  cfg.n_min = 3;  cfg.cut_step = 1;
cfg.t_grid = (10:0.5:25)';
cfg.eta_target = 0.8;  cfg.mc_iters = 20;  cfg.rho_gc = 1;  cfg.recall_min = 0.9;
cfg.lambda_grid = [5 10];  cfg.eta_grid = [0.7 0.8];
cfg.rho_grid = [0.5 1];  cfg.sigma_scale = [0.5 1];
cfg.n_rec_male = 72;  cfg.n_subj_male = 24;
cfg.n_rec_female = 40;  cfg.n_subj_female = 10;
cfg.tbl_dir = probe_dir;  cfg.fig_dir = probe_dir;  cfg.out_dir = probe_dir;

%% 全链路
fprintf('[探针] preprocess male...\n');
male   = preprocess_data(male_raw, 'male', cfg);
fprintf('[探针] preprocess female...\n');
female = preprocess_data(female_raw, 'female', cfg);
fprintf('[探针] 问题一...\n');
res1 = q1_correlation_regression(male, cfg);
fprintf('[探针] 问题二...\n');
res2 = q2_bmi_group_timing(male, cfg, res1.sigma_resid);
fprintf('[探针] 问题三...\n');
res3 = q3_multifactor_timing(male, cfg, res1.sigma_resid, res2);
fprintf('[探针] 问题四...\n');
res4 = q4_female_abnormal_judge(female, cfg);
fprintf('[探针] 灵敏度...\n');
sens = sensitivity_analysis(male, female, cfg, res1, res2, res3, res4);

%% 探针断言
assert(all(res2.t_opt >= 10 & res2.t_opt <= 25), '问题二最佳时点超出候选集合');
assert(all(diff(res2.bmi_edges) >= 0), '问题二分组边界非递增');
assert(all(res3.t_opt >= 10 & res3.t_opt <= 25), '问题三推荐时点超出候选集合');
assert(sum(res4.cm(:)) == 40, '问题四混淆矩阵样本数不符');
assert(issorted(sens.lam_edges(:, 1)), 'λ灵敏度边界列未排序');
fprintf('探针通过：全链路无致命错误，输出落于 %s\n', probe_dir);

function raw = build_male_toy()
n_rec = 72;  n_subj = 24;
subj_ids = string(compose('A%03d', (1:n_subj)'));
bmi_s = 21 + 19 * rand(n_subj, 1);
wk = [11; 15; 19];
gwk = nan(n_rec, 1);
num = nan(n_rec, 31);
num(:, 1) = (1:n_rec)';
num(:, 3) = randi([24 40], n_rec, 1);
num(:, 4) = 150 + randi([0 20], n_rec, 1);
num(:, 5) = 55 + randi([0 40], n_rec, 1);
num(:, 9) = mod((1:n_rec)' - 1, 3) + 1;
num(:, 12) = randi([3e6 7e6], n_rec, 1);
num(:, 13) = 0.75 + 0.1 * rand(n_rec, 1);
num(:, 14) = 0.02 + 0.03 * rand(n_rec, 1);
num(:, 15) = 0.5e6 + 3e6 * rand(n_rec, 1);
num(:, 16) = 0.35 + 0.1 * rand(n_rec, 1);
num(:, 17:20) = randn(n_rec, 4);
num(:, 21) = randn(n_rec, 1);
num(:, 23) = 0.05 + 0.05 * rand(n_rec, 1);
num(:, 24:26) = 0.35 + 0.05 * rand(n_rec, 3);
num(:, 27) = 0.01 + 0.05 * rand(n_rec, 1);
num(:, 29) = randi([1 4], n_rec, 1);
num(:, 30) = randi([0 2], n_rec, 1);
for i = 1:n_rec
    s = mod(i - 1, n_subj) + 1;
    r = floor((i - 1) / n_subj) + 1;
    num(i, 11) = bmi_s(s) + 0.1 * randn;
    gwk(i) = wk(r) + floor(rand * 7) / 7;
    yv = 0.02 + 0.004 * gwk(i) - 0.0008 * bmi_s(s) + 0.008 * randn;
    num(i, 22) = max(yv, 0.005);
end
txt = strings(n_rec, 31);
txt(:, 2) = repmat(subj_ids, 3, 1);
txt(:, 6) = "2023-01-01";
txt(:, 7) = "自然受孕";
txt(3, 7) = "IUI（人工授精）";
txt(5, 7) = "IVF（试管婴儿）";
txt(:, 8) = "20230101";
txt(:, 10) = string(arrayfun(@(x) sprintf('%dw+%d', floor(x), floor(rem(x, 1) * 7)), gwk, 'UniformOutput', false));
txt(:, 28) = "";
txt(10, 28) = "T18";
txt(20, 28) = "T21";
txt(:, 31) = "是";
raw = table();
for k = 1:31
    if ismember(k, [2 6 7 8 10 28 31])
        raw.(sprintf('c%d', k)) = txt(:, k);
    else
        raw.(sprintf('c%d', k)) = num(:, k);
    end
end
end

function raw = build_female_toy()
n_rec = 40;  n_subj = 10;
subj_ids = string(compose('B%03d', (1:n_subj)'));
wk = [12; 16; 20; 24];
gwk = nan(n_rec, 1);
num = nan(n_rec, 31);
num(:, 1) = (1:n_rec)';
num(:, 3) = randi([24 40], n_rec, 1);
num(:, 4) = 150 + randi([0 20], n_rec, 1);
num(:, 5) = 55 + randi([0 40], n_rec, 1);
num(:, 9) = mod((1:n_rec)' - 1, 4) + 1;
num(:, 12) = randi([3e6 7e6], n_rec, 1);
num(:, 13) = 0.75 + 0.1 * rand(n_rec, 1);
num(:, 14) = 0.02 + 0.03 * rand(n_rec, 1);
num(:, 15) = 0.5e6 + 3e6 * rand(n_rec, 1);
num(:, 16) = 0.35 + 0.1 * rand(n_rec, 1);
num(:, 17:20) = randn(n_rec, 4);
num(:, 23) = 0.05 + 0.05 * rand(n_rec, 1);
num(:, 24:26) = 0.35 + 0.05 * rand(n_rec, 3);
num(:, 27) = 0.01 + 0.05 * rand(n_rec, 1);
num(:, 29) = randi([1 4], n_rec, 1);
num(:, 30) = randi([0 2], n_rec, 1);
for i = 1:n_rec
    s = mod(i - 1, n_subj) + 1;
    r = floor((i - 1) / n_subj) + 1;
    num(i, 11) = 25 + 15 * rand;
    gwk(i) = wk(r) + floor(rand * 7) / 7;
end
num(7, 11) = NaN;   % 模拟女胎 BMI 缺失 1 条（P6）
txt = strings(n_rec, 31);
txt(:, 2) = repmat(subj_ids, 4, 1);
txt(:, 6) = "2023-01-01";
txt(:, 7) = "自然受孕";
txt(:, 8) = "20230101";
txt(:, 10) = string(arrayfun(@(x) sprintf('%dw+%d', floor(x), floor(rem(x, 1) * 7)), gwk, 'UniformOutput', false));
txt(:, 28) = "";
txt(3, 28) = "T21";
txt(7, 28) = "T18";
txt(15, 28) = "T13";
txt(22, 28) = "T18T21";
txt(31, 28) = "T21";
txt(:, 31) = "是";
raw = table();
for k = 1:31
    if ismember(k, [2 6 7 8 10 28 31])
        raw.(sprintf('c%d', k)) = txt(:, k);
    else
        raw.(sprintf('c%d', k)) = num(:, k);
    end
end
end
