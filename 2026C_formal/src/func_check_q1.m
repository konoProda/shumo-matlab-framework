function rep = func_check_q1(x, price_v, load_p, pv_p, prm, aux)

% 问题一"显式分流"解的校验
% 依次核对三条流量平衡式、储能状态、总平衡（导出量）、各变量上下界与互斥关系

T  = prm.T;
dt = prm.dt;
GL  = x(1:T);
GC  = x(T+1 : 2*T);
PVC = x(2*T+1 : 3*T);
C   = x(3*T+1 : 4*T);
D   = x(4*T+1 : 5*T);
E   = x(5*T+1 : 6*T);
V   = x(6*T+1 : 7*T);
u   = x(7*T+1 : 8*T);

tol = 1e-6;

rep.flow_load  = max(abs(GL + D - aux.Lbar));                   % 约束 (2)
rep.flow_chg   = max(abs(PVC + GC - C));                        % 约束 (3)
rep.flow_pv    = max(abs(PVC + V - aux.PVbar));                 % 约束 (4)
rep.state_resid = max(abs(diff([prm.E_init; E]) - prm.eta_ch*C*dt + D*dt/prm.eta_dis));
rep.total_bal  = max(abs((GL + GC) + pv_p(:) + D - load_p(:) - C - V));   % 导出量，应恒为零

rep.viol = struct( ...
    'GL_nonneg',  min(GL), ...
    'GC_nonneg',  min(GC), ...
    'PVC_range',  max([-min(PVC), max(PVC - aux.PVbar)]), ...
    'C_range',    max([-min(C), max(C) - prm.P_max]), ...
    'D_range',    max([-min(D), max(D) - prm.P_max]), ...
    'D_cap',      max(D - aux.Lbar), ...
    'E_range',    max([prm.E_min - min(E), max(E) - prm.E_max]), ...
    'V_range',    max([-min(V), max(V - aux.PVbar)]), ...
    'u_binary',   max(abs(u - round(u))), ...
    'simult',     max(min(C, D)), ...
    'E_terminal', abs(E(end) - prm.E_init));

worst = max(struct2array(rep.viol));
rep.pass = rep.flow_load < tol && rep.flow_chg < tol && rep.flow_pv < tol && ...
           rep.state_resid < tol && rep.total_bal < tol && worst < tol;

rep.buy_total  = sum(GL + GC) * dt;
rep.Z          = sum(price_v(:) .* (GL + GC)) * dt;
rep.pv_load    = sum(aux.PVL) * dt;
rep.pv_chg     = sum(PVC) * dt;
rep.grid_load  = sum(GL) * dt;
rep.grid_chg   = sum(GC) * dt;
rep.chg_total  = sum(C) * dt;
rep.dis_total  = sum(D) * dt;
rep.curt_total = sum(V) * dt;

end
