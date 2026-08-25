% =========================================================================
% test_vegetable.m — 2023c 一致性测试脚本（/test Phase 2, 幂等可重跑）
% 目标: 验证代码实现与建模手数学模型(建模.md)的一致性
% 测试项: T1 维度检查(对照映射表§2) / T2 特殊值与手算用例(公式级)
%         T3 全数据流水线+约束满足性 / T4 稳定性(重复10次, 阈值1e-3)
%         T5 参考解交叉验证(V敏感性单调性+利润公式独立重算)
% 结果: outputs/test_results.mat + test_log.txt(本文件 diary)
% =========================================================================
script_full = mfilename('fullpath');
if ~startsWith(script_full, filesep)                 % run() 相对调用时补全绝对路径
    script_full = fullfile(pwd, script_full);
end
PROJ_ROOT = fileparts(fileparts(script_full));       % shumo/2023c (两层父目录)
addpath(fullfile(PROJ_ROOT, 'src'));
addpath(fullfile(PROJ_ROOT, 'tests'));
OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end
diary(fullfile(OUT_DIR, 'test_log.txt'));
fprintf('===== 2023c 一致性测试开始 =====\n');

tol = 1e-6;                      % 约束满足容差
n_pass = 0;  n_fail = 0;
fail_list = {};                  % 失败项记录
profits = NaN(10, 2);            % T4 稳定性记录(默认 NaN 防未定义)

%% ================= T1 维度检查（对照 math_to_code_mapping.md §2） =================
fprintf('\n--- T1 维度检查 ---\n');
n_prod_exp = 251;  n_cat_exp = 6;  T_exp = 1085;  H_exp = 7;
try
    prod_info = func_preprocess(PROJ_ROOT);
    [h, w] = size(prod_info);
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.1 prod_info 维度 251×5', h == n_prod_exp && w == 5, ...
        '251×5', sprintf('%d×%d', h, w));
    stats_q1 = func_q1_statistics(prod_info, PROJ_ROOT);
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.2 cat_qty 维度 6×1085', ...
        isequal(size(stats_q1.cat_qty), [n_cat_exp, T_exp]), ...
        '6×1085', mat2str(size(stats_q1.cat_qty)));
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.3 item_qty 维度 251×1085', ...
        isequal(size(stats_q1.item_qty), [n_prod_exp, T_exp]), ...
        '251×1085', mat2str(size(stats_q1.item_qty)));
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.4 cat_rho 维度 6×6', ...
        isequal(size(stats_q1.cat_rho), [n_cat_exp, n_cat_exp]), ...
        '6×6', mat2str(size(stats_q1.cat_rho)));
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.5 item_rho 维度 251×251', ...
        isequal(size(stats_q1.item_rho), [n_prod_exp, n_prod_exp]), ...
        '251×251', mat2str(size(stats_q1.item_rho)));
    result_q2 = func_q2_category_lp(stats_q1, prod_info, PROJ_ROOT);
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.6 q2 x_ct_A 维度 6×7', ...
        isequal(size(result_q2.x_ct_A), [n_cat_exp, H_exp]), ...
        '6×7', mat2str(size(result_q2.x_ct_A)));
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.7 q2 w_ct/B_ct/coef3/markup_c 维度', ...
        isequal(size(result_q2.w_ct), [n_cat_exp, H_exp]) && ...
        isequal(size(result_q2.B_ct), [n_cat_exp, H_exp]) && ...
        isequal(size(result_q2.coef3), [n_cat_exp, 4]) && ...
        isequal(size(result_q2.markup_c), [n_cat_exp, 1]), ...
        '6×7/6×7/6×4/6×1', mat2str(size(result_q2.w_ct)));
    result_q3 = func_q3_item_milp(stats_q1, prod_info, PROJ_ROOT);
    n_cand = numel(result_q3.y_vec);
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.8 q3 y/x/p 维度一致 (N×1)', ...
        isequal(size(result_q3.x_vec), [n_cand, 1]) && ...
        isequal(size(result_q3.p_vec), [n_cand, 1]), ...
        'N×1×3', mat2str(size(result_q3.x_vec)));
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1.9 上架数在 27~33 之间', ...
        round(sum(result_q3.y_vec)) >= 27 && round(sum(result_q3.y_vec)) <= 33, ...
        '27≤Σy≤33', sprintf('Σy=%.0f', sum(result_q3.y_vec)));
