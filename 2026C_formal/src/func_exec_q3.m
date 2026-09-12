function out = func_exec_q3(Gplan, Gadj, Cadj, Dadj, load_a, pv_a, price_v, E_start, prm, policy)
%FUNC_EXEC_Q3  按最终生效购电量执行一天，并按三项口径结算
%
%   两种执行口径（同一份生效购电量，只是储能动作不同）：
%     'correct' 负载优先物理层（正式口径，C4 = A）
%     'plan'    储能严格照计划充放电（消融对照）
%
%   'correct' 规则（逐槽因果，只用当前时段已实现的量与当前实际储电量）：
%     R = G^adj_t + PV^act_t - L^act_t
%     R >= 0 : D_t = 0,  C_t = min{ R, P_max, (E_max-E_{t-1})/(eta_c*dt) },  V_t = R-C_t,  H_t = 0
%     R <  0 : C_t = 0,  D_t = min{ -R, P_max, eta_d*(E_{t-1}-E_min)/dt },   H_t = max{-R-D_t,0},  V_t = 0
%     不强行维持原计划的充电（实光伏不足时直接少充），供负载仍不足才紧急购电。
%
%   'plan' 规则：C_t、D_t 取计划值；供需净功率 Pnet = G^adj + PV^act + D - C，
%     不足部分记紧急购电、富余部分记弃光；储电量按计划充放电递推。
%
%   输入  Gplan / Gadj  T×1 原计划与最终生效购电功率 kW
%         Cadj / Dadj   T×1 计划充放电功率 kW（'plan' 口径使用）
%         load_a / pv_a T×1 当天实际负荷/光伏功率 kW
%         price_v       T×1 电价 元/kWh
%         E_start       标量 当天起点实际储电量 kWh
%         policy        'correct' | 'plan'
%   输出  out.C/D/E/H/V（**kWh**）、out.dP/dM（调整量 kWh）
%         out.cost_plan / cost_adj / cost_em / cost（元）
%   记账约定：本函数输出的电量一律为 kWh，三条费用式直接按 kWh 计算，不再乘 dt。

dt = prm.dt;
Gplan = Gplan(:);  Gadj = Gadj(:);  Cadj = Cadj(:);  Dadj = Dadj(:);
load_a = load_a(:);  pv_a = pv_a(:);  price_v = price_v(:);
T = numel(Gplan);                       % 本段槽数（全天 144，或 6:00/12:00/18:00 起的 108/72/36）

H = zeros(T,1);  V = zeros(T,1);
C = zeros(T,1);  D = zeros(T,1);  E = zeros(T,1);
Ecur = E_start;

switch policy
    case 'correct'
        for t = 1:T
            R = Gadj(t) + pv_a(t) - load_a(t);
            if R >= 0
                c = min([R, prm.P_max, (prm.E_max - Ecur)/(prm.eta_ch*dt)]);
                c = max(c, 0);
                d = 0;  h = 0;  v = R - c;
                assert(abs(R - c - v) < 1e-9, '富余时段恒等式 R = C + V 被破坏');
            else
                d = min([-R, prm.P_max, prm.eta_dis*(Ecur - prm.E_min)/dt]);
                d = max(d, 0);
                c = 0;  h = max(-R - d, 0);  v = 0;
                assert(abs(-R - d - h) < 1e-9, '缺口时段恒等式 -R = D + H 被破坏');
            end
            Ecur = Ecur + prm.eta_ch*c*dt - d*dt/prm.eta_dis;
            Ecur = min(max(Ecur, prm.E_min), prm.E_max);
            C(t) = c*dt;  D(t) = d*dt;  H(t) = h*dt;  V(t) = v*dt;  E(t) = Ecur;
        end

    case 'plan'
        C = Cadj * dt;  D = Dadj * dt;
        Pnet = Gadj + pv_a + D/dt - C/dt;
        H = max(load_a - Pnet, 0) * dt;
        V = max(Pnet - load_a, 0) * dt;
        for t = 1:T
            Ecur = Ecur + prm.eta_ch*C(t) - D(t)/prm.eta_dis;
            Ecur = min(max(Ecur, prm.E_min), prm.E_max);
            E(t) = Ecur;
        end

    otherwise
        error('未知执行口径：%s', policy);
end

out.C = C;  out.D = D;  out.E = E;  out.H = H;  out.V = V;
out.E0 = E_start;

% 结算：计划（按较小的实际生效量）× 电价 + 差额（下调 0.5 倍、上调 1.5 倍）+ 紧急（5 倍）
out.dP = max(Gadj - Gplan, 0) * dt;                    % 高于原计划的部分 kWh
out.dM = max(Gplan - Gadj, 0) * dt;                    % 低于原计划的部分 kWh
out.cost_plan = sum(price_v .* min(Gplan, Gadj)) * dt;
out.cost_adj  = sum(price_v .* (0.5*out.dM + 1.5*out.dP));      % dM/dP 已是 kWh
out.cost_em   = prm.kappa_em * sum(price_v .* H);
out.cost      = out.cost_plan + out.cost_adj + out.cost_em;

end
