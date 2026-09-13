function pv10 = func_interp_q3b(fc_hour, nLead)
%FUNC_INTERP_Q3B  整点光伏预报 → 10 分钟预报（线性插值，裁决 A9/A10）
%
%   相邻整点预报 F_h、F_{h+1} 之间线性过渡：
%       F_{h,m} = F_h + (m/6)·(F_{h+1} − F_h)，m = 0..5
%   小时序号自**发布时刻**起算：lead ℓ = 1 对应发布时刻所在的那 10 分钟。
%   末位不外推：缺 F_25 时最后一个小时保持 F_24（裁决 A10），
%   既不外推、也不取下一版预报补齐。
%
%   输入  fc_hour  1×24 该发布时刻的整点预报（预报 1..24 小时，kW）
%         nLead    需要的提前量个数（stage s 的视野长度；本版取 144 或当天剩余）
%   输出  pv10     1×nLead 各提前量的 10 分钟光伏预测功率 kW

fc_hour = fc_hour(:).';
t = 0:nLead-1;
h = floor(t / 6);                       % 相对发布时刻的小时序号（0 基）
m = mod(t, 6);                          % 小时内第几个 10 分钟
p_lo = fc_hour(h + 1);                  % F_h
p_hi = fc_hour(min(h + 2, 24));         % F_{h+1}；末位平延 F_24

pv10 = max(0, p_lo + (m / 6) .* (p_hi - p_lo));

end
