function [f, intcon, A, b, Aeq, beq, lb, ub] = func_build_q1(price_v, load_p, pv_p, prm)
%FUNC_BUILD_Q1  装配问题一 MILP 标准型
%
%   目标 (1)   min  sum_t pi_t*G_t*dt
%   约束 (2)   G_t + D_t - C_t - V_t = L_t - PV_t        能量平衡
%   约束 (3)   G_t >= 0                                  不允许售电
%   约束 (4)   0 <= V_t <= max(PV_t - L_t, 0)            弃光上下界
%   约束 (5)   E_t = E_{t-1} + eta_ch*C_t*dt - D_t*dt/eta_dis
%   约束 (6)   E_min <= E_t <= E_max,  E_T = E_0         容量与初末
%   约束 (7)   0 <= C_t, D_t <= P_max                    充放电功率
%   约束 (8)   C_t - P_max*u_t <= 0,  D_t + P_max*u_t <= P_max   充放电互斥
%
%   变量分段索引（共 6T 个）
%     G: 1:T   C: T+1:2T   D: 2T+1:3T   E: 3T+1:4T   V: 4T+1:5T   u: 5T+1:6T
%
%   输入  price_v/load_p/pv_p  电价 / 小区负载 / 光伏预测，均 T×1
%         prm                  参数结构体（T, dt, eta_ch, eta_dis, E_init, E_min, E_max, P_max）
%   输出  intlinprog 标准型

T   = prm.T;
n   = 6 * T;
dt  = prm.dt;
eta_c = prm.eta_ch;
eta_d = prm.eta_dis;

% 变量分段（列向量，保证三元组拼接方向一致）
iG = (1:T).';
iC = (T+1 : 2*T).';
iD = (2*T+1 : 3*T).';
iE = (3*T+1 : 4*T).';
iV = (4*T+1 : 5*T).';
iU = (5*T+1 : 6*T).';

% ---- 目标函数 (1) ----
f = zeros(n, 1);
f(iG) = price_v(:) * dt;

% ---- 变量上下界：约束 (3)(4)(6)(7) 与二元域 ----
lb = zeros(n, 1);
ub = inf(n, 1);
ub(iG) = 1e5;                        % 充分大，不设 Inf 便于预求解收紧
ub(iC) = prm.P_max;
ub(iD) = prm.P_max;
lb(iE) = prm.E_min;
ub(iE) = prm.E_max;
ub(iV) = max(pv_p(:) - load_p(:), 0);
lb(iU) = 0;
ub(iU) = 1;

% ---- 等式约束：平衡 (2) / 状态 (5) / 期末 (6) ----
rBal = (1:T).';                      % 1 : T
rSta = T + (1:T).';                  % T+1 : 2T
rEnd = 2*T + 1;                      % 2T+1

beq = zeros(2*T + 1, 1);
beq(rBal) = load_p(:) - pv_p(:);

% 平衡行：G + D - C - V
I = [rBal; rBal; rBal; rBal];
J = [iG;   iD;   iC;   iV  ];
S = [ones(T,1); ones(T,1); -ones(T,1); -ones(T,1)];

% 状态行 t=1：E_1 - eta_c*dt*C_1 + (dt/eta_d)*D_1 = E_0
I = [I; rSta(1); rSta(1); rSta(1)];
J = [J; iE(1);   iC(1);   iD(1)  ];
S = [S; 1;       -eta_c*dt; dt/eta_d];
beq(rSta(1)) = prm.E_init;

% 状态行 t>=2：E_t - E_{t-1} - eta_c*dt*C_t + (dt/eta_d)*D_t = 0
t2 = (2:T).';
if ~isempty(t2)
    I = [I; rSta(t2); rSta(t2); rSta(t2); rSta(t2)];
    J = [J; iE(t2);   iE(t2-1); iC(t2);   iD(t2)  ];
    S = [S; ones(T-1,1); -ones(T-1,1); -eta_c*dt*ones(T-1,1); (dt/eta_d)*ones(T-1,1)];
end

% 期末行 (6)：E_T = E_0
I = [I; rEnd];
J = [J; iE(T)];
S = [S; 1];
beq(rEnd) = prm.E_init;

Aeq = sparse(I, J, S, 2*T + 1, n);

% ---- 不等式约束：充放电互斥 (8) ----
% 行 1..T   ：C_t - P_max*u_t <= 0
% 行 T+1..2T：D_t + P_max*u_t <= P_max
I = [(1:T).'; (1:T).'; T + (1:T).'; T + (1:T).'];
J = [iC;      iU;      iD;          iU          ];
S = [ones(T,1); -prm.P_max*ones(T,1); ones(T,1); prm.P_max*ones(T,1)];
A = sparse(I, J, S, 2*T, n);
b = [zeros(T,1); prm.P_max*ones(T,1)];

intcon = iU;

end
