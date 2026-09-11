function rep = func_check_q1(x, price_v, load_p, pv_p, prm)

% 问题一解的校验（建模文档 §16）
% 输出 rep.pass 为总体结论，rep 其余字段保留各项残差供报告引用

T  = prm.T;
dt = prm.dt;
G = x(1:T);
C = x(T+1 : 2*T);
D = x(2*T+1 : 3*T);
E = x(3*T+1 : 4*T);
V = x(4*T+1 : 5*T);
u = x(5*T+1 : 6*T);

tol = 1e-6;

rep.bal_resid  = max(abs(G + pv_p(:) + D - load_p(:) - C - V));            % §16.1
rep.state_resid = max(abs(diff([prm.E_init; E]) - prm.eta_ch*C*dt + D*dt/prm.eta_dis));  % §16.2
rep.viol = struct( ...
    'G_nonneg',   min(G), ...
    'C_range',    max([-min(C), max(C) - prm.P_max]), ...
    'D_range',    max([-min(D), max(D) - prm.P_max]), ...
    'E_range',    max([prm.E_min - min(E), max(E) - prm.E_max]), ...
    'V_range',    max([-min(V), max(V - max(pv_p(:)-load_p(:), 0))]), ...
    'u_binary',   max(abs(u - round(u))), ...
    'simult',     max(min(C, D)), ...
    'E_terminal', abs(E(end) - prm.E_init));

worst = max(struct2array(rep.viol));
rep.pass = rep.bal_resid < tol && rep.state_resid < tol && worst < tol;

rep.Z = sum(price_v(:) .* G) * dt;
rep.buy_total = sum(G) * dt;
rep.chg_total = sum(C) * dt;
rep.dis_total = sum(D) * dt;
rep.curt_total = sum(V) * dt;

end
