%% test_2025C.m — 2025C 代码与数学模型一致性测试（组内产物，不交付）
% 测试项:
%   T1 全量数据维度与规模断言（P1~P6）
%   T2 特殊值检验（构造数据、可手算预期）
%   T3 数学一致性（真实数据前 200 行子集跑通各问）
%   T4 稳定性检验（确定性部分 10 次重跑；蒙特卡洛固定种子可复现）
%   T5 参考解交叉验证（无建模手参考解，用切点步长/时点网格交叉验证）
%   T6 收敛性检验（本题无迭代算法，为有限枚举搜索，不适用）
% 结果保存至 outputs/test_results.mat，日志写入 outputs/test_log.txt

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
out_dir = fullfile(PROJ_ROOT, 'outputs');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
log_file = fullfile(out_dir, 'test_log.txt');
if exist(log_file, 'file'), delete(log_file); end   % 幂等覆盖旧日志
diary(log_file);
diary on;

results = struct();
pass_all = true;

%% 参数（与主程序一致，独立重建）
cfg = struct();
cfg.thr_y = 0.04;  cfg.c_risk = [1 5 20];  cfg.lambda_risk = 10;
cfg.K = 4;  cfg.n_min = 20;  cfg.cut_step = 2;
cfg.t_grid = (10:1/7:25)';
cfg.eta_target = 0.85;  cfg.mc_iters = 100;  cfg.rho_gc = 1;  cfg.recall_min = 0.90;
cfg.lambda_grid = [5 10];  cfg.eta_grid = [0.80 0.85 0.90];
cfg.rho_grid = [0.5 1];  cfg.sigma_scale = [0.5 1];
cfg.tbl_dir = fullfile(out_dir, 'test_tables');
cfg.fig_dir = fullfile(out_dir, 'test_figures');
if ~exist(cfg.tbl_dir, 'dir'), mkdir(cfg.tbl_dir); end
if ~exist(cfg.fig_dir, 'dir'), mkdir(cfg.fig_dir); end

%% T1 全量数据维度与规模（P1~P6、检验清单 §9 相关项）
fprintf('\n=== T1 全量数据维度与规模 ===\n');
[male_raw, female_raw] = load_data(fullfile(PROJ_ROOT, 'data', '附件.xlsx'));
male = preprocess_data(male_raw, 'male', cfg);
female = preprocess_data(female_raw, 'female', cfg);

chk('男胎记录数1082', height(male.rec) == 1082);
chk('女胎记录数605', height(female.rec) == 605);
chk('男胎孕妇数267', height(male.subj) == 267);
chk('女胎孕妇数147', numel(unique(female.rec.subj_id)) == 147);
chk('男胎孕周全部解析成功(兼容16W+1)', ~any(isnan(male.rec.gest_week)));
chk('女胎Y染色体Z值/Y浓度两列全空', all(isnan(female_raw{:, 21})) && all(isnan(female_raw{:, 22})));
chk('女胎BMI缺失恰好1条', sum(isnan(female.rec.bmi)) == 1);
chk('男胎达标标签来自Y浓度与0.04比较', ...
    all(male.rec.is_reach == double(male.rec.y_conc >= cfg.thr_y)));
chk('男胎达标记录占比≈0.866(实测)', abs(mean(male.rec.is_reach) - 0.866) < 0.01);
chk('女胎异常标签来自AB列,共67条', sum(female.rec.abn_label) == 67);
chk('AB标签来源正确(AB列非AE列)', ...
    all(female.rec.abn_label == double(~ismissing(female_raw{:, 28}) & female_raw{:, 28} ~= "")));
chk('男胎BMI均值在经验范围', all(male.subj.bmi_mean > 20 & male.subj.bmi_mean < 47));
chk('首次达标时间在孕周范围内', ...
    all(male.subj.first_reach_time(isnan(male.subj.first_reach_time) == 0) >= 10));
chk('怀孕次数截断编码: 男胎≥3共300条映射为3', sum(male.rec.grav_ge3) == 300 && ...
    all(male.rec.gravidity(male.rec.grav_ge3 == 1) == 3));
chk('怀孕次数截断编码: 女胎≥3共165条映射为3', sum(female.rec.grav_ge3) == 165 && ...
    all(female.rec.gravidity(female.rec.grav_ge3 == 1) == 3));

%% T2 特殊值检验（构造数据，可手算预期）
fprintf('\n=== T2 特殊值检验 ===\n');

