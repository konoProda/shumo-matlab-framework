% probe_q2_price.m —— 电价相位错位的静态影响估计（只读，不覆盖任何结果）
%
% 目的：在同一份已求得的购电/紧急购电计划上，分别按【现行相位】与【修正相位】
%（附件1 末行 0:00+1 归位到首槽）重新计价，量化相位错位本身的影响量级。
% 注：这不是重解后的结果，只是"同一计划换价目表"的静态差，用于判断修复的优先级。

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_corr.mat'));
res = S.res;  prm = S.prm;
D   = size(res.buy_m, 1);
day_list = (datetime(2025,1,1) + days(0:D-1)).';
ri  = (find(day_list == datetime(2025,2,1)) : D).';

[p_cur, ~, ~, ~] = func_read_q2(PROJ_ROOT);        % 现行（按列号）电价
raw   = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
p_raw = cell2mat(raw(2:145, 2));            % 行标签 0:10 ... 23:50, 0:00+1
p_fix = p_raw([numel(p_raw), 1:numel(p_raw)-1]);   % 末行归位到首槽
res.price_v = p_cur;

fprintf('=== 现行相位 vs 修正相位（同一计划，静态计价）===\n');
fprintf('  两套电价逐槽最大差 %.4f 元/kWh，均值均为 %.5f\n', ...
        max(abs(p_fix - res.price_v(:))), mean(p_fix));

for tag = {'全年365天', '报送窗口334天'}
    if tag{1}(1) == '全'; idx = (1:D).'; else; idx = ri; end
    B = res.buy_m(idx, :);   E = res.em_m(idx, :);
    plan_now = sum(B * res.price_v(:));
    plan_fix = sum(B * p_fix);
    em_now   = prm.kappa_em * sum(E * res.price_v(:));
    em_fix   = prm.kappa_em * sum(E * p_fix);
    fprintf('\n  【%s】\n', tag{1});
    fprintf('    计划购电费   现行 %16.2f  →  修正 %16.2f   差 %+12.2f 元\n', ...
            plan_now, plan_fix, plan_fix - plan_now);
    fprintf('    紧急购电费   现行 %16.2f  →  修正 %16.2f   差 %+12.2f 元\n', ...
            em_now, em_fix, em_fix - em_now);
    fprintf('    合计         现行 %16.2f  →  修正 %16.2f   差 %+12.2f 元（%.4f%%）\n', ...
            plan_now + em_now, plan_fix + em_fix, (plan_fix + em_fix) - (plan_now + em_now), ...
            100 * ((plan_fix + em_fix) - (plan_now + em_now)) / (plan_now + em_now));
end

% 相位差在时间上的分布（哪些小时的计价变化最大）
blk = reshape(abs(p_fix(1:144) - res.price_v(:)), 6, 24);
[~, hmax] = max(max(blk, [], 1));
fprintf('\n  逐小时最大相位差：最大出现在 %d:00 时段（%.4f 元/kWh）\n', hmax - 1, max(blk(:)));
fprintf('  相邻槽跳变最大的位置：');
[dj, jj] = max(abs(diff(p_raw)));
fprintf(' 标签 %s → %s 处跳变 %.4f 元/kWh\n', ...
        strtrim(string(raw(1 + jj, 1))), strtrim(string(raw(2 + jj, 1))), dj);
