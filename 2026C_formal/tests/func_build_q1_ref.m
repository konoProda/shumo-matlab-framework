function [f, intcon, A, b, Aeq, beq, lb, ub] = func_build_q1_ref(price_v, load_p, pv_p, prm)
%FUNC_BUILD_Q1_REF  参考实现：总能量平衡式（6T 变量），仅用于测试期交叉校验
%   与显式分流模型对照，验证两种表述给出同一最优值。组内产物，不交付。

T   = prm.T;
n   = 6 * T;
dt  = prm.dt;
eta_c = prm.eta_ch;
eta_d = prm.eta_dis;

iG = (1:T).';
iC = (T+1 : 2*T).';
iD = (2*T+1 : 3*T).';
iE = (3*T+1 : 4*T).';
iV = (4*T+1 : 5*T).';
iU = (5*T+1 : 6*T).';

f = zeros(n, 1);
f(iG) = price_v(:) * dt;

lb = zeros(n, 1);
ub = inf(n, 1);
ub(iG) = 1e5;
ub(iC) = prm.P_max;
ub(iD) = prm.P_max;
lb(iE) = prm.E_min;
ub(iE) = prm.E_max;
ub(iV) = max(pv_p(:) - load_p(:), 0);
lb(iU) = 0;
ub(iU) = 1;

rBal = (1:T).';
rSta = T + (1:T).';
rEnd = 2*T + 1;

beq = zeros(2*T + 1, 1);
beq(rBal) = load_p(:) - pv_p(:);

I = [rBal; rBal; rBal; rBal];
J = [iG;   iD;   iC;   iV  ];
S = [ones(T,1); ones(T,1); -ones(T,1); -ones(T,1)];

I = [I; rSta(1); rSta(1); rSta(1)];
J = [J; iE(1);   iC(1);   iD(1)  ];
S = [S; 1;       -eta_c*dt; dt/eta_d];
beq(rSta(1)) = prm.E_init;

t2 = (2:T).';
I = [I; rSta(t2); rSta(t2); rSta(t2); rSta(t2)];
J = [J; iE(t2);   iE(t2-1); iC(t2);   iD(t2)  ];
S = [S; ones(T-1,1); -ones(T-1,1); -eta_c*dt*ones(T-1,1); (dt/eta_d)*ones(T-1,1)];

I = [I; rEnd];
J = [J; iE(T)];
S = [S; 1];
beq(rEnd) = prm.E_init;

Aeq = sparse(I, J, S, 2*T + 1, n);

I = [(1:T).'; (1:T).'; T + (1:T).'; T + (1:T).'];
J = [iC;      iU;      iD;          iU          ];
S = [ones(T,1); -prm.P_max*ones(T,1); ones(T,1); prm.P_max*ones(T,1)];
A = sparse(I, J, S, 2*T, n);
b = [zeros(T,1); prm.P_max*ones(T,1)];

intcon = iU;

end