catch ME
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T1 集成执行无异常', false, '无异常', ME.message);
end

%% ================= T2 特殊值与手算用例（公式级验证） =================
fprintf('\n--- T2 特殊值与手算用例 ---\n');
% T2.1 斯皮尔曼(公式3.3): 手写秩实现交叉验证 + 完全单调情形 ρ=±1
x1 = [1 2 3 4 5]';    y1 = [2 4 6 8 10]';
x2 = [1 2 2 3 4]';    y2 = [5 4 4 2 1]';       % 含并列秩
rho_manual = @(a, b) corr(manual_rank(a), manual_rank(b));
ok21a = abs(rho_manual(x1, y1) - 1) < 1e-12 && ...
        abs(corr(x1, y1, 'Type', 'Spearman') - 1) < 1e-12;
[n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
    'T2.1a 完全单调 Spearman ρ=+1', ok21a, 'ρ=1', ...
    sprintf('manual=%.3g, corr=%.3g', rho_manual(x1, y1), corr(x1, y1, 'Type', 'Spearman')));
ok21b = abs(rho_manual(x2, y2) - corr(x2, y2, 'Type', 'Spearman')) < 1e-12;
[n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
    'T2.1b 含并列秩: 手写秩实现与 corr 一致(<1e-12)', ok21b, ...
    '一致', sprintf('diff=%.3g', abs(rho_manual(x2, y2) - corr(x2, y2, 'Type', 'Spearman'))));

% T2.2 三次多项式拟合精确恢复 (B1): S = 10 + 2P - 0.5P² + 0.1P³ (无噪声)
p_t = (1:7)';  q_t = 10 + 2 * p_t - 0.5 * p_t.^2 + 0.1 * p_t.^3;
coef = polyfit(p_t, q_t, 3);
ok22 = all(abs(coef - [0.1 -0.5 2 10]) < 1e-6);
[n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
    'T2.2 三次多项式系数精确恢复 [0.1 -0.5 2 10]', ok22, ...
    '[0.1 -0.5 2 10]', mat2str(coef, 4));

% T2.3 方案A LP 手算用例: 2品类, margin=[3,2], 需求=[5,8], V=10
% 手算: 品类1利润高先满足需求5, 品类2分得剩余空间5 → x=[5,5], 利润=25
m_t = [3; 2];  d_t = [5; 8];  V_t = 10;
[x_t, ~, flag_t] = linprog(-m_t, ones(1, 2), V_t, [], [], zeros(2, 1), d_t);
profit_t = m_t' * x_t;
ok23 = flag_t >= 1 && norm(x_t - [5; 5]) < 1e-6 && abs(profit_t - 25) < 1e-6;
[n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
    'T2.3 方案A LP 手算用例 x=[5,5], 利润25', ok23, ...
    'x=[5,5], Z=25', sprintf('x=[%.2f,%.2f], Z=%.4f', x_t(1), x_t(2), profit_t));

% T2.4 方案B MILP 手算用例: 1品类, 2档价, margin=[1,3], 需求=[10,5]
% 手算: 选第2档(利润3), x=min(需求5,空间)=5, 利润=15
[sol_b, fval_b, flag_b] = intlinprog([0 0 -1 -3], [1 2], ...
    [-10 0 1 0; 0 -5 0 1], [0; 0], [1 1 0 0], 1, zeros(4, 1), [1; 1; inf; inf]);
