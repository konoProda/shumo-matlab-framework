function [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q2(price_v, load_p, pv_p, E_start, prm, use_bin)
%FUNC_BUILD_Q2  装配问题二"显式分流 + 紧急购电"模型标准型
%
%   目标 (OBJ)  min  sum_s [ pi_s*(G^L_s + G^ch_s) + kappa_em*pi_s*(H^L_s + H^ch_s) ] * dt
%   约束 (1)    G^L_s + H^L_s + D_s = Lbar_s                       负荷平衡
%   约束 (2)    PV^ch_s + G^ch_s + H^ch_s = C_s                    储能充电来源平衡
%   约束 (3)    PV^ch_s + V_s = PVbar_s                            光伏剩余平衡
%   约束 (4)    E_s - E_{s-1} - eta_c*dt*C_s + (dt/eta_dis)*D_s = 0  储能状态转移
%   约束 (5)    C_s - P_max*u_s <= 0                               充放电互斥（上）
%   约束 (6)    D_s + P_max*u_s <= P_max                           充放电互斥（下）
%   约束 (7)    0 <= V_s <= PVbar_s；0 <= C_s, D_s <= P_max；E_min <= E_s <= E_max
%
%   分流辅助量（由输入数据确定，不作为决策变量）
%     PV^L_s = min(PV_s, L_s)   Lbar_s = max(L_s - PV_s, 0)   PVbar_s = max(PV_s - L_s, 0)
%
%   紧急购电拆为 H^L（直供负载）与 H^ch（供储能充电）两个变量：若合并为一个变量同时进入
%   约束 (1)(2)，同一度电会被重复使用，物理上不成立。
%
%   输入  price_v  nS×1  电价（每天相同，按槽平铺） 元/kWh
%         load_p   nS×1  小区负载功率 kW
%         pv_p     nS×1  光伏实际功率 kW
%         E_start  标量  本段起点（第 1 槽之前）的储电量 kWh
%         prm            参数结构体
%         use_bin  逻辑  true = 含互斥二元变量（MILP，10 块）；false = 连续松弛（LP，9 块）
%   输出  intlinprog / linprog 标准型；aux 含分流辅助量与分段索引
%
%   变量分段索引（nS 为段内槽数）
%     G^L:  1:nS            G^ch: nS+1:2nS        H^L:  2nS+1:3nS
%     H^ch: 3nS+1:4nS       PV^ch: 4nS+1:5nS      C:    5nS+1:6nS
%     D:    6nS+1:7nS       E: 7nS+1:8nS          V:    8nS+1:9nS
%     u:    9nS+1:10nS（仅 use_bin = true）

nS = numel(price_v);
dt = prm.dt;
eta_c = prm.eta_ch;
eta_d = prm.eta_dis;

% 由输入数据确定的分流辅助量
aux = struct();
aux.PVL   = min(pv_p(:), load_p(:));
aux.Lbar  = max(load_p(:) - pv_p(:), 0);
aux.PVbar = max(pv_p(:) - load_p(:), 0);

% 变量分段（一律列向量，保证三元组拼接方向一致）
iGL  = (1:nS).';
iGC  = (nS+1 : 2*nS).';
iHL  = (2*nS+1 : 3*nS).';
iHC  = (3*nS+1 : 4*nS).';
iPVC = (4*nS+1 : 5*nS).';
iC   = (5*nS+1 : 6*nS).';
iD   = (6*nS+1 : 7*nS).';
iE   = (7*nS+1 : 8*nS).';
iV   = (8*nS+1 : 9*nS).';

aux.idx = struct('GL', iGL(1), 'GC', iGC(1), 'HL', iHL(1), 'HC', iHC(1), ...
                 'PVC', iPVC(1), 'C', iC(1), 'D', iD(1), 'E', iE(1), 'V', iV(1));

n = 9 * nS;
if use_bin
    iU = (9*nS+1 : 10*nS).';
    aux.idx.U = iU(1);
    n = 10 * nS;
end

% ---- 目标函数 (OBJ)：正常购电按电价、紧急购电按 kappa_em 倍电价 ----
f = zeros(n, 1);
f(iGL) = price_v(:) * dt;
f(iGC) = price_v(:) * dt;
f(iHL) = prm.kappa_em * price_v(:) * dt;
f(iHC) = prm.kappa_em * price_v(:) * dt;

% ---- 变量上下界 (7) ----
lb = zeros(n, 1);
ub = inf(n, 1);
ub(iGL)  = 1e5;              % 购电功率无题面上限，取远大于负荷的量级
ub(iGC)  = 1e5;
ub(iHL)  = 1e5;
ub(iHC)  = 1e5;
ub(iPVC) = aux.PVbar;        % 光伏充电不超过光伏剩余
ub(iV)   = aux.PVbar;        % 弃光不超过光伏剩余
ub(iC)   = prm.P_max;
ub(iD)   = prm.P_max;
lb(iE)   = prm.E_min;
ub(iE)   = prm.E_max;

% ---- 等式约束：三条流量平衡 + 状态转移 (1)(2)(3)(4) ----
rBL = (1:nS).';                 % 负荷平衡
rCH = nS + (1:nS).';            % 充电来源平衡
rPV = 2*nS + (1:nS).';          % 光伏剩余平衡
rST = 3*nS + (1:nS).';          % 储能状态

beq = zeros(4*nS, 1);
beq(rBL) = aux.Lbar;
beq(rPV) = aux.PVbar;

% (1) G^L + H^L + D = Lbar
I = [rBL; rBL; rBL];
J = [iGL; iHL; iD ];
S = [ones(nS,1); ones(nS,1); ones(nS,1)];

% (2) PV^ch + G^ch + H^ch - C = 0
I = [I; rCH; rCH; rCH; rCH];
J = [J; iPVC; iGC; iHC; iC];
S = [S; ones(nS,1); ones(nS,1); ones(nS,1); -ones(nS,1)];

% (3) PV^ch + V = PVbar
I = [I; rPV; rPV];
J = [J; iPVC; iV];
S = [S; ones(nS,1); ones(nS,1)];

% (4) 首槽：E_1 - eta_c*dt*C_1 + (dt/eta_d)*D_1 = E_start
I = [I; rST(1); rST(1); rST(1)];
J = [J; iE(1);   iC(1);   iD(1)  ];
S = [S; 1;       -eta_c*dt; dt/eta_d];
beq(rST(1)) = E_start;

% (4) 其余槽：E_s - E_{s-1} - eta_c*dt*C_s + (dt/eta_d)*D_s = 0
s2 = (2:nS).';
if ~isempty(s2)
    I = [I; rST(s2); rST(s2); rST(s2); rST(s2)];
    J = [J; iE(s2);   iE(s2-1); iC(s2);   iD(s2)  ];
    S = [S; ones(nS-1,1); -ones(nS-1,1); -eta_c*dt*ones(nS-1,1); (dt/eta_d)*ones(nS-1,1)];
end

Aeq = sparse(I, J, S, 4*nS, n);

% ---- 不等式约束 (5)(6)：充放电互斥（仅含二元变量时装配）----
% 行 1..nS   ：C_s - P_max*u_s <= 0
% 行 nS+1..2nS：D_s + P_max*u_s <= P_max
if use_bin
    I2 = [(1:nS).'; (1:nS).'; nS + (1:nS).'; nS + (1:nS).'];
    J2 = [iC;       iU;       iD;            iU          ];
    S2 = [ones(nS,1); -prm.P_max*ones(nS,1); ones(nS,1); prm.P_max*ones(nS,1)];
    A = sparse(I2, J2, S2, 2*nS, n);
    b = [zeros(nS,1); prm.P_max*ones(nS,1)];
    intcon = iU;
    ub(iU) = 1;
else
    A = sparse(0, n);
    b = zeros(0, 1);
    intcon = zeros(0, 1);
end

end
