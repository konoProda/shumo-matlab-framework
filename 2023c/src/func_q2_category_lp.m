function result_q2 = func_q2_category_lp(stats_q1, prod_info, PROJ_ROOT, save_figs)
% =========================================================================
% func_q2_category_lp.m — 问题2: 品类层面补货与定价优化（建模文档第4节 + 二次优化裁定）
% B1(2026-08-14): 品类销量-定价关系用三次多项式拟合 S = f(P)（替代线性回归）
% B2(2026-08-14): 未来一周销售量 = 往年6-7月同星期均值预测
% B3(2026-08-14): 目标函数含打折回收项 max Σ x·(P·[(1-ℓ)+ℓ·d] - ŵ)
% B4(2026-08-14): 灵敏度分析 = 定价 ±5%/±10%
% A9(2026-08-14): 同比2020-2023年7月1-7日利润对比图
% 方案A(主模型): 成本加成定价 P=(1+η)w + LP(linprog) 分配补货量
% 方案B(对比):   价格离散K档 + MILP(intlinprog) 联合寻优
% 公式(4.2): ŵ = w(1+ℓ); 公式(4.4)含打折项见 B3
% =========================================================================

OUT_DIR = fullfile(PROJ_ROOT, 'outputs');
FIG_DIR = fullfile(PROJ_ROOT, 'figures');
if nargin < 4, save_figs = true; end               % 稳定性测试循环传 false 跳过绘图

%% 0. 参数 (与主程序保持一致)
FORECAST_START = datetime(2023, 7, 1);
HORIZON = 7;
N_PRICE_LEVELS = 10;                    % 方案B档数 K
P_SENS_RATIOS = [0.90 0.95 1.00 1.05 1.10];   % B4: 定价 ±5%/±10%
V_QUANTILE = 0.95;  V_LOWER = 27 * 2.5;       % Q3: V = max(67.5, 6-7月日总销量95%分位)
V_SENS_RATIOS = [0.8 0.9 1.0 1.1 1.2];

%% 1. 品类批发价日序列 + 打折日均价 (建模文档4.2)
ws_cache = fullfile(OUT_DIR, 'wholesale_price.mat');
if exist(ws_cache, 'file')                        % 缓存加载(约1s, 见 func_preprocess)
    S = load(ws_cache, 'ws_tbl');
    ws = S.ws_tbl;
else
    opts_w = detectImportOptions(fullfile(OUT_DIR, 'wholesale_price.csv'), 'TextType', 'string');
    opts_w.VariableNames = {'prod_code', 'w_date', 'w_price'};
    opts_w.VariableTypes = {'string', 'string', 'double'};
    ws = readtable(fullfile(OUT_DIR, 'wholesale_price.csv'), opts_w);
    ws.w_date = datetime(ws.w_date);
end
opts_c = detectImportOptions(fullfile(OUT_DIR, 'category_daily.csv'), 'TextType', 'string');
opts_c.VariableNames = {'class_code', 'sale_date', 'qty', 'revenue', 'avg_price', ...
                        'qty_am', 'qty_noon', 'qty_pm', 'disc_avg_price', ...
                        'loss_bar', 'weekday', 'is_weekend'};
opts_c.VariableTypes = {'string', 'string', 'double', 'double', 'double', ...
                        'double', 'double', 'double', 'double', 'double', ...
                        'string', 'logical'};
cat = readtable(fullfile(OUT_DIR, 'category_daily.csv'), opts_c);
cat.sale_date = datetime(cat.sale_date);

[g_cat, cat_codes] = findgroups(prod_info.class_code);
cat_codes = string(cat_codes);
[~, cn] = ismember(cat_codes, prod_info.class_code);
cat_names_q2 = prod_info.class_name(cn);
n_cat = numel(cat_codes);
dates = stats_q1.dates;                            % 日期网格 (1×T)
[~, iw_p] = ismember(ws.prod_code, prod_info.prod_code);
[~, iw_d] = ismember(ws.w_date, dates);
keep = iw_p > 0 & iw_d > 0;
g_w = g_cat(iw_p(keep));  gd_w = iw_d(keep);
q_ik = stats_q1.item_qty(sub2ind(size(stats_q1.item_qty), iw_p(keep), gd_w));
w_num = accumarray([g_w, gd_w], ws.w_price(keep) .* q_ik, [n_cat, numel(dates)]);
w_den = accumarray([g_w, gd_w], q_ik, [n_cat, numel(dates)]);
w_cat = w_num ./ w_den;                            % 加权均价; 无销量日 → NaN
[g2, ~] = findgroups(prod_info.class_code);
loss_bar_c = splitapply(@mean, prod_info.loss, g2);

