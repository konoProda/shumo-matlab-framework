function result_q3 = func_q3_item_milp(stats_q1, prod_info, PROJ_ROOT, save_figs, sat_lb)
% =========================================================================
% func_q3_item_milp.m — 问题3: 单品层面选品/补货/定价 MILP（建模文档第5节）
% C2(2026-08-14): 熵权法+TOPSIS 预筛选: 利润额/销售量/销售次数/打折次数/损耗率
%                 5指标评价, 取前33进入MILP; C1裁定: 保留价格离散寻优
% 方案b(2026-08-14 编程手裁定): sat_lb 为各品类需求满足率下限(基准A口径),
%                默认0=不加; >0 时加入约束 Σ_{i∈c} x_i ≥ sat_lb·D̄_c
% 决策变量(5.1): y_i 是否上架(binary); x_i 补货量(kg); p_i 售价(元/kg)
% 参数(5.2): w_i,ℓ_i,a_i,b_i,p^min/max,V,L=27,U=33,M
% 约束(5.3): 1 数量27~33; 2 最小陈列x≥2.5y; 3 需求上限x≤a+b*p;
%            4 价格区间; 5 空间Σs*x≤V; 6 离散关联(Σz=y, p=Σp^(k)z, x≤M*y)
% 目标(5.4): max Z = Σ_i (p_i - w_i*(1+ℓ_i)) * x_i
% Q5两阶段: 纯利润求解后检查各品类需求满足率, 低于警戒线(0.30)则打印警告
% 输入: stats_q1 / prod_info / PROJ_ROOT
% =========================================================================

OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
FIG_DIR = fullfile(PROJ_ROOT, 'figures');
if nargin < 4, save_figs = true; end               % 稳定性测试循环传 false 跳过绘图
if nargin < 5, sat_lb = 0.5; end                   % 方案b(2026-08-14裁定): 品类满足率下限=50%

%% 0. 参数 (与主程序一致)
CAND_START = datetime(2023, 6, 24);   CAND_END = datetime(2023, 6, 30);
W_MEAN_START = datetime(2023, 6, 24); W_MEAN_END = datetime(2023, 6, 30);
L_SHELF = 27;  U_SHELF = 33;  MIN_DISPLAY = 2.5;
V_QUANTILE = 0.95;  V_LOWER = L_SHELF * MIN_DISPLAY;
V_SENS_RATIOS = [0.8 0.9 1.0 1.1 1.2];
N_PRICE_LEVELS = 10;   BIG_M = 1000;   % 大M须大于最大可能需求(实测菠菜需求>100, 故取1000)
REGRESS_WINDOW = 30;
DEMAND_SAT_ALERT = 0.30;               % Q5: 品类需求满足率警戒线

%% 1. 候选单品: 2023-06-24~30 可售品种（题目要求）
dates = stats_q1.dates;
item_qty = stats_q1.item_qty;   item_price = stats_q1.item_price;
cand_mask = dates >= CAND_START & dates <= CAND_END;
cand_idx = find(sum(item_qty(:, cand_mask), 2) > 0);
n = numel(cand_idx);
assert(n >= L_SHELF, '[q3] 可售品种数 %d < 下界 %d, 请检查数据', n, L_SHELF);
prod_codes = prod_info.prod_code(cand_idx);

%% 2. 单品参数 (公式5.2)
% 批发价 w_i: 2023-06-24~30 均值
ws_cache = fullfile(OUT_DIR, 'wholesale_price.mat');
if exist(ws_cache, 'file')                        % 缓存加载(约1s, 见 func_preprocess)
    S = load(ws_cache, 'ws_tbl');
    ws = S.ws_tbl;
else
    opts_w = detectImportOptions(fullfile(OUT_DIR, 'wholesale_price.csv'), 'TextType', 'string');
    opts_w.VariableNames = {'prod_code', 'w_date', 'w_price'};
    opts_w.VariableTypes = {'string', 'string', 'double'};   % 强制字符串防15位编码失真
    ws = readtable(fullfile(OUT_DIR, 'wholesale_price.csv'), opts_w);
    ws.w_date = datetime(ws.w_date);
