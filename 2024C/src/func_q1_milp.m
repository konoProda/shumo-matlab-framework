function sol = func_q1_milp(param, planted_2023, case_mode, debug_flag, opts_in)
% func_q1_milp —— 问题1 确定性 MILP 装配与求解（映射表 C1-1~C1-8）
% 输入: param  参数结构（func_build_params 输出，主程序注入 delta_min）
%       planted_2023  54x41x2 logical 2023种植锚点（P1-8）
%       case_mode  '滞销'（γ=0，q_disc≡0）| '半价'（γ=0.5）
%       debug_flag 可选，'debug' 时不求解，返回装配产物（A/b/f/lb/ub/intcon）
%       opts_in   可选，intlinprog 选项对象（稳定性检验用），缺省 MaxTime=900
% 输出: sol.x / sol.u / sol.q_norm / sol.q_disc  Nx7（N=|Ω|=1062，列为年份）
%       sol.profit_total 七年总利润（元）；sol.profit_by_year 7x1；sol.exit_flag

n_t = 7;
N = size(param.omega_list, 1);
oi = param.omega_list(:, 1);  oj = param.omega_list(:, 2);  os = param.omega_list(:, 3);
Ai = param.plot_area(oi);                          % 每个 Ω 行的地块面积
delta = param.delta_min;                           % P1-6

% ---- 变量分块：x | u | q_norm | q_disc（块内 (idx,t) 列主序） ----
N7 = N * n_t;
off_u = N7;  off_qn = 2 * N7;  off_qd = 3 * N7;
n_var = 4 * N7;
xidx  = @(idx, t) (t - 1) * N + idx;
uidx  = @(idx, t) off_u  + (t - 1) * N + idx;
qnidx = @(idx, t) off_qn + (t - 1) * N + idx;
qdidx = @(idx, t) off_qd + (t - 1) * N + idx;
allidx = (1:N)';                                    % 列向量，保证索引结果始终为列

% ---- 目标：max W -> min -W（W 见映射表 3.3） ----
if strcmp(case_mode, '滞销')
    gamma = 0;
else
    gamma = 0.5;
end
f = zeros(n_var, 1);
for t = 1:n_t
    f(xidx(allidx, t))  = param.cost_i;               % +C·x（取负后为 -C·x）
    f(qnidx(allidx, t)) = -param.price_i;             % -P·q_norm
    f(qdidx(allidx, t)) = -gamma * param.price_i;     % -γP·q_disc
end

% ---- 按 (i,s)/(j,s) 预分组 Ω 行 ----
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

% ---- 约束稀疏装配（全为不等式，Aeq 为空） ----
% Ic=变量列索引，Jc=约束行索引，Vc=系数，bc=右端项；n_row 随每次追加递增
Ic = {};  Jc = {};  Vc = {};  bc = {};  n_row = 0;

% C1-2 全村需求上限: Σ_i q_norm ≤ D_{j,s}
for t = 1:n_t
    for j = 1:41
        for s = 1:2
            ids = idx_js{j, s};
            if isempty(ids), continue; end
            n_row = n_row + 1;
            Ic{end+1, 1} = qnidx(ids, t);  Jc{end+1, 1} = n_row + zeros(numel(ids), 1);
            Vc{end+1, 1} = ones(numel(ids), 1);  bc{end+1, 1} = param.demand_2023(j, s);
        end
    end
end

% C1-3 单地块产销: q_norm + q_disc ≤ Y·x（C1-1 的 Q 已代入，每个 idx 独立一行）
for t = 1:n_t
    Ic{end+1, 1} = [qnidx(allidx, t); qdidx(allidx, t); xidx(allidx, t)];
    Jc{end+1, 1} = n_row + [allidx; allidx; allidx];
    Vc{end+1, 1} = [ones(N, 1); ones(N, 1); -param.yield_i];
    bc{end+1, 1} = zeros(N, 1);
    n_row = n_row + N;
end

% C1-4 面积上限: Σ_j x ≤ A_i（按 (i,s) 分组）
for t = 1:n_t
    for i = 1:54
        for s = 1:2
            ids = idx_is{i, s};
            if isempty(ids), continue; end
            n_row = n_row + 1;
            Ic{end+1, 1} = xidx(ids, t);  Jc{end+1, 1} = n_row + zeros(numel(ids), 1);
            Vc{end+1, 1} = ones(numel(ids), 1);  bc{end+1, 1} = Ai(ids(1));
        end
    end
end

% C1-5 最小比例与种植开关: δ·A_i·u ≤ x ≤ A_i·u（每个 idx 独立一行）
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
    rhs = 1 - planted_2023(oi(idx), oj(idx), os(idx));
    n_row = n_row + 1;
    Ic{end+1, 1} = uidx(idx, 1);  Jc{end+1, 1} = n_row;  Vc{end+1, 1} = 1;  bc{end+1, 1} = rhs;