% T2a 孕周解析（P1）
gest_str = ["13w"; "13w+5"; "16W+1"; "11w+6"; "12w"; "25w"; "XW+2"; ""];
gest_exp = [13; 13 + 5/7; 16 + 1/7; 11 + 6/7; 12; 25; NaN; NaN];
male_gest = make_craft_table(gest_str, [0.05; 0.05; 0.05; 0.05; 0.05; 0.05; 0.05; 0.05]);
cfg_gest = cfg; cfg_gest.n_rec_male = 8; cfg_gest.n_subj_male = 8;
d_gest = preprocess_data(male_gest, 'male', cfg_gest);
chk('孕周解析已知用例(8条)', max(abs(d_gest.rec.gest_week - gest_exp), [], 'omitnan') < 1e-9);

% T2b 达标标签边界（P2）
y_edge = [0.0399; 0.04; 0.0401];
male_edge = make_craft_table(["10w"; "10w"; "10w"], y_edge);
cfg_edge = cfg; cfg_edge.n_rec_male = 3; cfg_edge.n_subj_male = 3;
d_edge = preprocess_data(male_edge, 'male', cfg_edge);
chk('Y=0.04边界达标标签[0 1 1]', all(d_edge.rec.is_reach == [0; 1; 1]));

% T2c 女胎异常标签（P3）
ab_strs = [""; "T13"; "T18T21"; "T13T18T21"; "T21"];
female_craft = make_craft_female(ab_strs);
cfg_fc = cfg; cfg_fc.n_rec_female = 5; cfg_fc.n_subj_female = 5;
d_fc = preprocess_data(female_craft, 'female', cfg_fc);
chk('女胎异常标签A', all(d_fc.rec.abn_label == [0; 1; 1; 1; 1]));
chk('女胎T13子标签', all(d_fc.rec.abn_t13 == [0; 1; 0; 1; 0]));
chk('女胎T18子标签', all(d_fc.rec.abn_t18 == [0; 0; 1; 1; 0]));
chk('女胎T21子标签', all(d_fc.rec.abn_t21 == [0; 0; 1; 1; 1]));

% T2d 切点搜索手算用例（Q2-4~Q2-7 核心）
% 4 名孕妇, K=2, n_min=1; 前两名所有时点达标, 后两名仅 t=14 达标
bmi_s2 = [21; 22; 23; 24];
t_grid2 = [10; 11; 12; 13; 14];
cost2 = [1 1 1 5 5];
pg2 = [1 1 1 1 1; 1 1 1 1 1; 0 0 0 0 1; 0 0 0 0 1];
sol2 = func_cutsearch(bmi_s2, pg2, t_grid2, cost2, 10, 1, 2, 1, NaN);
chk('手算用例:总风险=6', abs(sol2.total - 6) < 1e-9);
chk('手算用例:最佳时点[10 14]', all(abs(sol2.t_opt - [10; 14]) < 1e-9));
chk('手算用例:组人数[1 3]', all(sol2.n_g(:) == [1; 3]));
chk('手算用例:边界[21 21.5 24]', max(abs(sol2.bmi_edges - [21; 21.5; 24])) < 1e-9);

% T2e 标准正态累积（Q3-4 用）
chk('normcdf(1)=0.8413', abs(normcdf(1) - 0.841344746068543) < 1e-9);

%% T3 数学一致性（真实数据前 200 行子集）
fprintf('\n=== T3 数学一致性（200 行子集） ===\n');
male_sub = male_raw(1:200, :);
female_sub = female_raw(1:200, :);
cfg_sub = cfg;
cfg_sub.n_rec_male = 200;
cfg_sub.n_subj_male = numel(unique(male_sub{:, 2}));
cfg_sub.n_rec_female = 200;
cfg_sub.n_subj_female = numel(unique(female_sub{:, 2}));
male_s = preprocess_data(male_sub, 'male', cfg_sub);
female_s = preprocess_data(female_sub, 'female', cfg_sub);

res1 = q1_correlation_regression(male_s, cfg_sub);
chk('Q1:相关系数6个且在[-1,1]', numel(res1.corr_vec) == 6 && all(abs(res1.corr_vec) <= 1));
chk('Q1:基础/交互/二次/对照系数维度', ...
    numel(res1.base.beta) == 6 && numel(res1.int.beta) == 7 && ...
    numel(res1.quad.beta) == 6 && numel(res1.hw.beta) == 7);
chk('Q1:各模型R2在[0,1]', ...
    all([res1.base.r2 res1.int.r2 res1.quad.r2 res1.hw.r2] >= 0 & ...
        [res1.base.r2 res1.int.r2 res1.quad.r2 res1.hw.r2] <= 1));
chk('Q1:主模型选择符合N8规则', ...
    strcmp(res1.model_selected, 'int') || strcmp(res1.model_selected, 'base'));
