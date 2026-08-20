function sol = func_q2_saa(param, scen, u_q1, alpha, lambda, mode, ext)
% func_q2_saa —— 问题2 SAA-CVaR 两阶段随机规划装配与求解（映射表 Q2）
% 输入: param / scen（func_gen_scenarios 输出）
%       u_q1  Nx7 问题1的0-1种植拓扑（第一阶段沿用）
%       alpha CVaR置信度（0.95）；lambda 风险厌恶系数
%       mode  'lp_fixed' 拓扑固定法->纯LP（主路径）| 'milp_full' u自由二值（尝试，宜K<=30）
%       ext   可选，Q3 拓展结构（ext.rho_sp/ext.clusters/ext.phi）：启用替代需求转移
%             与互补成本折减（C3-1~C3-4）
% 输出: sol.x  Nx7 第一阶段种植面积
%       sol.profit_scen  7xK 情景净利润 Pi_t(w)；sol.profit_total_vec 1xK 总利润情景分布
%       sol.profit_mean_total 期望总利润；sol.profit_std_total 总利润情景标准差
%       sol.cvar_by_year  7x1；sol.eta / sol.v_tail；sol.exit_flag；sol.omega_list
%       sol.scen  透传情景（供 Q3 统计复用）

K = scen.K;
N = numel(param.yield_i);
n_t = 7;
N7 = N * n_t;
N7K = N7 * K;
oi = param.omega_list(:, 1);  oj = param.omega_list(:, 2);  os = param.omega_list(:, 3);
Ai = param.plot_area(oi);
delta = param.delta_min;

% ---- Q3 拓展：前茬豆类指示 b_prev（B6 时间相邻上一季，u 固定时为常数） ----
has_s2 = (oi >= 27);                       % 水浇地/大棚存在第二季
omega_lin = zeros(54, 41, 2);
omega_lin(sub2ind([54 41 2], oi, oj, os)) = 1:N;
p23 = param.planted_2023;
b_prev = zeros(N, n_t);
for idx = 1:N
    for t = 1:n_t
        if os(idx) == 2
            sp = 1;  tp = t;               % 前茬 = 同年第一季
        elseif has_s2(idx)
            sp = 2;  tp = t - 1;           % 前茬 = 上年第二季（t=1 时取 2023）
        else
            sp = 1;  tp = t - 1;           % 单季地块：前茬 = 上年第一季
        end
        if tp == 0
            b_prev(idx, t) = any(p23(oi(idx), [1 2 3 4 5 17 18 19], sp), 'all');
        else
            rows = omega_lin(oi(idx), [1 2 3 4 5 17 18 19], sp);
            rows = rows(rows > 0);
            b_prev(idx, t) = any(u_q1(rows, tp) > 0.5);
        end
    end
end
if nargin >= 7 && ~isempty(ext)
    cost_eff = scen.cost_w .* (1 - (1 - ext.phi) * b_prev);   % C3-3 互补折减
    ext_mode = true;
else
    cost_eff = scen.cost_w;
    ext_mode = false;
end

% ---- 变量分块：x | u | qn | qd | eta | v ----
off_u = N7;  off_qn = 2 * N7;  off_qd = 2 * N7 + N7K;
off_eta = 2 * N7 + 2 * N7K;  off_v = off_eta + 7;
n_var = off_v + 7 * K;
xidx  = @(idx, t) (t - 1) * N + idx;
uidx  = @(idx, t) off_u + (t - 1) * N + idx;
qnidx = @(idx, t, w) off_qn + (w - 1) * N7 + (t - 1) * N + idx;
qdidx = @(idx, t, w) off_qd + (w - 1) * N7 + (t - 1) * N + idx;
etaidx = @(t) off_eta + t;
vidx = @(t, w) off_v + (t - 1) * K + w;

% ---- 目标 min -[期望利润 - lambda*CVaR] ----
f = zeros(n_var, 1);
f(1:N7) = reshape(sum(cost_eff, 3) / K, [], 1);             % x: +C/K（期望成本，Q3 含折减）
f(off_qn + 1:off_qd) = -scen.price_w(:) / K;                % qn: -P/K
f(off_qd + 1:off_eta) = -0.5 * scen.price_w(:) / K;         % qd: -0.5P/K
f(off_eta + 1:off_v) = lambda;                              % eta: +lambda
f(off_v + 1:end) = lambda * (1 / ((1 - alpha) * K));        % v: +lambda/((1-a)K)

% ---- 预分组 ----
idx_is = cell(54, 2);
for i = 1:54
    idx_is{i, 1} = find(oi == i & os == 1);
    idx_is{i, 2} = find(oi == i & os == 2);
