function out = func_exec_q2(Gplan, Cplan, Dplan, Eplan, load_a, pv_a, price_v, E_start, prm, policy)
%FUNC_EXEC_Q2  问题二第二部分：给定当天 0:00 计划，按指定口径执行并结算
%
%   两种执行口径（同一份计划，只是储能执行方式不同）：
%     'plan'    储能严格照计划执行（消融对照口径）
%     'correct' 日内储能实时纠偏（正式口径，建模手确认）
%
%   'correct' 规则（逐槽因果，只用当前时段已实现的数据与当前实际 SOC）：
%     R = G^plan_t + PV^act_t - L^act_t
%     R >= 0 : D_t = 0,  C_t = min{ R, P_max, (E_max-E_{t-1})/(eta_c*dt) },  V_t = R-C_t,  H_t = 0
%     R <  0 : C_t = 0,  D_t = min{ -R, P_max, eta_d*(E_{t-1}-E_min)/dt },   H_t = max{-R-D_t,0}
%   库容按实际充放电量更新；不设日末归位目标，日末状态传递到下一天。
%
%   输入  Gplan/Cplan/Dplan/Eplan  T×1 计划功率(kW)与计划储电量(kWh)
%         load_a / pv_a            T×1 当天实际负荷/光伏功率(kW)
%         price_v                  T×1 电价（元/kWh）
%         E_start                  标量 当天起点实际储电量(kWh)
%         prm                      参数结构体
%         policy                   'plan' | 'correct'
%   输出  out.C/D/E/H/V（kWh）、out.cost_plan/cost_em/cost（元）
%         两条口径的 C/D/H/V 在循环内一律以 kW 记账，函数末尾统一乘 dt 转为 kWh。

T = prm.T;  dt = prm.dt;
Gplan = Gplan(:);  load_a = load_a(:);  pv_a = pv_a(:);  price_v = price_v(:);
out = struct();

switch policy
    case 'plan'
        Pnet = Gplan + pv_a + Dplan(:) - Cplan(:);          % 供负荷净功率 kW
        H    = max(load_a - Pnet, 0);
        V    = max(Pnet - load_a, 0);
        out.C = Cplan(:) * dt;
        out.D = Dplan(:) * dt;
        out.E = Eplan(:);

    case 'correct'
        H = zeros(T,1);  V = zeros(T,1);
        C = zeros(T,1);  D = zeros(T,1);  E = zeros(T,1);
        Ecur = E_start;
        for t = 1:T
            R = Gplan(t) + pv_a(t) - load_a(t);
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
            Ecur = min(max(Ecur, prm.E_min), prm.E_max);     % 数值保护
            C(t) = c*dt;  D(t) = d*dt;  H(t) = h;  V(t) = v;  E(t) = Ecur;
        end
        out.C = C;  out.D = D;  out.E = E;

    otherwise
        error('未知执行口径：%s', policy);
end

out.E0 = E_start;
out.H  = H * dt;
out.V  = V * dt;
out.cost_plan = sum(price_v .* Gplan) * dt;
out.cost_em   = prm.kappa_em * sum(price_v .* H) * dt;
out.cost      = out.cost_plan + out.cost_em;

end