chk('Q1:σ>0', res1.sigma_resid > 0);

res2 = q2_bmi_group_timing(male_s, cfg_sub, res1.sigma_resid);
chk('Q2:时点都在候选集合[10,25]', all(res2.t_opt >= 10 & res2.t_opt <= 25));
chk('Q2:分组边界递增', all(diff(res2.bmi_edges) >= 0));
chk('Q2:各组人数之和=子集孕妇数', sum(res2.n_g) == cfg_sub.n_subj_male);
chk('Q2:达标比例在[0,1]', all(res2.p_at >= 0 & res2.p_at <= 1));
chk('Q2:可行性等级合法', ismember(res2.feasible_level, {'nmin20', 'nmin10', 'K_backup'}));
chk('Q2:风险函数分段正确(实测cost)', ...
    all(res2.cost(cfg_sub.t_grid < 13) == 1) && ...
    all(res2.cost(cfg_sub.t_grid >= 13 & cfg_sub.t_grid < 28) == 5));
chk('Q2:蒙特卡洛时点范围合理', all(res2.t_opt_mc(:) >= 10 & res2.t_opt_mc(:) <= 25));

res3 = q3_multifactor_timing(male_s, cfg_sub, res1.sigma_resid, res2);
chk('Q3:γ系数10个(含IUI/IVF哑变量)', numel(res3.gamma_mdl.beta) == 10);
chk('Q3:δ对照系数6个', numel(res3.delta_mdl.beta) == 6);
chk('Q3:质量指标6列', size(res3.qual_q, 2) == 6);
chk('Q3:等权与PCA权重均归一化', abs(sum(res3.qual_w_eq) - 1) < 1e-12 && abs(sum(res3.qual_w_pca) - 1) < 1e-12);
chk('Q3:推荐时点都在候选集合', all(res3.t_opt >= 10 & res3.t_opt <= 25));
chk('Q3:η满足组其达标比例≥η', all(res3.p_at(res3.eta_ok) >= cfg_sub.eta_target - 1e-9));
chk('Q3:π值在[0,1]', all(res3.pi_mat(:) >= 0 & res3.pi_mat(:) <= 1));

res4 = q4_female_abnormal_judge(female_s, cfg_sub);
chk('Q4:评分分量6列605→200行', size(res4.comp, 2) == 6 && size(res4.comp, 1) == 200);
chk('Q4:混淆矩阵总和=子集记录数', sum(res4.cm(:)) == 200);
chk('Q4:五指标在[0,1]', ...
    all([res4.metrics.acc res4.metrics.rec res4.metrics.prec res4.metrics.f1 res4.metrics.spec] >= 0) && ...
    all([res4.metrics.acc res4.metrics.rec res4.metrics.prec res4.metrics.f1 res4.metrics.spec] <= 1));
chk('Q4:Youden=Se+Sp-1', ...
    abs((res4.se_curve(1) + res4.sp_curve(1) - 1) - res4.youden(1)) < 1e-12);
chk('Q4:阈值在评分范围内', res4.theta_opt >= min(res4.abn_score) - 1 && res4.theta_opt <= max(res4.abn_score) + 1);
chk('Q4:BMI分层4层', size(res4.layer_rows, 1) == 4);

sens = sensitivity_analysis(male_s, female_s, cfg_sub, res1, res2, res3, res4);
chk('SENS:λ/η/ρ/σ结果维度正确', ...
    all(size(sens.lam_t_opt) == [cfg_sub.K numel(cfg_sub.lambda_grid)]) && ...
    all(size(sens.eta_t_opt) == [cfg_sub.K numel(cfg_sub.eta_grid)]) && ...
    all(size(sens.sigma_t_opt) == [cfg_sub.K numel(cfg_sub.sigma_scale)]));

%% T4 稳定性检验
fprintf('\n=== T4 稳定性检验 ===\n');
% 确定性核心: 用问题二已存储输入直接重跑切点搜索 10 次
t_opt_runs = nan(cfg_sub.K, 10);
for ri = 1:10
    s_r = func_cutsearch(res2.bmi_s, res2.reach, cfg_sub.t_grid, res2.cost, ...
        cfg_sub.lambda_risk, cfg_sub.n_min, cfg_sub.K, cfg_sub.cut_step, NaN);
    t_opt_runs(:, ri) = s_r.t_opt;
end
chk('T4:确定性算法10次结果标准差<1e-3', max(std(t_opt_runs, 0, 2)) < 1e-3);
chk('T4:确定性算法10次结果完全相同', all(t_opt_runs == t_opt_runs(:, 1), 'all'));
mc_runs = cell(1, 2);
for ri = 1:2
    r2r = q2_bmi_group_timing(male_s, cfg_sub, res1.sigma_resid);
    mc_runs{ri} = r2r.t_opt_mc;