end
idx_js = cell(41, 2);
for j = 1:41
    idx_js{j, 1} = find(oj == j & os == 1);
    idx_js{j, 2} = find(oj == j & os == 2);
end
allidx = (1:N)';

% ---- 约束稀疏装配 ----
Ic = {};  Jc = {};  Vc = {};  bc = {};  n_row = 0;

% C1-4 面积上限: sum_j x <= A_i
for t = 1:n_t
    for i = 1:54
        for s = 1:2
            ids = idx_is{i, s};
            if isempty(ids), continue; end
            Ic{end+1, 1} = xidx(ids, t);  Jc{end+1, 1} = n_row + 1 + zeros(numel(ids), 1);
            Vc{end+1, 1} = ones(numel(ids), 1);  bc{end+1, 1} = Ai(ids(1));
            n_row = n_row + 1;
        end
    end
end

% C1-5 最小比例与种植开关: delta*A*u <= x <= A*u（每 idx 独立一行）
for t = 1:n_t
    Ic{end+1, 1} = [xidx(allidx, t); uidx(allidx, t)];
    Jc{end+1, 1} = n_row + [allidx; allidx];
    Vc{end+1, 1} = [-ones(N, 1); delta * Ai];  bc{end+1, 1} = zeros(N, 1);
    n_row = n_row + N;
    Ic{end+1, 1} = [xidx(allidx, t); uidx(allidx, t)];
    Jc{end+1, 1} = n_row + [allidx; allidx];
    Vc{end+1, 1} = [ones(N, 1); -Ai];  bc{end+1, 1} = zeros(N, 1);
    n_row = n_row + N;
end

% C1-6a 连作（跨年同季，含 2023 常数）
for idx = 1:N
    rhs = 1 - planted_2023_aux(param, idx);
    Ic{end+1, 1} = uidx(idx, 1);  Jc{end+1, 1} = n_row + 1;  Vc{end+1, 1} = 1;  bc{end+1, 1} = rhs;
    n_row = n_row + 1;
end
for t = 2:n_t
    Ic{end+1, 1} = [uidx(allidx, t); uidx(allidx, t - 1)];
    Jc{end+1, 1} = n_row + [allidx; allidx];
    Vc{end+1, 1} = ones(2 * N, 1);  bc{end+1, 1} = ones(N, 1);
    n_row = n_row + N;
end

% C1-6b 连作（年内跨季，实质智慧大棚）
for t = 1:n_t
    for i = 27:54
        ids1 = idx_is{i, 1};  ids2 = idx_is{i, 2};
        [is_m, loc] = ismember(oj(ids1), oj(ids2));
        pairs = find(is_m);
        if isempty(pairs), continue; end
        np = numel(pairs);
        Ic{end+1, 1} = [uidx(ids1(pairs), t); uidx(ids2(loc(pairs)), t)];
        Jc{end+1, 1} = n_row + [(1:np)'; (1:np)'];
        Vc{end+1, 1} = ones(2 * np, 1);  bc{end+1, 1} = ones(np, 1);
        n_row = n_row + np;
    end
end

% C1-6c 连作（智慧大棚跨年跨季）
for i = 51:54
    ids1 = idx_is{i, 1};
    for k = 1:numel(ids1)
        rhs = 1 - planted_2023_aux2(param, i, oj(ids1(k)));
        Ic{end+1, 1} = uidx(ids1(k), 1);  Jc{end+1, 1} = n_row + 1;  Vc{end+1, 1} = 1;  bc{end+1, 1} = rhs;
        n_row = n_row + 1;
    end
    ids2 = idx_is{i, 2};
    [is_m, loc] = ismember(oj(ids1), oj(ids2));
    pairs = find(is_m);
    for t = 2:n_t
        np = numel(pairs);
        if np == 0, continue; end
        Ic{end+1, 1} = [uidx(ids1(pairs), t); uidx(ids2(loc(pairs)), t - 1)];
        Jc{end+1, 1} = n_row + [(1:np)'; (1:np)'];
        Vc{end+1, 1} = ones(2 * np, 1);  bc{end+1, 1} = ones(np, 1);
        n_row = n_row + np;
    end
end

