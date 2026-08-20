function scen = func_gen_scenarios(param, K, rng_seed)
% func_gen_scenarios —— 问题2 随机参数情景生成（映射表 P2-1~P2-4）
% 输入: param  参数结构（含 yield/cost/price_i、demand_2023、p_disaster）
%       K  情景数；rng_seed  随机种子（可复现）
% 输出: scen.K
%       scen.demand_w  41x2x7xK  预期销售量 D_{j,s,t}(w)（逐年独立抽样后复利）
%       scen.cost_w    Nx7xK     种植成本（全村统一增长率 N(5%,1%^2) 复利）
%       scen.price_w   Nx7xK     销售单价（粮食稳/蔬菜N(5%,1%)/食用菌U(-5%,-1%)/羊肚菌-5%）
%       scen.yield_w   Nx7xK     亩产量（±10%波动 + 露天灾害：每地块每年10%独立触发，
%                                减产率每地块独立 U(30%,40%)，B5；大棚不受灾）

rng(rng_seed);
N = numel(param.yield_i);
n_t = 7;
omega_list = param.omega_list;
oi = omega_list(:, 1);   oj = omega_list(:, 2);

% ---- P2-1 需求增长率（按作物逐年独立抽样） ----
g_d = zeros(41, n_t, K);
for j = 1:41
    if j == 6 || j == 7          % 小麦/玉米 U(5%,10%)
        g_d(j, :, :) = 0.05 + 0.05 * rand(n_t, K);
    else                         % 其他作物 U(-5%,5%)
        g_d(j, :, :) = -0.05 + 0.10 * rand(n_t, K);
    end
end
demand_mult = cumprod(1 + g_d, 2);                     % 复利累积
scen.demand_w = zeros(41, 2, n_t, K);
for s = 1:2
    scen.demand_w(:, s, :, :) = reshape(param.demand_2023(:, s), 41, 1, 1) .* demand_mult;
end

% ---- P2-2 种植成本（全村统一逐年增长率） ----
g_c = 0.05 + 0.01 * randn(n_t, K);                     % N(5%,1%^2)
cost_mult = cumprod(1 + g_c, 1);                       % 7xK
scen.cost_w = param.cost_i .* reshape(cost_mult, 1, n_t, K);

% ---- P2-3 销售单价（按作物类别） ----
rate_p = zeros(41, n_t, K);                            % 粮食类 rate=0
veg = 17:37;
fungi = [38 39 40];
rate_p(veg, :, :)   = 0.05 + 0.01 * randn(numel(veg), n_t, K);     % 蔬菜 N(5%,1%)
rate_p(fungi, :, :) = -0.01 - 0.04 * rand(numel(fungi), n_t, K);   % 食用菌年降 U(1%,5%)
rate_p(41, :, :)    = -0.05;                                       % 羊肚菌固定 -5%
price_mult = cumprod(1 + rate_p, 2);
scen.price_w = param.price_i .* price_mult(oj, :, :);

% ---- P2-4 亩产量与灾害 ----
xi = -0.10 + 0.20 * rand(41, n_t, K);                  % 常规波动 U(-10%,10%) 按作物逐年
dis_trigger = rand(54, n_t, K) < param.p_disaster;     % 每地块每年独立触发
dis_trigger(35:end, :, :) = false;                     % 大棚不受灾（假设5）
theta = 0.30 + 0.10 * rand(54, n_t, K);                % 减产率每地块独立 U(30%,40%)（B5）
dis_loss = 1 - theta .* dis_trigger;
scen.yield_w = param.yield_i .* (1 + xi(oj, :, :)) .* dis_loss(oi, :, :);

scen.K = K;
end
