function rep = func_check_q2(x, price_v, load_p, pv_p, prm, aux, E_start)
%FUNC_CHECK_Q2  校验一段求解结果的约束残差、越界与能源流向汇总
%
%   残差对应模型约束 (1)~(4)；流向汇总用于论文的能源流向分析与四组交叉校验。
%
%   输入  x        解向量（段内 nS 槽，10 块）
%         price_v  段内电价 nS×1
%         load_p   段内负载 nS×1      pv_p  段内光伏 nS×1
%         prm      参数结构体
%         aux      func_build_q2 返回的分流辅助量与分段索引
%         E_start  段起点储电量 kWh
%   输出  rep      残差 / 越界 / 流向汇总 / 费用复核

nS = numel(load_p);
o  = aux.idx;
dt = prm.dt;

GL  = x(o.GL  : o.GL +nS-1);
GC  = x(o.GC  : o.GC +nS-1);
HL  = x(o.HL  : o.HL +nS-1);
HC  = x(o.HC  : o.HC +nS-1);
PVC = x(o.PVC : o.PVC+nS-1);
CC  = x(o.C   : o.C  +nS-1);
DD  = x(o.D   : o.D  +nS-1);
EE  = x(o.E   : o.E  +nS-1);
VV  = x(o.V   : o.V  +nS-1);

% 约束残差 (1)(2)(3)(4)
rep.flow_load = max(abs(GL + HL + DD - aux.Lbar));
rep.flow_chg  = max(abs(PVC + GC + HC - CC));
rep.flow_pv   = max(abs(PVC + VV - aux.PVbar));
Eprev = [E_start; EE(1:end-1)];
rep.state_resid = max(abs(EE - Eprev - prm.eta_ch*dt*CC + DD*dt/prm.eta_dis));

% 互斥与越界
rep.mutex   = max(min(CC, DD));
rep.viol.Elo = max(max(prm.E_min - EE), 0);
rep.viol.Ehi = max(max(EE - prm.E_max), 0);
rep.viol.Chi = max(max(CC - prm.P_max), 0);
rep.viol.Dhi = max(max(DD - prm.P_max), 0);
rep.viol.Vhi = max(max(VV - aux.PVbar), 0);
rep.viol.neg = max(-min([GL; GC; HL; HC; PVC; CC; DD; VV]));

% 能源流向汇总（kWh）
rep.pv_load  = sum(aux.PVL)*dt;
rep.pv_chg   = sum(PVC)*dt;
rep.curt     = sum(VV)*dt;
rep.g_load   = sum(GL)*dt;
rep.g_chg    = sum(GC)*dt;
rep.h_load   = sum(HL)*dt;
rep.h_chg    = sum(HC)*dt;
rep.chg_tot  = sum(CC)*dt;
rep.dis_tot  = sum(DD)*dt;
rep.buy_norm = (sum(GL) + sum(GC))*dt;
rep.buy_em   = (sum(HL) + sum(HC))*dt;
rep.E_end    = EE(end);

% 费用复核：按目标函数 (OBJ) 独立重算
rep.cost = (sum(price_v(:).*(GL + GC)) + prm.kappa_em*sum(price_v(:).*(HL + HC)))*dt;

% 四组交叉校验（用未舍入值）
rep.xchk.pv   = sum(pv_p)*dt  - (rep.pv_load + rep.pv_chg + rep.curt);
rep.xchk.load = sum(load_p)*dt - (rep.pv_load + rep.g_load + rep.h_load + rep.dis_tot);
rep.xchk.chg  = rep.chg_tot - (rep.pv_chg + rep.g_chg + rep.h_chg);
rep.xchk.buy  = (rep.buy_norm + rep.buy_em) - (rep.g_load + rep.g_chg + rep.h_load + rep.h_chg);

tol = 1e-6;
rep.pass = max([rep.flow_load, rep.flow_chg, rep.flow_pv, rep.state_resid, rep.mutex]) < tol ...
    && max(struct2array(rep.viol)) < tol;

end