% C1-7 豆类轮作（B1 修正：窗口 t-2..t，t in {2025..2030}）
bean = [1 2 3 4 5 17 18 19];
bean_2023_aux = param.bean_2023;   % 54x1（主程序注入：各2023年是否种过豆类）
for i = 1:54
    ids_i = find(oi == i & ismember(oj, bean));
    if isempty(ids_i), continue; end
    for tt = 2:n_t
        rhs = 1 - (tt == 2) * bean_2023_aux(i);
        if rhs <= 0, continue; end
        tau_all = max(1, tt - 2):tt;
        n_col = numel(tau_all);
        Ic{end+1, 1} = reshape(uidx(ids_i, tau_all), [], 1);
        Jc{end+1, 1} = n_row + 1 + zeros(numel(ids_i) * n_col, 1);
        Vc{end+1, 1} = ones(numel(ids_i) * n_col, 1);  bc{end+1, 1} = rhs;
        n_row = n_row + 1;
    end
end

% C1-8 集中度
for t = 1:n_t
    for j = 1:41
        for s = 1:2
            ids = idx_js{j, s};
            if isempty(ids), continue; end
            Ic{end+1, 1} = uidx(ids, t);  Jc{end+1, 1} = n_row + 1 + zeros(numel(ids), 1);
            Vc{end+1, 1} = ones(numel(ids), 1);  bc{end+1, 1} = param.n_plot_max(j);
            n_row = n_row + 1;
        end
    end
end

