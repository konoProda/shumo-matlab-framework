function [scores, weights] = func_topsis(X, is_benefit)
% =========================================================================
% func_topsis.m — 熵权法+TOPSIS 综合评价（问题3选品预筛选, C2裁定）
% 输入: X         指标矩阵 (n×m), n=评价对象, m=指标
%       is_benefit 指标方向 (1×m): 1=极大型(越大越好), 0=极小型(越小越好)
% 输出: scores  相对贴近度得分 (n×1), 越大越优
%       weights 熵权法权重 (1×m)
% 步骤: ① 正向化(极小型取 max-x) ② 向量归一化 ③ 熵权法求权重
%       ④ 加权矩阵 ⑤ 正/负理想解 ⑥ 相对贴近度
% =========================================================================

%% 1. 正向化: 极小型指标转为极大型
X = X + 0;                                      % 防御性复制
n = size(X, 1);
for j = 1:size(X, 2)
    if ~is_benefit(j)
        X(:, j) = max(X(:, j)) - X(:, j);      % 极小型 → 极大型
    end
end

%% 2. 向量归一化 z = x / sqrt(Σx²)
z = X ./ sqrt(sum(X.^2, 1));
z(:, all(X == 0, 1)) = 0;

%% 3. 熵权法求权重
p = (z - min(z, [], 1)) ./ (max(z, [], 1) - min(z, [], 1) + eps);   % 平移至(0,1]
p = p ./ sum(p, 1);
e = -sum(p .* log(p + eps), 1) / log(n);        % 信息熵
d = 1 - e;                                      % 信息效用值
weights = d / sum(d);                           % 熵权

%% 4. 加权矩阵 + 正/负理想解
v = z .* weights;
v_pos = max(v, [], 1);
v_neg = min(v, [], 1);

%% 5. 欧氏距离与相对贴近度
D_pos = sqrt(sum((v - v_pos).^2, 2));
D_neg = sqrt(sum((v - v_neg).^2, 2));
scores = D_neg ./ (D_pos + D_neg);
end
