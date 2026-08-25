function out = func_cutsearch(bmi_s, pg_mat, t_grid, cost, lambda, n_min, K, cut_step, eta)
% 有序 BMI 切点枚举搜索（问题二/三共用，目标: 总风险最小）
% 输入: bmi_s    n×1 排序后的孕妇 BMI 均值
%       pg_mat   n×nt 达标矩阵（问题二: 0/1 指示; 问题三: π 概率），行序与 bmi_s 一致
%       t_grid   nt×1 候选检测时点（升序）
%       cost     nt×1 时间风险 C(t)
%       lambda   不达标惩罚系数 λ
%       n_min    组最小样本（不可行自动放宽到 10；仍不可行降 K-1 备选）
%       K        分组数
%       cut_step 切点候选步长（1=全枚举，2=隔位取候选）
%       eta      达标比例下限 η（NaN 表示无该约束）
% 输出: out.bmi_edges (K+1)×1 边界（切点取相邻 BMI 中点，两端取 min/max）
%       out.t_opt / out.p_at / out.risk_min (K×1)、out.total
%       out.n_g (K×1)、out.eta_ok (K×1 logical)
%       out.cuts (K-1)×1 切点位置（bmi_s 下标，供蒙特卡洛/灵敏度复用）
%       out.feasible_level 'nmin20'/'nmin10'/'K_backup'、out.K_used

n = numel(bmi_s);
cum_p = cumsum(pg_mat, 1);     % n×nt 前缀和，分组达标数 = 端点差

[best, feasible_level] = search_K(bmi_s, cum_p, t_grid, cost, lambda, n_min, K, cut_step, eta);
if isempty(best)
    % N1: n_min 与 10 均不可行时降 K-1 组作为备选方案
    [best, ~] = search_K(bmi_s, cum_p, t_grid, cost, lambda, 10, K - 1, cut_step, eta);
    feasible_level = 'K_backup';
end
out = best;
out.feasible_level = feasible_level;
out.K_used = numel(best.n_g);
end

function [best, feasible_level] = search_K(bmi_s, cum_p, t_grid, cost, lambda, n_min, K, cut_step, eta)
n = numel(bmi_s);
best = [];
feasible_level = '';
for nm = unique([n_min, 10], 'stable')   % 先试 n_min，不可行再放宽到 10（N1 顺序）
    cand = nm : cut_step : (n - nm);          % 切点候选位置
    if numel(cand) < K - 1, continue; end
    combs = nchoosek(cand, K - 1);
    d = diff(combs, 1, 2);
    ok = all(d >= nm, 2) & combs(:, 1) >= nm & (n - combs(:, end)) >= nm;
    combs = combs(ok, :);
    if isempty(combs), continue; end
    best_total = inf;
    for ci = 1:size(combs, 1)
        cuts = combs(ci, :);
        idx_st = [1, cuts + 1];
        idx_end = [cuts, n];
        [total, tvec, pvec, rvec, okvec] = eval_partition(idx_st, idx_end, cum_p, t_grid, cost, lambda, eta);
        if total < best_total
            best_total = total;
            best.t_opt = tvec; best.p_at = pvec; best.risk_min = rvec;
            best.eta_ok = okvec; best.total = total; best.cuts = cuts;
        end
    end
    if ~isempty(best)
        best.n_g = diff([0, best.cuts, n]);
        bmi_edges = nan(K + 1, 1);
        bmi_edges(1) = bmi_s(1);
        bmi_edges(end) = bmi_s(end);
        for g = 2:K
            bmi_edges(g) = (bmi_s(best.cuts(g-1)) + bmi_s(best.cuts(g-1) + 1)) / 2;
        end
        best.bmi_edges = bmi_edges;
        feasible_level = sprintf('nmin%d', nm);
        return;
    end
end
end

function [total, tvec, pvec, rvec, okvec] = eval_partition(idx_st, idx_end, cum_p, t_grid, cost, lambda, eta)
% 给定一组切点，计算各组达标比例、风险与最优时点（Q2-2/Q2-6/Q2-7、Q3-5~Q3-7）
K = numel(idx_st);
tvec = nan(K, 1); pvec = nan(K, 1); rvec = nan(K, 1); okvec = true(K, 1);
total = 0;
for g = 1:K
    ng = idx_end(g) - idx_st(g) + 1;
    s = cum_p(idx_end(g), :);
    if idx_st(g) > 1
        s = s - cum_p(idx_st(g) - 1, :);
    end
    pg = s / ng;
    risk = cost + lambda * (1 - pg);
    if isnan(eta)
        [rmin, tidx] = min(risk);
    else
        feas = find(pg >= eta);
        if isempty(feas)
            [~, tidx] = max(pg);       % N4: 组内不可行时取最大达标比例时点
            okvec(g) = false;
            rmin = risk(tidx);
        else
            [rmin, tpos] = min(risk(feas));
            tidx = feas(tpos);
        end
    end
    tvec(g) = t_grid(tidx);
    pvec(g) = pg(tidx);
    rvec(g) = rmin;
    total = total + rmin;
end
end