ok24 = flag_b >= 1 && abs(-fval_b - 15) < 1e-6 && sol_b(2) > 0.5 && abs(sol_b(4) - 5) < 1e-6;
[n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
    'T2.4 方案B MILP 手算用例 选高价档, 利润15', ok24, ...
    'z=[0,1], x=5, Z=15', sprintf('z=[%.0f,%.0f], x=%.2f, Z=%.4f', sol_b(1), sol_b(2), sol_b(4), -fval_b));

%% ================= T3 约束满足性（全数据结果逐条核对公式4.3/5.3） =================
fprintf('\n--- T3 约束满足性 ---\n');
if exist('result_q2', 'var') && exist('result_q3', 'var')
    % 问题2 方案A: x≤B/(1-ℓ) 损耗上界; 非负 (B2/B3 口径)
    x_ub = result_q2.B_ct ./ (1 - result_q2.loss_bar_c);
    ok31 = all(result_q2.x_ct_A <= x_ub + tol, 'all') && all(result_q2.x_ct_A >= -tol, 'all');
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3.1 q2 补货量≤B/(1-ℓ) 且非负', ok31, '0≤x≤B/(1-ℓ)', ...
        sprintf('max(x-ub)=%.3g', max(result_q2.x_ct_A - x_ub, [], 'all')));
    ok32 = all(isfinite(result_q2.p_ct_A), 'all') && all(result_q2.p_ct_A >= 0, 'all');
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3.2 q2 价格有限且非负 (公式4.3.2 由构造截断保证)', ok32, 'p≥0', ...
        sprintf('min p=%.2f', min(result_q2.p_ct_A, [], 'all')));
    ok33 = all(sum(result_q2.x_ct_A, 1) <= result_q2.V + tol);
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3.3 q2 空间约束 (公式4.3.3)', ok33, sprintf('Σx≤V=%.1f', result_q2.V), ...
        sprintf('max Σx=%.2f', max(sum(result_q2.x_ct_A, 1))));
    % 问题3: 最小陈列/空间/二元性 (公式5.3)
    y_r = round(result_q3.y_vec);
    ok34 = all(result_q3.x_vec >= 2.5 * y_r - tol);
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3.4 q3 最小陈列量 x≥2.5y (公式5.3.2)', ok34, 'x≥2.5y', ...
        sprintf('min(x-2.5y)=%.3g', min(result_q3.x_vec - 2.5 * y_r)));
    ok35 = all(abs(result_q3.y_vec - y_r) < 1e-6);
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3.5 q3 二元性 (公式5.1)', ok35, 'y∈{0,1}', ...
        sprintf('max|y-round(y)|=%.3g', max(abs(result_q3.y_vec - y_r))));
    ok36 = sum(result_q3.x_vec) <= result_q3.V + tol;
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3.6 q3 空间约束 (公式5.3.5)', ok36, sprintf('Σx≤V=%.1f', result_q3.V), ...
        sprintf('Σx=%.2f', sum(result_q3.x_vec)));
    ok37 = isfinite(result_q3.profit_q3) && result_q3.profit_q3 >= 0;
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3.7 q3 利润有限且非负', ok37, 'Z≥0', sprintf('Z=%.2f', result_q3.profit_q3));
else
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T3 约束满足性(前置依赖)', false, 'T1 集成通过', 'T1 失败未产生结果');
end