%% 2. B1 三次多项式拟合: S = f(P)（6-7月品类日数据）
jj_mask = ismember(month(dates), [6, 7]);
coef3 = zeros(n_cat, 4);                           % [c3 c2 c1 c0]: S = c0+c1P+c2P²+c3P³
r2_c = zeros(n_cat, 1);
for c = 1:n_cat
    p = stats_q1.cat_price(c, jj_mask)';  q = stats_q1.cat_qty(c, jj_mask)';
    ok = ~isnan(p);
    coef3(c, :) = polyfit(p(ok), q(ok), 3);
    q_hat = polyval(coef3(c, :), p(ok));
    r2_c(c) = 1 - sum((q(ok) - q_hat).^2) / sum((q(ok) - mean(q(ok))).^2);
end
fprintf('[q2] 三次多项式拟合 R2: %s\n', mat2str(round(r2_c', 2)));

%% 3. B2 未来一周销售量预测 (往年6-7月同星期均值)
fcast_dates = FORECAST_START + caldays(0:HORIZON-1);
B_ct = zeros(n_cat, HORIZON);
for t = 1:HORIZON
    wd_mask = weekday(dates) == weekday(fcast_dates(t)) & jj_mask;
    B_ct(:, t) = mean(stats_q1.cat_qty(:, wd_mask), 2);
end

%% 4. 未来一周批发价 (Q2②同星期对齐) + 打折数 d_c (B3)
w_ct = zeros(n_cat, HORIZON);
for t = 1:HORIZON
    wd_mask = weekday(dates) == weekday(fcast_dates(t));
    w_ct(:, t) = mean(w_cat(:, wd_mask), 2, 'omitnan');
end
d_c = zeros(n_cat, 1);
for c = 1:n_cat
    ratio = cat.disc_avg_price(cat.class_code == cat_codes(c) & ismember(cat.sale_date, dates(jj_mask))) ./ ...
            cat.avg_price(cat.class_code == cat_codes(c) & ismember(cat.sale_date, dates(jj_mask)));
    d_c(c) = mean(ratio, 'omitnan');
end
d_c(~isfinite(d_c)) = 1;                           % 无打折记录 → 折扣数=1(不打折)

%% 5. 价格区间与加成率
p_min_c = min(stats_q1.cat_price, [], 2, 'omitnan');
p_max_c = max(stats_q1.cat_price, [], 2, 'omitnan');
p_win = stats_q1.cat_price(:, jj_mask);
w_hist = w_cat(:, jj_mask);
markup_c = mean((p_win - w_hist) ./ w_hist, 2, 'omitnan');
markup_c(~isfinite(markup_c)) = 0;

%% 6. 展示空间 V (Q3: 历史6-7月日总销量95%分位, 下限67.5)
q_total = sum(stats_q1.cat_qty, 1);
V = max(V_LOWER, quantile(q_total(jj_mask), V_QUANTILE));

%% 7. 方案A (主模型): P=(1+η)w 截断 → LP 分配补货量
w_eff_ct = w_ct .* (1 + loss_bar_c);               % 有效成本 (公式4.2)
p_ct_A = min(max((1 + markup_c) .* w_ct, p_min_c), p_max_c);
% 有效回收价 = P·[(1-ℓ)+ℓ·d] (B3: 正常部分+打折回收部分)
recov_A = p_ct_A .* ((1 - loss_bar_c) + loss_bar_c .* d_c);
margin_A = recov_A - w_eff_ct;
x_ub_A = B_ct ./ (1 - loss_bar_c);                 % 损耗约束 x(1-ℓ)≥B → 上界 B/(1-ℓ)
x_ct_A = zeros(size(p_ct_A));
for t = 1:HORIZON
    m = margin_A(:, t);
    if all(m <= 0), continue; end
    [x, ~, flag] = linprog(-m, ones(1, n_cat), V, [], [], zeros(n_cat, 1), x_ub_A(:, t));
    if flag >= 1, x_ct_A(:, t) = x; end
end
profit_A = sum(sum(margin_A .* x_ct_A));           % 目标 (公式4.4+B3)

%% 8. 方案B (对比): 价格离散K档 MILP, 需求=三次多项式值
p_grid = zeros(n_cat, N_PRICE_LEVELS);
for c = 1:n_cat
    p_grid(c, :) = linspace(p_min_c(c), p_max_c(c), N_PRICE_LEVELS);
end
S_grid = zeros(n_cat, N_PRICE_LEVELS);
for c = 1:n_cat
    S_grid(c, :) = max(polyval(coef3(c, :), p_grid(c, :)), 0);   % 各档需求 S_k=f_c(P_k)
end
recov_B = p_grid .* ((1 - loss_bar_c) + loss_bar_c .* d_c);   % (n×K, 与日无关)
x_ct_B = zeros(size(p_ct_A));  p_ct_B = zeros(size(p_ct_A));
profit_B = 0;  profit_day_B = zeros(1, HORIZON);
for t = 1:HORIZON
    margin_Bt = recov_B - w_eff_ct(:, t);          % 逐日有效成本 (n×K)
    [x_row, p_row, prof_t] = solve_milp_day(p_grid, S_grid, margin_Bt, V);
    x_ct_B(:, t) = x_row(:);
    p_ct_B(:, t) = p_row(:);
    profit_B = profit_B + prof_t;
    profit_day_B(t) = prof_t;
end

%% 9. A9 同比 2020-2023 年 7月1-7日利润 (方案A口径)
years = [2020 2021 2022 2023];
yoy_profit = zeros(7, numel(years));
for yi = 1:numel(years)
    yr = years(yi);
    if yr == 2023
        B_y = B_ct;  w_y = w_ct;                   % 预测年
    else
        hist_mask = year(dates) == yr & jj_mask;   % 该年6-7月
        B_y = zeros(n_cat, 7);  w_y = zeros(n_cat, 7);
        for t = 1:7
            wd_mask = weekday(dates) == weekday(fcast_dates(t)) & hist_mask;
            B_y(:, t) = mean(stats_q1.cat_qty(:, wd_mask), 2);
            w_y(:, t) = mean(w_cat(:, wd_mask), 2, 'omitnan');
        end
    end
    p_y = min(max((1 + markup_c) .* w_y, p_min_c), p_max_c);
    m_y = p_y .* ((1 - loss_bar_c) + loss_bar_c .* d_c) - w_y .* (1 + loss_bar_c);
    xb_y = B_y ./ (1 - loss_bar_c);
    x_y = zeros(n_cat, 7);
    for t = 1:7
        if all(m_y(:, t) <= 0), continue; end
        [x, ~, flag] = linprog(-m_y(:, t), ones(1, n_cat), V, [], [], ...
                               zeros(n_cat, 1), xb_y(:, t));
        if flag >= 1, x_y(:, t) = x; end
    end
    yoy_profit(:, yi) = sum(m_y .* x_y, 1);
end

%% 10. B4 定价灵敏度 (±5%/±10%) 与 Q3 空间灵敏度 (0.8~1.2V)
sens_P = zeros(numel(P_SENS_RATIOS), 1);
for r = 1:numel(P_SENS_RATIOS)
    pv = min(max(p_ct_A * P_SENS_RATIOS(r), p_min_c), p_max_c);
    mv = pv .* ((1 - loss_bar_c) + loss_bar_c .* d_c) - w_eff_ct;
    xv = zeros(size(pv));
    for t = 1:HORIZON
        if all(mv(:, t) <= 0), continue; end
        [x, ~, flag] = linprog(-mv(:, t), ones(1, n_cat), V, [], [], ...
                               zeros(n_cat, 1), x_ub_A(:, t));
        if flag >= 1, xv(:, t) = x; end
    end
    sens_P(r) = sum(sum(mv .* xv));
end
sens_V = zeros(numel(V_SENS_RATIOS), 1);
for r = 1:numel(V_SENS_RATIOS)
    Vr = V * V_SENS_RATIOS(r);
    xv = zeros(size(p_ct_A));
    for t = 1:HORIZON
        if all(margin_A(:, t) <= 0), continue; end
        [x, ~, flag] = linprog(-margin_A(:, t), ones(1, n_cat), Vr, [], [], ...
                               zeros(n_cat, 1), x_ub_A(:, t));
        if flag >= 1, xv(:, t) = x; end
    end
    sens_V(r) = sum(sum(margin_A .* xv));
end

%% 11. 输出: 结果表 + 敏感性表 (表格优先呈现)
day_labels = string(FORECAST_START + caldays(0:HORIZON-1), 'MM-dd');
day_labels = day_labels(:);
x_names = strcat('x_', cat_names_q2);
p_names = strcat('p_', cat_names_q2);
b_names = strcat('B_', cat_names_q2);              % 预测销售量列
res_tbl = [table(day_labels, 'VariableNames', "date"), ...
           array2table(x_ct_A', 'VariableNames', x_names), ...
           array2table(p_ct_A', 'VariableNames', p_names), ...
           array2table(B_ct', 'VariableNames', b_names)];
writetable(res_tbl, fullfile(OUT_DIR, 'q2_strategy_A.csv'), 'Encoding', 'UTF-8');
res_tbl_B = [table(day_labels, 'VariableNames', "date"), ...
             array2table(x_ct_B', 'VariableNames', x_names), ...
             array2table(p_ct_B', 'VariableNames', p_names)];
writetable(res_tbl_B, fullfile(OUT_DIR, 'q2_strategy_B.csv'), 'Encoding', 'UTF-8');
sens_tbl = table(string(round(P_SENS_RATIOS' * 100)) + "%", sens_P / 1000, ...
    'VariableNames', {'定价相对基准', '7天总利润千元'});
writetable(sens_tbl, fullfile(OUT_DIR, 'q2_sens_price.csv'), 'Encoding', 'UTF-8');
fprintf('[q2] 方案A(主模型)利润=%.2f元, 方案B(对比)利润=%.2f元, V=%.1fkg, 7天预测销量=%.0fkg\n', ...
        profit_A, profit_B, V, sum(B_ct, 'all'));

%% 12. 图表 (save_figs 控制)
if save_figs
    % 三次拟合曲线 (6品类散点+拟合曲线)
    f = figure('Position', [100 100 960 640], 'Color', 'w');
    for c = 1:n_cat
        subplot(2, 3, c);
        p = stats_q1.cat_price(c, jj_mask);  q = stats_q1.cat_qty(c, jj_mask);
        ok = ~isnan(p);
        scatter(p(ok), q(ok), 6, '.');
        hold on;
        px = linspace(min(p(ok)), max(p(ok)), 100);
        plot(px, polyval(coef3(c, :), px), 'r-', 'LineWidth', 1.5);
        hold off;
        xlabel('销售单价(元/kg)');  ylabel('销售量(kg)');
        title(sprintf('%s (R^2=%.2f)', cat_names_q2(c), r2_c(c)));
    end
    sgtitle('图10 各品类销售量与成本加成定价三次多项式拟合');
    exportgraphics(f, fullfile(FIG_DIR, 'q2_fit_cubic.png'), 'Resolution', 300);
    print(f, fullfile(FIG_DIR, 'q2_fit_cubic.eps'), '-depsc');
    close(f);

    % 方案A/B 日利润对比 (本环境bar: 行=组 → 7×2)
    f = figure('Position', [100 100 760 440], 'Color', 'w');
    profit_day = [sum(margin_A .* x_ct_A, 1); profit_day_B];
    b = bar(profit_day');
    xticks(1:HORIZON);  xticklabels(day_labels);
    legend({'方案A(主模型)', '方案B(对比)'}, 'Location', 'northwest');
    xlabel('日期');  ylabel('日利润(元)');  title('图11 方案A/B 日利润对比');
    ylim([0, max(profit_day, [], 'all') * 1.2]);
    for k = 1:numel(b)
        text(b(k).XEndPoints, b(k).YEndPoints, string(round(b(k).YData)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
    end
    exportgraphics(f, fullfile(FIG_DIR, 'q2_profit_compare.png'), 'Resolution', 300);
    print(f, fullfile(FIG_DIR, 'q2_profit_compare.eps'), '-depsc');
    close(f);

    % A9 同比利润对比 (7天×4年 分组柱状图)
    f = figure('Position', [100 100 820 440], 'Color', 'w');
    bar(yoy_profit);
    xticks(1:7);  xticklabels(day_labels);
    legend({'2020年', '2021年', '2022年', '2023年(预测)'}, 'Location', 'northwest');
    xlabel('日期');  ylabel('日利润(元)');
    title('图12 7月1-7日单日利润同比对比 (方案A口径)');
    exportgraphics(f, fullfile(FIG_DIR, 'q2_yoy_profit.png'), 'Resolution', 300);
    print(f, fullfile(FIG_DIR, 'q2_yoy_profit.eps'), '-depsc');
    close(f);
end

%% 13. 返回结构体
result_q2 = struct();
result_q2.x_ct_A = x_ct_A;    result_q2.p_ct_A = p_ct_A;    result_q2.profit_A = profit_A;
result_q2.x_ct_B = x_ct_B;    result_q2.p_ct_B = p_ct_B;    result_q2.profit_B = profit_B;
result_q2.w_ct = w_ct;        result_q2.markup_c = markup_c;
result_q2.B_ct = B_ct;        result_q2.d_c = d_c;
result_q2.coef3 = coef3;      result_q2.r2_c = r2_c;
result_q2.loss_bar_c = loss_bar_c;   result_q2.V = V;
result_q2.sens_P = sens_P;    result_q2.sens_V = sens_V;
result_q2.yoy_profit = yoy_profit;
result_q2.cat_codes = cat_codes;
end

%% ================= 局部函数: 方案B单日MILP (公式4.5-B, 需求=三次多项式) =================
function [x_day, p_day, profit_day] = solve_milp_day(p_grid, S_grid, margin_B, V)
% 决策: z_{c,k} 二元选价; x_{c,k} 连续补货量(受所选档位需求 S_k 约束)
% 目标: max Σ margin_k · x_{c,k};  约束: Σ_k z=1, x_{c,k}≤S_k·z, ΣΣx≤V
% 返回: x_day/p_day 为 1×nC 行向量(调用方转列); profit_day 为当日利润
nC = size(p_grid, 1);  K = size(p_grid, 2);
nz = nC * K;
c_obj = [zeros(nz, 1); -reshape(margin_B', [], 1)];     % min 形式取负
intcon = 1:nz;
Aineq = zeros(nz + 1, nz + nz);   bineq = zeros(nz + 1, 1);
for c = 1:nC
    for k = 1:K
        row = (c - 1) * K + k;
        Aineq(row, row) = -S_grid(c, k);    % x_{c,k} - S_k·z_{c,k} ≤ 0
        Aineq(row, nz + row) = 1;
    end
end
Aineq(nz + 1, nz + 1:end) = 1;   bineq(nz + 1) = V;            % 空间约束 ΣΣx ≤ V
Aeq = zeros(nC, nz + nz);        beq = ones(nC, 1);
for c = 1:nC
    Aeq(c, (c - 1) * K + (1:K)) = 1;                            % Σ_k z_{c,k} = 1
end
lb = zeros(nz + nz, 1);          ub = [ones(nz, 1); inf(nz, 1)];
opts = optimoptions('intlinprog', 'Display', 'off');
[sol, ~, flag] = intlinprog(c_obj, intcon, Aineq, bineq, Aeq, beq, lb, ub, opts);
if flag < 1
    x_day = zeros(1, nC);  p_day = zeros(1, nC);  profit_day = 0;
    return;
end
z = reshape(sol(1:nz), K, nC);
x_day = sum(reshape(sol(nz + 1:end), K, nC), 1);        % x_c = Σ_k x_{c,k}
p_day = sum(z .* p_grid', 1);                           % p_c = Σ_k p^(k) z_{c,k}
profit_day = margin_B(:)' * sol(nz + 1:end);            % 日利润 = Σ margin·x_k
end
