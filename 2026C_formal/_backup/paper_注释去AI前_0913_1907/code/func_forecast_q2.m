function [Lhat, PVhat, used_max, fb] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d0)
%FUNC_FORECAST_Q2  问题二：同星期滚动均值预测（因果，严格只用历史实际数据）
%
%   两种用法：
%     逐日模式（省略 d0）—— 第 d 天 0:00 只预测当天：
%         S_d = {d-7, d-14, ..., d-7K} ∩ {τ >= 1}
%     地平线模式（给定决策日 d0）—— 在 d0 的 0:00 预测第 d0..D 天：
%         对目标日 τ，取【严格早于 d0】的最近 K 个与 τ 同星期的日期
%         S(τ|d0) = { 最大的 s < d0 且 s ≡ τ (mod 7), 再往前每周取一个 }
%         当 τ = d0 时该式退化为 {d0-7, d0-14, ...}，与逐日模式完全一致。
%
%   全年视野滚动要求"预测任何未来日期时都不得引用决策日及之后的实际数据"，
%   两种模式共用同一套回溯规则，只是可用数据的截止日不同（τ 或 d0）。
%
%   冷启动（S 为空）：
%     截止日为 1        → 附件1 典型日曲线（此时无任何历史可用）
%     截止日 >= 2       → 第 1..dcut-1 天的同时段扩展均值
%
%   输入  load_m / pv_m   D×T 实际负荷 / 实际光伏（已按起始标签口径读入）
%         L1 / PV1        T×1 附件1 典型日曲线
%         K               同星期回溯周数（建模口径 K=4）
%         d0              （可选）决策日索引；省略或给 [] 为逐日模式
%   输出  Lhat / PVhat    逐日模式 D×T；地平线模式 (D-d0+1)×T，行 j 对应第 d0+j-1 天
%         used_max       各行实际引用的最晚历史日（信息泄漏自检用）
%         fb             各行是否走了冷启动/扩展均值回退（诊断用，逻辑向量）

[D, T] = size(load_m);
assert(size(pv_m,1) == D && size(pv_m,2) == T, '负荷与光伏维度不一致');
assert(numel(L1) == T && numel(PV1) == T, '附件1 典型日长度与日内时段数不一致');

if nargin < 6 || isempty(d0)
    d0 = 0;                                   % 0 表示逐日模式
else
    assert(d0 >= 1 && d0 <= D, '决策日索引越界');
end

tau_list = (d0 == 0) * 1 + (d0 > 0) * d0;    % 起始目标日
n   = D - tau_list + 1;
Lhat = zeros(n, T);  PVhat = zeros(n, T);  used_max = zeros(n, 1);
fb   = false(n, 1);
cut  = zeros(n, 1);

for j = 1:n
    tau = tau_list + j - 1;
    dcut = tau;                               % 逐日模式：可用数据严格早于 τ
    if d0 > 0
        dcut = d0;                            % 地平线模式：严格早于决策日
    end
    cut(j) = dcut;

    if dcut == 1
        Lhat(j,:) = L1(:).';  PVhat(j,:) = PV1(:).';  used_max(j) = 0;
        fb(j) = true;
        continue;
    end

    r  = mod(tau - 1, 7);                     % τ 的星期分组
    s1 = (r + 1) + 7*floor((dcut - 1 - (r + 1))/7);   % 最近一个同星期且 < dcut 的日
    S  = s1 : -7 : max(1, s1 - 7*(K - 1));
    S  = S(S >= 1);

    if isempty(S)
        Lhat(j,:) = mean(load_m(1:dcut-1,:), 1);
        PVhat(j,:) = mean(pv_m(1:dcut-1,:), 1);
        used_max(j) = dcut - 1;
        fb(j) = true;
    else
        Lhat(j,:) = mean(load_m(S,:), 1);
        PVhat(j,:) = mean(pv_m(S,:), 1);
        used_max(j) = max(S);
    end
end

assert(all(used_max < cut), '信息泄漏：存在引用决策日或之后实际数据的预测');

end
