function mdl = func_ols(X, y)
% 最小二乘回归与全套检验输出（各问回归模型共用）
% 输入: X  n×p 设计矩阵（含截距列）
%       y  n×1 响应向量
% 输出: mdl 结构体: beta/se/t_stat/p_val/r2/r2_adj/f_stat/f_p/resid/sigma/n/p
n = size(X, 1);
p = size(X, 2);
dof = n - p;

beta = X \ y;
resid = y - X * beta;
sse = resid' * resid;
sigma2 = sse / dof;
se = sqrt(diag(sigma2 * inv(X' * X)));
t_stat = beta ./ se;
p_val = 2 * tcdf(-abs(t_stat), dof);

sst = sum((y - mean(y)).^2);
r2 = 1 - sse / sst;
r2_adj = 1 - (1 - r2) * (n - 1) / dof;
f_stat = (r2 / (p - 1)) / ((1 - r2) / dof);
f_p = 1 - fcdf(f_stat, p - 1, dof);

mdl = struct('beta', beta, 'se', se, 't_stat', t_stat, 'p_val', p_val, ...
    'r2', r2, 'r2_adj', r2_adj, 'f_stat', f_stat, 'f_p', f_p, ...
    'resid', resid, 'sigma', sqrt(sigma2), 'n', n, 'p', p);
end