end
w_mask = ws.w_date >= W_MEAN_START & ws.w_date <= W_MEAN_END;
[~, iw] = ismember(ws.prod_code, prod_codes);
keep = w_mask & iw > 0;                       % 仅保留窗口内且属于候选单品的记录
w_cnt = accumarray(iw(keep), ones(sum(keep), 1), [n, 1]);
w_mean = accumarray(iw(keep), ws.w_price(keep), [n, 1]) ./ w_cnt;
w_mean(isnan(w_mean)) = 0;               % 无近周批发价 → 0 (利润为负, 自然不选)
loss_vec = prod_info.loss(cand_idx);     % 损耗率 ℓ_i

% 需求回归 a_i, b_i (Q6: 近期30天; 样本不足→品类系数兜底)
win_mask = dates >= CAND_END - caldays(REGRESS_WINDOW) & dates <= CAND_END;
a_vec = zeros(n, 1);   b_vec = zeros(n, 1);
% 品类系数兜底 (逐品类回归, 与 func_q2 同口径; g_cat 为 prod_info 行→组号映射)
[g_cat, cat_codes] = findgroups(prod_info.class_code);
n_cat = numel(cat_codes);
cat_coef = zeros(n_cat, 2);
for c = 1:n_cat
    cat_coef(c, :) = regr_coef(stats_q1.cat_price(c, :), stats_q1.cat_qty(c, :), win_mask);
end
g_i = g_cat(cand_idx);                   % 候选单品所属品类组号
for i = 1:n
    p = item_price(cand_idx(i), win_mask)';  q = item_qty(cand_idx(i), win_mask)';
    ok = ~isnan(p);
    if sum(ok) < 5                       % 样本不足 → 品类系数兜底(F1: 按历史份额缩放)
        ratio = mean(item_qty(cand_idx(i), win_mask)) / ...
                max(mean(stats_q1.cat_qty(g_i(i), win_mask)), eps);
        ratio = max(ratio, 1e-3);        % 防全零份额
        a_vec(i) = cat_coef(g_i(i), 2) * ratio;
        b_vec(i) = cat_coef(g_i(i), 1) * ratio;
    else
        coef = polyfit(p(ok), q(ok), 1);
        a_vec(i) = coef(2);  b_vec(i) = coef(1);
    end
end
% 价格区间 (F2: 取2023-06窗口, 无数据才回退全历史, 防止过时高价档)
jun_mask_p = month(dates) == 6 & year(dates) == 2023;
p_min_vec = min(item_price(cand_idx, jun_mask_p), [], 2, 'omitnan');
p_max_vec = max(item_price(cand_idx, jun_mask_p), [], 2, 'omitnan');
fb = isnan(p_min_vec) | isnan(p_max_vec);
p_min_vec(fb) = min(item_price(cand_idx(fb), :), [], 2, 'omitnan');
p_max_vec(fb) = max(item_price(cand_idx(fb), :), [], 2, 'omitnan');
p_min_vec(isnan(p_min_vec)) = 0;  p_max_vec(isnan(p_max_vec)) = 0;

%% 2.5 C2: 熵权TOPSIS 预筛选（5指标评价, 取前33进入MILP）
week_mask = dates >= CAND_START & dates <= CAND_END;
qty_wk = sum(item_qty(cand_idx, week_mask), 2);                        % 销售量(极大型)
profit_wk = sum((item_price(cand_idx, week_mask) - w_mean) .* ...
                item_qty(cand_idx, week_mask), 2, 'omitnan');          % 利润额(极大型)
ds_cache = fullfile(OUT_DIR, 'daily_sales.mat');
if exist(ds_cache, 'file')                                             % 缓存加载
    S = load(ds_cache, 'long_daily');
    ds = S.long_daily;
    ds.sale_date = datetime(ds.sale_date);                            % 缓存中为文本, 需转换