end
for t = 2:n_t
    Ic{end+1, 1} = [uidx(allidx, t); uidx(allidx, t - 1)];
    Jc{end+1, 1} = n_row + [allidx; allidx];
    Vc{end+1, 1} = ones(2 * N, 1);  bc{end+1, 1} = ones(N, 1);
    n_row = n_row + N;
end

% C1-6b 连作（年内跨季，i∈27..54；实质作用于智慧大棚）
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

% C1-6c 连作（智慧大棚跨年跨季: (t-1)第二季 -> t第一季，含 2023 常数）
for i = 51:54
    ids1 = idx_is{i, 1};
    for k = 1:numel(ids1)
        rhs = 1 - planted_2023(i, oj(ids1(k)), 2);
        n_row = n_row + 1;
        Ic{end+1, 1} = uidx(ids1(k), 1);  Jc{end+1, 1} = n_row;  Vc{end+1, 1} = 1;  bc{end+1, 1} = rhs;
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

% C1-7 豆类轮作（B1 修正）：窗口 t-2..t，t∈{2025..2030}（列 2..7），2023 为常数
bean = [1 2 3 4 5 17 18 19];
for i = 1:54
    ids_i = find(oi == i & ismember(oj, bean));
    if isempty(ids_i), continue; end
    bean_2023 = sum(planted_2023(i, bean, :), 'all');
    for tt = 2:n_t
        rhs = 1 - (tt == 2) * bean_2023;
        if rhs <= 0, continue; end                     % 2023 已种豆类，该窗口自动满足
        tau_all = max(1, tt - 2):tt;
        n_col = numel(tau_all);
        n_row = n_row + 1;
        Ic{end+1, 1} = reshape(uidx(ids_i, tau_all), [], 1);  % 列主序: tau 外层, idx 内层
        Jc{end+1, 1} = n_row + zeros(numel(ids_i) * n_col, 1);
        Vc{end+1, 1} = ones(numel(ids_i) * n_col, 1);
        bc{end+1, 1} = rhs;
    end
end

% C1-8 集中度: Σ_i u ≤ N_j^max
for t = 1:n_t
    for j = 1:41
        for s = 1:2
            ids = idx_js{j, s};
            if isempty(ids), continue; end
            n_row = n_row + 1;
            Ic{end+1, 1} = uidx(ids, t);  Jc{end+1, 1} = n_row + zeros(numel(ids), 1);
            Vc{end+1, 1} = ones(numel(ids), 1);  bc{end+1, 1} = param.n_plot_max(j);
        end
    end
end

A = sparse(vertcat(Jc{:}), vertcat(Ic{:}), vertcat(Vc{:}), n_row, n_var);
b = vertcat(bc{:});

% ---- 边界与整数性 ----
lb = zeros(n_var, 1);
ub = inf(n_var, 1);
intcon = (off_u + 1:off_u + N7)';
if strcmp(case_mode, '滞销')                       % 情况(1)：q_disc ≡ 0
    lb(off_qd + 1:off_qd + N7) = 0;
    ub(off_qd + 1:off_qd + N7) = 0;
end

if nargin >= 4 && strcmp(debug_flag, 'debug')
    sol.A = A;  sol.b = b;  sol.f = f;
    sol.lb = lb;  sol.ub = ub;  sol.intcon = intcon;
    sol.n_row = n_row;  sol.n_var = n_var;  sol.n_blocks = N7;
    sol.row_seq = cellfun(@(c) c(1), Jc);      % 每次追加的行号序列
    sol.entry_sz = cellfun(@numel, Ic);        % 每次追加的非零个数
    return;
end

% ---- 求解 ----
if nargin >= 5 && ~isempty(opts_in)
    opts = opts_in;
else
    opts = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 900);
end
[sol_vec, ~, exit_flag] = intlinprog(f, intcon, A, b, [], [], lb, ub, opts);
if exit_flag < 1
    warning('intlinprog 返回 exit_flag=%d（可能不可行或超时）', exit_flag);
end

% ---- 拆解与利润核算 ----
x_mat  = reshape(sol_vec(1:N7), N, n_t);
u_mat  = reshape(round(sol_vec(off_u + 1:off_qn)), N, n_t);
qn_mat = reshape(sol_vec(off_qn + 1:off_qd), N, n_t);
qd_mat = reshape(sol_vec(off_qd + 1:end), N, n_t);
profit_by_year = zeros(n_t, 1);
for t = 1:n_t
    profit_by_year(t) = sum(param.price_i .* qn_mat(:, t) ...
                          + gamma * param.price_i .* qd_mat(:, t) ...
                          - param.cost_i .* x_mat(:, t));
end

sol.x = x_mat;  sol.u = u_mat;  sol.q_norm = qn_mat;  sol.q_disc = qd_mat;
sol.profit_total = sum(profit_by_year);
sol.profit_by_year = profit_by_year;
sol.exit_flag = exit_flag;
sol.omega_list = param.omega_list;
end
