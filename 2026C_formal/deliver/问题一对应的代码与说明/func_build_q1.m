function [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q1(price_v, load_p, pv_p, prm)
%FUNC_BUILD_Q1  装配问题一"显式分流"MILP 标准型
%
%   目标 (1)   min  sum_t pi_t*(G^L_t + G^ch_t)*dt
%   约束 (2)   G^L_t + D_t = Lbar_t                     负荷平衡（含 D_t <= Lbar_t）
%   约束 (3)   PV^ch_t + G^ch_t = C_t                   充电来源平衡
%   约束 (4)   PV^ch_t + V_t = PVbar_t                  光伏剩余平衡（含 V_t <= PVbar_t）
%   约束 (5)   E_t = E_{t-1} + eta_c*C_t*dt - D_t*dt/eta_dis
%   约束 (6)   E_min <= E_t <= E_max,  E_T = E_0
%   约束 (7)   0 <= C_t, D_t <= P_max
%   约束 (8)   C_t - P_max*u_t <= 0,  D_t + P_max*u_t <= P_max
%
%   分流辅助量（由输入数据确定，不参与优化）
%     PV^L_t = min(PV_t, L_t)      Lbar_t = max(L_t - PV_t, 0)      PVbar_t = max(PV_t - L_t, 0)
%
%   变量分段索引（共 8T 个；三条流量平衡式取代了总能量平衡，故不设总购电变量）
%     G^L: 1:T   G^ch: T+1:2T   PV^ch: 2T+1:3T   C: 3T+1:4T
%     D: 4T+1:5T   E: 5T+1:6T   V: 6T+1:7T   u: 7T+1:8T
%
%   输入  price_v/load_p/pv_p  电价 / 小区负载 / 光伏预测，均 T×1
%         prm                  参数结构体（T, dt, eta_ch, eta_dis, E_init, E_min, E_max, P_max）
%   输出  intlinprog 标准型；aux 为分流辅助量（PVL / Lbar / PVbar）

T   = prm.T;
n   = 8 * T;
dt  = prm.dt;
eta_c = prm.eta_ch;
eta_d = prm.eta_dis;

% 由输入数据确定的分流辅助量
aux = struct();
aux.PVL   = min(pv_p(:), load_p(:));
aux.Lbar  = max(load_p(:) - pv_p(:), 0);
aux.PVbar = max(pv_p(:) - load_p(:), 0);

% 变量分段（列向量，保证三元组拼接方向一致）
iGL  = (1:T).';
iGC  = (T+1 : 2*T).';
iPVC = (2*T+1 : 3*T).';
iC   = (3*T+1 : 4*T).';
iD   = (4*T+1 : 5*T).';
iE   = (5*T+1 : 6*T).';
iV   = (6*T+1 : 7*T).';
iU   = (7*T+1 : 8*T).';

% ---- 目标函数 (1)：购电费用按两条外网来路计 ----
f = zeros(n, 1);
f(iGL) = price_v(:) * dt;
f(iGC) = price_v(:) * dt;

% ---- 变量上下界 ----
lb = zeros(n, 1);
ub = inf(n, 1);
ub(iGL) = 1e5;
ub(iGC) = 1e5;
ub(iPVC) = aux.PVbar;              % 光伏充电不超过光伏剩余
ub(iC) = prm.P_max;
ub(iD) = prm.P_max;
lb(iE) = prm.E_min;
ub(iE) = prm.E_max;
ub(iV) = aux.PVbar;                % 弃光不超过光伏剩余
lb(iU) = 0;
ub(iU) = 1;

% ---- 等式约束：流量平衡 (2)(3)(4) / 状态 (5) / 期末 (6) ----
rBL = (1:T).';                     % 负荷平衡
rCH = T + (1:T).';                 % 充电来源平衡
rPV = 2*T + (1:T).';               % 光伏剩余平衡
rST = 3*T + (1:T).';               % 储能状态
rEnd = 4*T + 1;                    % 期末储电量

beq = zeros(4*T + 1, 1);
beq(rBL) = aux.Lbar;
beq(rPV) = aux.PVbar;

% (2) G^L + D = Lbar
I = [rBL; rBL];
J = [iGL; iD ];
S = [ones(T,1); ones(T,1)];

% (3) PV^ch + G^ch - C = 0
I = [I; rCH; rCH; rCH];
J = [J; iPVC; iGC; iC];
S = [S; ones(T,1); ones(T,1); -ones(T,1)];

% (4) PV^ch + V = PVbar
I = [I; rPV; rPV];
J = [J; iPVC; iV];
S = [S; ones(T,1); ones(T,1)];

% (5) 状态行 t=1：E_1 - eta_c*dt*C_1 + (dt/eta_d)*D_1 = E_0
I = [I; rST(1); rST(1); rST(1)];
J = [J; iE(1);   iC(1);   iD(1)  ];
S = [S; 1;       -eta_c*dt; dt/eta_d];
beq(rST(1)) = prm.E_init;

% (5) 状态行 t>=2：E_t - E_{t-1} - eta_c*dt*C_t + (dt/eta_d)*D_t = 0
t2 = (2:T).';
if ~isempty(t2)
    I = [I; rST(t2); rST(t2); rST(t2); rST(t2)];
    J = [J; iE(t2);   iE(t2-1); iC(t2);   iD(t2)  ];
    S = [S; ones(T-1,1); -ones(T-1,1); -eta_c*dt*ones(T-1,1); (dt/eta_d)*ones(T-1,1)];
end

% (6) 期末：E_T = E_0
I = [I; rEnd];
J = [J; iE(T)];
S = [S; 1];
beq(rEnd) = prm.E_init;

Aeq = sparse(I, J, S, 4*T + 1, n);

% ---- 不等式约束：充放电互斥 (8) ----
% 行 1..T   ：C_t - P_max*u_t <= 0
% 行 T+1..2T：D_t + P_max*u_t <= P_max
I2 = [(1:T).'; (1:T).'; T + (1:T).'; T + (1:T).'];
J2 = [iC;      iU;      iD;          iU          ];
S2 = [ones(T,1); -prm.P_max*ones(T,1); ones(T,1); prm.P_max*ones(T,1)];
A = sparse(I2, J2, S2, 2*T, n);
b = [zeros(T,1); prm.P_max*ones(T,1)];

intcon = iU;

end