else
    opts_d = detectImportOptions(fullfile(OUT_DIR, 'daily_sales.csv'), 'TextType', 'string');
    opts_d.VariableNames = {'prod_code', 'sale_date', 'qty', 'revenue', 'avg_price', ...
                            'has_discount', 'n_trans', 'qty_am', 'qty_noon', 'qty_pm'};
    opts_d.VariableTypes = {'string', 'string', 'double', 'double', 'double', ...
                            'logical', 'double', 'double', 'double', 'double'};
    ds = readtable(fullfile(OUT_DIR, 'daily_sales.csv'), opts_d);
    ds.sale_date = datetime(ds.sale_date);
end
ds_wk = ds(ds.sale_date >= CAND_START & ds.sale_date <= CAND_END, :);
[~, iw3] = ismember(ds_wk.prod_code, prod_codes);
keep3 = iw3 > 0;
n_trans_i = accumarray(iw3(keep3), ds_wk.n_trans(keep3), [n, 1]);      % 销售次数(极大型)
n_disc_i = accumarray(iw3(keep3), double(ds_wk.has_discount(keep3)), [n, 1]);  % 打折次数(极小型)
X_ind = [profit_wk, qty_wk, n_trans_i, n_disc_i, loss_vec];            % 损耗率(极小型)
[topsis_score, topsis_w] = func_topsis(X_ind, [1 1 1 0 0]);
rank_tbl = table(prod_codes, prod_info.prod_name(cand_idx), topsis_score, ...
    'VariableNames', {'单品编码', '单品名称', 'TOPSIS得分'});
rank_tbl = sortrows(rank_tbl, 'TOPSIS得分', 'descend');
writetable(rank_tbl, fullfile(OUT_DIR, 'q3_topsis_scores.csv'), 'Encoding', 'UTF-8');
fprintf('[q3] TOPSIS 熵权=%s, 候选%d个, 取前%d进入MILP\n', ...
        mat2str(round(topsis_w, 3)), n, min(33, n));
% 预筛选池重组 (后续 MILP 均在池上进行)
[~, ord_s] = sort(topsis_score, 'descend');
keep_pool = ord_s(1:min(33, n));
n = numel(keep_pool);
prod_codes = prod_codes(keep_pool);
w_mean = w_mean(keep_pool);        loss_vec = loss_vec(keep_pool);
a_vec = a_vec(keep_pool);          b_vec = b_vec(keep_pool);
p_min_vec = p_min_vec(keep_pool);  p_max_vec = p_max_vec(keep_pool);
g_i = g_i(keep_pool);              cand_idx = cand_idx(keep_pool);

% 基准A需求 (各候选单品在2023-06历史实际售价下的需求, 用于方案b约束与Q5检查)
jun_mask = month(dates) == 6 & year(dates) == 2023;
P = stats_q1.item_price(cand_idx, jun_mask);
Q = stats_q1.item_qty(cand_idx, jun_mask);
p_bar = sum(P .* Q, 2, 'omitnan') ./ sum(Q, 2, 'omitnan');   % 销量加权均价 (n×1)
demand_bar = max(a_vec + b_vec .* p_bar, 0);                 % 历史实际售价下的需求 D̄_i
% F3(2026-08-14): 容量护栏 = 全期最大日销量×1.5 (市场容纳量思路)
cap_vec = max(item_qty(cand_idx, :), [], 2) * 1.5;

%% 3. 展示空间 V (Q3: 与问题2同口径)
q_total = sum(stats_q1.cat_qty, 1);
mm = month(dates);
V = max(V_LOWER, quantile(q_total(mm == 6 | mm == 7), V_QUANTILE));

%% 4. 构建 MILP (intlinprog)
% 变量排布: [y(1..n) | z(n*K) | x(1..n) | xk(n*K)]
% 约束: Σ_k z=y; x=Σ_k xk; xk≤D*z; x≥2.5y; x≤M*y; 27≤Σy≤33; Σx≤V
K = N_PRICE_LEVELS;
p_grid = zeros(n, K);
for i = 1:n
    p_grid(i, :) = linspace(p_min_vec(i), p_max_vec(i), K);
end
D_grid = max(a_vec + b_vec .* p_grid, 0);          % 各档需求 D_i(p^(k))
w_eff = w_mean .* (1 + loss_vec);                  % ŵ_i = w_i(1+ℓ_i) (公式5.4)
margin_k = p_grid - w_eff;                         % 各档单位利润