%% ================= T4 稳定性检验（确定性算法重复10次, 阈值 std<1e-3） =================
fprintf('\n--- T4 稳定性 ---\n');
% 说明: q1 统计量由确定性数据运算(无随机性), 稳定性风险集中在 LP/MILP 求解器,
%       故重复对象为 q2/q3 (各10次); q1 复用 T1 结果
if exist('prod_info', 'var') && exist('stats_q1', 'var')
    for k = 1:10
        % save_figs=false: 稳定性只检验求解器, 跳过重复绘图(3GB无GPU环境会耗尽图形资源)
        rq2 = func_q2_category_lp(stats_q1, prod_info, PROJ_ROOT, false);
        rq3 = func_q3_item_milp(stats_q1, prod_info, PROJ_ROOT, false);
        profits(k, :) = [rq2.profit_A, rq3.profit_q3];
    end
    s1 = std(profits(:, 1));  s2 = std(profits(:, 2));
    ok41 = s1 < 1e-3 && s2 < 1e-3;
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T4.1 重复10次利润标准差 <1e-3 (确定性算法)', ok41, ...
        'std<1e-3', sprintf('std(q2)=%.3g, std(q3)=%.3g', s1, s2));
    rel1 = s1 / max(abs(mean(profits(:, 1))), eps);
    rel2 = s2 / max(abs(mean(profits(:, 2))), eps);
    ok42 = rel1 < 0.01 && rel2 < 0.01;
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T4.2 相对标准差 <1%', ok42, 'rel_std<1%', ...
        sprintf('rel(q2)=%.3g, rel(q3)=%.3g', rel1, rel2));
else
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T4 稳定性(前置依赖)', false, 'T1 集成通过', 'T1 失败未产生结果');
end

%% ================= T5 参考解交叉验证 =================
fprintf('\n--- T5 交叉验证 ---\n');
if exist('result_q2', 'var')
    % 5.1 V 敏感性单调性: 空间放宽 → 利润不降 (数学保证)
    sv = result_q2.sens_V;
    ok51 = all(diff(sv) >= -1e-6 * max(abs(sv), [], 'omitnan'));
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T5.1 q2 空间敏感性利润随V单调非降', ok51, 'monotone', mat2str(round(sv, 2)));
    % 5.2 方案A利润与公式(4.4+B3打折项)独立重算一致
    recov = result_q2.p_ct_A .* ((1 - result_q2.loss_bar_c) + result_q2.loss_bar_c .* result_q2.d_c);
    profit_recalc = sum(sum((recov - result_q2.w_ct .* (1 + result_q2.loss_bar_c)) .* result_q2.x_ct_A));
    ok52 = abs(profit_recalc - result_q2.profit_A) < 1e-9;
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T5.2 q2 利润公式(含打折回收项)独立重算一致', ok52, ...
        sprintf('Z=%.6f', profit_recalc), sprintf('Z=%.6f', result_q2.profit_A));
    % 5.3 方案B全数据可行且利润非负
    ok53 = all(result_q2.x_ct_B >= -tol, 'all') && result_q2.profit_B >= 0;
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T5.3 q2 方案B全数据可行且利润非负', ok53, 'feasible', ...
        sprintf('Z_B=%.2f', result_q2.profit_B));
else
    [n_pass, n_fail, fail_list] = func_record(n_pass, n_fail, fail_list, ...
        'T5 交叉验证(前置依赖)', false, 'T1 集成通过', 'T1 失败未产生结果');
end

%% ================= 汇总判定 =================
fprintf('\n===== 测试汇总: 通过 %d / 失败 %d =====\n', n_pass, n_fail);
test_results = struct('n_pass', n_pass, 'n_fail', n_fail, ...
    'fail_list', {fail_list}, 'profits_stability', profits, ...
    'passed', n_fail == 0);
save(fullfile(OUT_DIR, 'test_results.mat'), 'test_results');
if n_fail > 0
    fid = fopen(fullfile(OUT_DIR, 'failure_notes.md'), 'w');
    fprintf(fid, '# 2023c 测试失败记录\n\n');
    for k = 1:numel(fail_list)
        fprintf(fid, '- %s\n', fail_list{k});
    end
    fclose(fid);
end
fprintf('结果已保存: outputs/test_results.mat\n');
diary off;

%% ================= 局部函数: 手写秩(平均秩处理并列) =================
function r = manual_rank(v)
[sv, order] = sort(v);
r = zeros(size(v));
r(order) = 1:numel(v);
[uv, ~, group] = unique(sv);
for k = 1:numel(uv)
    members = find(group == k);
    r(order(members)) = mean(r(order(members)));   % 并列取平均秩
end
r = r(:);
end