end
chk('T4:蒙特卡洛固定种子可复现', all(mc_runs{1}(:) == mc_runs{2}(:)));
chk('T4:蒙特卡洛时点标准差<6周(子集样本量小,全量在/report复核)', all(res2.t_mc_std < 6));

%% T5 参考解交叉验证（无建模手参考解，步长/网格交叉验证）
fprintf('\n=== T5 交叉验证 ===\n');
cfg_step1 = cfg_sub; cfg_step1.cut_step = 1;
r_step1 = q2_bmi_group_timing(male_s, cfg_step1, res1.sigma_resid);
chk('T5:细步长总风险不劣于粗步长', r_step1.total <= res2.total + 1e-9);
chk('T5:两步长最佳时点差异≤0.3周', all(abs(r_step1.t_opt - res2.t_opt) <= 0.3));

cfg_coarse = cfg_sub; cfg_coarse.t_grid = (10:0.5:25)';
r_coarse = q2_bmi_group_timing(male_s, cfg_coarse, res1.sigma_resid);
chk('T5:粗时点网格与时点差异≤0.55周', all(abs(r_coarse.t_opt - res2.t_opt) <= 0.55));

%% T6 收敛性检验
fprintf('\n=== T6 收敛性 ===\n');
fprintf('本题无迭代算法（切点搜索为有限枚举、阈值遍历为有限网格），收敛性检验不适用。\n');
results.t6_note = '不适用: 无迭代算法';

%% 汇总
results.pass_all = pass_all;
results.note = '测试通过标准: 特殊值可手算预期误差<1e-9; 确定性算法10次标准差<1e-3; 交叉验证步长一致性';
save(fullfile(out_dir, 'test_results.mat'), 'results');
fprintf('\n========== 测试汇总: %s ==========\n', ternary(pass_all, '全部通过', '存在失败项'));
diary off;
if ~pass_all
    error('存在失败测试项，详见 test_log.txt');
end

function chk(name, ok)
% 单项检查: 记录结果并计数
global_pass = evalin('caller', 'pass_all');
results = evalin('caller', 'results');
if ok
    fprintf('[通过] %s\n', name);
else
    fprintf('[失败] %s\n', name);
    global_pass = false;
end
assignin('caller', 'pass_all', global_pass);
assignin('caller', 'results', results);
end

function s = ternary(cond, a, b)
if cond, s = a; else, s = b; end
end

function raw = make_craft_table(gest_str, y_conc)
% 构造男胎 31 列微型表（仅孕周与 Y 浓度有区分度，其余列取常数）
n = numel(gest_str);
num = nan(n, 31);
num(:, 1) = (1:n)';
num(:, 3) = 30;
num(:, 4) = 160;
num(:, 5) = 60;
num(:, 9) = 1;
num(:, 11) = 25;
num(:, 12) = 5e6;
num(:, 13) = 0.8;
num(:, 14) = 0.02;
num(:, 15) = 4e6;
num(:, 16) = 0.4;
num(:, 17:21) = 0;
num(:, 22) = y_conc;
num(:, 23) = 0.05;
num(:, 24:26) = 0.4;
num(:, 27) = 0.02;
num(:, 29) = 1;
num(:, 30) = 0;
txt = strings(n, 31);
txt(:, 2) = string(compose('A%03d', (1:n)'));
txt(:, 6) = "2023-01-01";
txt(:, 7) = "自然受孕";
txt(:, 8) = "20230101";
txt(:, 10) = gest_str;
txt(:, 28) = "";
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

function raw = make_craft_female(ab_strs)
n = numel(ab_strs);
num = nan(n, 31);
num(:, 1) = (1:n)';
num(:, 3) = 30;
num(:, 4) = 160;
num(:, 5) = 60;
num(:, 9) = 1;
num(:, 11) = 25;
num(:, 12) = 5e6;
num(:, 13) = 0.8;
num(:, 14) = 0.02;
num(:, 15) = 4e6;
num(:, 16) = 0.4;
num(:, 17:20) = 0;
num(:, 23) = 0.05;
num(:, 24:26) = 0.4;
num(:, 27) = 0.02;
num(:, 29) = 1;
num(:, 30) = 0;
txt = strings(n, 31);
txt(:, 2) = string(compose('B%03d', (1:n)'));
txt(:, 6) = "2023-01-01";
txt(:, 7) = "自然受孕";
txt(:, 8) = "20230101";
txt(:, 10) = "12w";
txt(:, 28) = ab_strs;
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
