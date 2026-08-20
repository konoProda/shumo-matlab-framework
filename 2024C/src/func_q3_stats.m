function [rho_sp, clusters] = func_q3_stats(param, sol_q2)
% func_q3_stats —— 问题3 统计分析（映射表 S3-1~S3-3）
% 输入: param 参数结构；sol_q2 Q2 解（含 sol_q2.scen 情景数据）
% 输出: rho_sp    41x41 Spearman 相关矩阵（情景均价向量，市场相关性口径）
%       clusters  41x1 K-means 聚类标签（4 类，特征：预期销量/均价/成本/价格波动区间）
% 另存 outputs/q3_stats.mat（含 jb_pvals、rho_demand、rho_price、特征矩阵、聚类中心）

scen = sol_q2.scen;
K = scen.K;
omega_list = param.omega_list;
oj = omega_list(:, 2);

% 每作物情景向量：7 年跨情景的 销量/均价/成本 均值与价格波动
demand_vec = zeros(41, K);   % 各年各季全村需求总和
price_vec  = zeros(41, K);   % 各作物 Ω 行均价
cost_vec   = zeros(41, K);
for w = 1:K
    for j = 1:41
        ids = find(oj == j);
        demand_vec(j, w) = sum(scen.demand_w(j, :, :, w), 'all');
        price_vec(j, w)  = mean(scen.price_w(ids, :, w), 'all');
        cost_vec(j, w)   = mean(scen.cost_w(ids, :, w), 'all');
    end
end

% S3-1 正态性检验（jbtest，内置，逐作物）
jb_pvals = zeros(41, 3);
for j = 1:41
    [~, jb_pvals(j, 1)] = jbtest(price_vec(j, :)');
    [~, jb_pvals(j, 2)] = jbtest(demand_vec(j, :)');
    [~, jb_pvals(j, 3)] = jbtest(cost_vec(j, :)');
end

% S3-2 Spearman 相关矩阵（内置 corr）
rho_sp     = corr(price_vec', 'Type', 'Spearman');
rho_demand = corr(demand_vec', 'Type', 'Spearman');

% S3-3 K-means 聚类（4 类，特征先标准化）
feat = [mean(demand_vec, 2), mean(price_vec, 2), mean(cost_vec, 2), std(price_vec, 0, 2)];
feat_z = zscore(feat);
rng(2024);
clusters = kmeans(feat_z, 4, 'Replicates', 10);

save(fullfile(fileparts(mfilename('fullpath')), '..', 'outputs', 'q3_stats.mat'), ...
     'rho_sp', 'rho_demand', 'clusters', 'jb_pvals', 'feat');
end
