function sol = func_q3_extend(param, scen, u_q1, rho_sp, clusters, phi, theta_rule)
% func_q3_extend —— 问题3 替代/互补拓展求解（映射表 C3-1~C3-4）
% 输入: param/scen/u_q1（沿用 Q2 拓扑）；rho_sp/clusters（func_q3_stats 输出）
%       phi 互补折减系数（0.90，Δc=0.10）；theta_rule 转移系数规则（'abs_rho'）
% 机制: 替代 C3-1/C3-2 —— 同簇且 rho<=-0.4 构成替代集，需求转移 theta=|rho| 直接线性化；
%       互补 C3-3/C3-4 —— 前茬豆类成本折减（B6 时序，u 固定后为常数系数）
% 输出: 与 func_q2_saa 同结构（sol.x 为 Q3 策略），alpha=0.95、lambda=0.1 基准

assert(strcmp(theta_rule, 'abs_rho'), 'theta_rule 仅支持 ''abs_rho''');
ext.rho_sp = rho_sp;
ext.clusters = clusters;
ext.phi = phi;
sol = func_q2_saa(param, scen, u_q1, 0.95, 0.1, 'lp_fixed', ext);
end