% C1-2' 情景需求上限: sum_i qn <= D_{j,s,t}(w)（Q3 拓展时为替代转移上限 C3-2）
for w = 1:K
    for t = 1:n_t
        for j = 1:41
            for s = 1:2
                ids = idx_js{j, s};
                if isempty(ids), continue; end
                if ext_mode
                    % C3-2 直接线性化: sum_i qn_j + sum_{m in Sub(j)} theta*sum_i qn_m
                    %               <= D_j + sum_m theta*D_m（theta=|rho|）
                    has_rows = ~cellfun(@isempty, idx_js(:, s));   % 41x1 该季有行
                    rho_col = ext.rho_sp(j, :)';
                    sub_list = find(ext.clusters == ext.clusters(j) & has_rows ...
                                    & rho_col <= -0.4 & isfinite(rho_col) ...
                                    & (1:41)' ~= j);
                    Ic{end+1, 1} = qnidx(ids, t, w);
                    Jc{end+1, 1} = n_row + 1 + zeros(numel(ids), 1);
                    Vc{end+1, 1} = ones(numel(ids), 1);
                    rhs_val = scen.demand_w(j, s, t, w);
                    if ~isempty(sub_list)
                        % 向量化拼接替代作物的 qn 项（避免逐作物取 cell）
                        sub_cells = idx_js(sub_list, s);
                        lens = cellfun(@numel, sub_cells);
                        all_ids = cell2mat(sub_cells);
                        theta_vec = abs(ext.rho_sp(j, sub_list));
                        all_theta = repelem(theta_vec, lens);
                        Ic{end+1, 1} = [Ic{end, 1}; qnidx(all_ids, t, w)];
                        Jc{end+1, 1} = [Jc{end, 1}; n_row + 1 + zeros(numel(all_ids), 1)];
                        Vc{end+1, 1} = [Vc{end, 1}; all_theta(:)];
                        rhs_val = rhs_val + sum(theta_vec .* reshape(scen.demand_w(sub_list, s, t, w), [], 1));
                    end
                    bc{end+1, 1} = rhs_val;
                else
                    Ic{end+1, 1} = qnidx(ids, t, w);  Jc{end+1, 1} = n_row + 1 + zeros(numel(ids), 1);
                    Vc{end+1, 1} = ones(numel(ids), 1);  bc{end+1, 1} = scen.demand_w(j, s, t, w);
                end
                n_row = n_row + 1;
            end
        end
    end
end

% C1-3' 情景产销: qn+qd <= Y_{i,j,s,t}(w)*x（每 idx 独立一行）
for w = 1:K
    for t = 1:n_t
        Ic{end+1, 1} = [qnidx(allidx, t, w); qdidx(allidx, t, w); xidx(allidx, t)];
        Jc{end+1, 1} = n_row + [allidx; allidx; allidx];
        Vc{end+1, 1} = [ones(N, 1); ones(N, 1); -scen.yield_w(:, t, w)];
        bc{end+1, 1} = zeros(N, 1);
        n_row = n_row + N;
    end
end

% CVaR 线性化: -v -eta + sum[P*qn + 0.5P*qd - C*x] <= 0（每 (t,w) 一行）
for w = 1:K
    for t = 1:n_t
        Ic{end+1, 1} = [vidx(t, w); etaidx(t); qnidx(allidx, t, w); qdidx(allidx, t, w); xidx(allidx, t)];
        Jc{end+1, 1} = n_row + 1 + ones(3 * N + 2, 1);
        Vc{end+1, 1} = [-1; -1; -scen.price_w(:, t, w); -0.5 * scen.price_w(:, t, w); cost_eff(:, t, w)];
        bc{end+1, 1} = 0;
        n_row = n_row + 1;
    end
end

jc_all = vertcat(Jc{:});
row_max = max(jc_all);  col_max = max(vertcat(Ic{:}));  col_min = min(vertcat(Ic{:}));
assert(col_max <= n_var && col_min >= 1, '装配越界: 列索引[%d..%d]/%d', col_min, col_max, n_var);
% 按实际行号装配：行号有缝隙也不影响正确性；冲突行号会被捕获
A = sparse(jc_all, vertcat(Ic{:}), vertcat(Vc{:}), row_max, n_var);
b = zeros(row_max, 1);
for k = 1:numel(Jc)
    rk = unique(Jc{k});
    if any(b(rk) ~= 0)
        error('约束行号冲突: 追加#%d 与已有行重叠', k);
    end
    b(rk) = bc{k};
end

% ---- 边界与求解 ----
lb = zeros(n_var, 1);
ub = inf(n_var, 1);
if strcmp(mode, 'debug')
    sol.A = A;  sol.b = b;  sol.f = f;  sol.lb = lb;  sol.ub = ub;
    sol.n_var = n_var;
    sol.offs = struct('x', 0, 'u', off_u, 'qn', off_qn, 'qd', off_qd, 'eta', off_eta, 'v', off_v);
    return;
end
lb(off_eta + 1:off_v) = -inf;          % eta 自由
if strcmp(mode, 'lp_fixed')
    lb(off_u + 1:off_qn) = u_q1(:);    % 拓扑固定
    ub(off_u + 1:off_qn) = u_q1(:);
    opts = optimoptions('linprog', 'Display', 'off');
    [v, ~, exit_flag] = linprog(f, A, b, [], [], lb, ub, opts);
    intcon = [];
else
    ub(off_u + 1:off_qn) = 1;          % u 自由二值
    opts = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 900);
    [v, ~, exit_flag] = intlinprog(f, (off_u + 1:off_qn)', A, b, [], [], lb, ub, opts);
    intcon = (off_u + 1:off_qn)';
end
if exit_flag < 1
    warning('Q2 求解器返回 exit_flag=%d', exit_flag);
end

% ---- 拆解与统计 ----
x_mat = reshape(v(1:N7), N, n_t);
u_mat = round(reshape(v(off_u + 1:off_qn), N, n_t));
qn_w = reshape(v(off_qn + 1:off_qd), N, n_t, K);
qd_w = reshape(v(off_qd + 1:off_eta), N, n_t, K);
eta_v = v(off_eta + 1:off_v);
v_tail = reshape(v(off_v + 1:end), n_t, K);
profit_scen = zeros(n_t, K);
revenue_scen = zeros(n_t, K);
cost_scen = zeros(n_t, K);
for w = 1:K
    for t = 1:n_t
        revenue_scen(t, w) = sum(scen.price_w(:, t, w) .* qn_w(:, t, w) ...
                              + 0.5 * scen.price_w(:, t, w) .* qd_w(:, t, w));
        cost_scen(t, w) = sum(cost_eff(:, t, w) .* x_mat(:, t));
        profit_scen(t, w) = revenue_scen(t, w) - cost_scen(t, w);
    end
end
profit_total_vec = sum(profit_scen, 1);                       % 1xK 总利润情景分布
cvar_by_year = eta_v + (1 / ((1 - alpha) * K)) * sum(v_tail, 2);
sol.scen = scen;

sol.x = x_mat;  sol.u = u_mat;  sol.intcon_used = intcon;
sol.profit_scen = profit_scen;
sol.revenue_scen = revenue_scen;  sol.cost_scen = cost_scen;
sol.profit_total_vec = profit_total_vec;
sol.profit_mean_total = mean(profit_total_vec);
sol.profit_std_total = std(profit_total_vec);
sol.cvar_by_year = cvar_by_year;
sol.eta = eta_v;  sol.v_tail = v_tail;
sol.exit_flag = exit_flag;
sol.omega_list = param.omega_list;
end

function val = planted_2023_aux(param, idx)
% 2023 锚点值 u^2023(i,j,s)（调用方计算 1-值 作为约束右端）
p23 = param.planted_2023;
oi = param.omega_list(idx, 1);  oj = param.omega_list(idx, 2);  os = param.omega_list(idx, 3);
val = p23(oi, oj, os);
end

function val = planted_2023_aux2(param, i, j)
% 2023 锚点值 u^2023(i,j,2)（智慧大棚跨年跨季 C1-6c，调用方计算 1-值）
val = param.planted_2023(i, j, 2);
end