n_y = n;  n_z = n * K;  n_x = n;  n_xk = n * K;
n_var = n_y + n_z + n_x + n_xk;
c = [zeros(n_y, 1); zeros(n_z, 1); zeros(n_x, 1); -reshape(margin_k', [], 1)];  % min -利润
intcon = [1:n_y, n_y + (1:n_z)];                   % y, z 为二元

Aeq = zeros(2 * n, n_var);  beq = zeros(2 * n, 1);
Aineq = zeros(n_z + 2 * n + 3 + n_cat, n_var);  bineq = zeros(n_z + 2 * n + 3 + n_cat, 1);
row = 0;
for i = 1:n                                   % 离散关联 (公式5.3.6)
    zs = n_y + (i - 1) * K + (1:K);
    Aeq(2 * i - 1, [i, zs]) = [-1, ones(1, K)];        % Σ_k z_{i,k} - y_i = 0
    xks = n_y + n_z + n_x + (i - 1) * K + (1:K);
    Aeq(2 * i, [n_y + n_z + i, xks]) = [1, -ones(1, K)];   % x_i - Σ_k xk = 0
    for k = 1:K
        row = row + 1;
        Aineq(row, [zs(k), xks(k)]) = [-D_grid(i, k), 1];  % xk - D*z ≤ 0
    end
    row = row + 1;  Aineq(row, [i, n_y + n_z + i]) = [MIN_DISPLAY, -1];  % 2.5y - x ≤ 0
    row = row + 1;  Aineq(row, [i, n_y + n_z + i]) = [-BIG_M, 1];        % x - M*y ≤ 0
end
row = row + 1;  Aineq(row, 1:n_y) = 1;   bineq(row) = U_SHELF;   % Σy ≤ 33
row = row + 1;  Aineq(row, 1:n_y) = -1;  bineq(row) = -L_SHELF;  % Σy ≥ 27
row = row + 1;  Aineq(row, n_y + n_z + (1:n_x)) = 1;  bineq(row) = V;  % Σs_i*x_i ≤ V (s=1)
idx_space = row;                                    % 空间约束行号(敏感性分析用)
% 方案b(2026-08-14): 各品类需求满足率 ≥ sat_lb (基准A口径: Σ_{i∈c} x_i ≥ sat_lb·D̄_c)
if sat_lb > 0
    for cc = 1:n_cat                     % 注意: 循环变量不得与目标向量 c 重名
        row = row + 1;
        idx_in_c = find(g_i == cc);
        Aineq(row, n_y + n_z + idx_in_c) = -1;
        bineq(row) = -sat_lb * sum(demand_bar(idx_in_c));
    end
end
Aineq = Aineq(1:row, :);  bineq = bineq(1:row);
lb = zeros(n_var, 1);
ub = [ones(n_y + n_z, 1); cap_vec; inf(n_xk, 1)];    % F3: x 变量上界=容量护栏

%% 5. 求解
opts = optimoptions('intlinprog', 'Display', 'off');
[sol, fval, flag] = intlinprog(c, intcon, Aineq, bineq, Aeq, beq, lb, ub, opts);
assert(flag >= 1, '[q3] MILP 求解失败 (exitflag=%d), 请检查约束可行性', flag);
y_vec = sol(1:n_y);
z_mat = reshape(sol(n_y + (1:n_z)), K, n);
x_vec = sol(n_y + n_z + (1:n_x));
p_vec = sum(z_mat' .* p_grid, 2);                    % p_i = Σ_k p^(k) z (公式5.3.6)
profit_q3 = -fval;                                   % 目标 (公式5.4)
fprintf('[q3] 上架单品 %d 个, 总利润 %.2f 元, 空间占用 %.1f/%.1f kg\n', ...
        round(sum(y_vec)), profit_q3, sum(x_vec), V);

%% 6. Q5 两阶段检查: 品类需求满足率（基准A口径, demand_bar 已在 2.5 节计算）
sat_num = accumarray(g_i(y_vec > 0.5), x_vec(y_vec > 0.5), [n_cat, 1]);
sat_den = accumarray(g_i, demand_bar, [n_cat, 1]);
demand_sat = sat_num ./ sat_den;                     % 各品类需求满足率
demand_sat(sat_den == 0) = NaN;
fprintf('[q3] 品类需求满足率(基准A): %s\n', mat2str(round(demand_sat' * 100, 1)));
if sat_lb == 0 && min(demand_sat) < DEMAND_SAT_ALERT
    [min_sat, min_c] = min(demand_sat);
    name_i = find(g_cat == min_c, 1);
    fprintf('[q3][Q5][警告] 品类 %s 需求满足率 %.0f%% < 警戒线 %.0f%%: 纯利润方案结果极端, 请编程手裁定\n', ...
            prod_info.class_name(name_i), min_sat * 100, DEMAND_SAT_ALERT * 100);
end

%% 7. V 敏感性 (Q3: 0.8~1.2V 五点)
sens_V = zeros(numel(V_SENS_RATIOS), 1);
for r = 1:numel(V_SENS_RATIOS)
    bineq(idx_space) = V * V_SENS_RATIOS(r);         % 修改空间约束右端
    [~, fvalr, flagr] = intlinprog(c, intcon, Aineq, bineq, Aeq, beq, lb, ub, opts);
    if flagr >= 1
        sens_V(r) = -fvalr;
    else
        sens_V(r) = NaN;                             % 空间过小不可行
    end
end

%% 8. 输出: 补货定价表 + 图 (论文级)
sel = y_vec > 0.5;
unit_profit = sum(margin_k .* z_mat', 2);            % 所选档位单位利润 (公式5.4), n×1
out_tbl = table(prod_codes(sel), prod_info.prod_name(cand_idx(sel)), ...
                x_vec(sel), p_vec(sel), unit_profit(sel), ...
    'VariableNames', {'prod_code', 'prod_name', 'x_kg', 'p_yuan', 'unit_profit'});
out_tbl = sortrows(out_tbl, 'unit_profit', 'descend');

if save_figs
    % 仅展示前15名(其余14个单品利润极小, 全画会淹没细节); 标签旋转45°
    n_show = min(15, height(out_tbl));
    show = out_tbl(1:n_show, :);
    f = figure('Position', [100 100 860 440], 'Color', 'w');
    b = bar(categorical(show.prod_name), show.unit_profit .* show.x_kg);
    xtickangle(45);
    xlabel('单品(前15名)');  ylabel('单品利润(元)');
    title(sprintf('7月1日选品单品利润分布 (共%d个上架, 前15名)', height(out_tbl)));
    text(b(1).XEndPoints, b(1).YEndPoints, string(round(b(1).YData, 1)), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 7);
    exportgraphics(f, fullfile(FIG_DIR, 'q3_item_profit.png'), 'Resolution', 300);
    print(f, fullfile(FIG_DIR, 'q3_item_profit.eps'), '-depsc');
    close(f);
end

out_tbl.Properties.VariableNames = {'单品编码', '单品名称', '补货量kg', '售价元每kg', '单位利润'};
writetable(out_tbl, fullfile(OUT_DIR, 'q3_strategy_items.csv'), 'Encoding', 'UTF-8');

%% 9. 返回结构体
result_q3 = struct();
result_q3.y_vec = y_vec;   result_q3.x_vec = x_vec;   result_q3.p_vec = p_vec;
result_q3.profit_q3 = profit_q3;   result_q3.V = V;
result_q3.V_used = sum(x_vec);
result_q3.demand_sat = demand_sat;
result_q3.sens_V = sens_V;
result_q3.cand_codes = prod_codes;
result_q3.alert = min(demand_sat) < DEMAND_SAT_ALERT;
end

%% ================= 局部函数: 回归系数 (q = a + b*p, 返回 [b, a]) =================
function coefs = regr_coef(p, q, win_mask)
p = p(:);  q = q(:);  win_mask = win_mask(:);        % 统一为列向量, 避免广播歧义
ok = win_mask & ~isnan(p);
if sum(ok) < 5, ok = ~isnan(p); end                  % 样本不足 → 全历史
coefs = polyfit(p(ok), q(ok), 1);                    % coefs = [b, a]
end
