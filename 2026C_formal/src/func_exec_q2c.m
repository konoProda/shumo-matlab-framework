function out = func_exec_q2c(Gplan, load_a, pv_a, price_v, E_start, prm)
%FUNC_EXEC_Q2C  当天实际执行（问题二第三轮，方案文档 §15 + 建模手 C3）
%
%   计划购电 G^plan_{d,t} 当天固定不可改，只允许储能实时响应与紧急购电兜底。
%   逐槽优先级（建模手 C3 原文）：
%     ① 光伏优先供负荷；
%     ② 计划购电补负荷；
%     ③ 仍不足 → 先放电、再紧急购电；
%     ④ 负荷满足后：光伏余电**优先**充储能，其次用**剩余计划购电**充储能；
%     ⑤ 最后：剩余光伏记 V、剩余已购电记 W —— **V 与 W 必须分开**。
%   约束：同槽不得同时充放；储能充电不挤占负荷；紧急购电不给储能充电。
%
%   输入  Gplan    T×1 当天计划购电功率 kW（0:00 锁定）
%         load_a / pv_a  T×1 当天实际负荷 / 光伏 kW
%         price_v  T×1 电价 元/kWh
%         E_start  标量 当天 0:00 实际储电量 kWh
%         prm      参数结构体
%   输出  out.C/D/E/H/V/W（kWh，E 为 kWh）与逐槽分流明细
%         out.cost_plan（按完整计划量计费）/ cost_em / cost

T = prm.T;  dt = prm.dt;
Gplan = Gplan(:);  load_a = load_a(:);  pv_a = pv_a(:);  price_v = price_v(:);

g2load = zeros(T,1);  g2chg = zeros(T,1);  pv2chg = zeros(T,1);
C = zeros(T,1);  D = zeros(T,1);  H = zeros(T,1);  V = zeros(T,1);  W = zeros(T,1);
E = zeros(T,1);
Ecur = E_start;

for t = 1:T
    pv2load = min(pv_a(t), load_a(t));
    lrem    = load_a(t) - pv2load;
    g2load(t) = min(Gplan(t), lrem);
    lrem    = lrem - g2load(t);

    if lrem > 1e-12
        % 缺口：先放电、再紧急购电（此时必然 pv 余电 = 0、计划购电已用尽）
        d = min([lrem, prm.P_max, prm.eta_dis * (Ecur - prm.E_min) / dt]);
        d = max(d, 0);
        D(t) = d;
        H(t) = lrem - d;
        assert(abs(lrem - D(t) - H(t)) < 1e-9, '缺口槽恒等式 -缺口 = D + H 被破坏');
    else
        % 负荷已满足：光伏余电优先充电，其次剩余计划购电
        pvsur = pv_a(t) - pv2load;
        gleft = Gplan(t) - g2load(t);
        room  = (prm.E_max - Ecur) / (prm.eta_ch * dt);
        c1 = min([pvsur, prm.P_max, room]);
        c1 = max(c1, 0);
        c2 = min([gleft, prm.P_max - c1, room - c1]);
        c2 = max(c2, 0);
        pv2chg(t) = c1;   g2chg(t) = c2;
        V(t) = pvsur - c1;
        W(t) = gleft - c2;
        assert(abs(pvsur - c1 - V(t)) < 1e-9, '光伏余电恒等式 P̄V = c1 + V 被破坏');
        assert(abs(gleft - c2 - W(t)) < 1e-9, '剩余计划购电恒等式 = c2 + W 被破坏');
    end

    C(t) = pv2chg(t) + g2chg(t);
    assert(C(t) * D(t) < 1e-12, '同槽同时充放');
    Ecur = Ecur + prm.eta_ch * C(t) * dt - D(t) * dt / prm.eta_dis;
    Ecur = min(max(Ecur, prm.E_min), prm.E_max);
    E(t) = Ecur;
end

out = struct();
out.C = C * dt;  out.D = D * dt;  out.E = E;
out.H = H * dt;  out.V = V * dt;  out.W = W * dt;
out.g2load = g2load;  out.g2chg = g2chg;  out.pv2chg = pv2chg;
out.E0 = E_start;
out.cost_plan = sum(price_v .* Gplan) * dt;              % 计划量全额计费（未用部分不退）
out.cost_em   = prm.kappa_em * sum(price_v .* H) * dt;
out.cost      = out.cost_plan + out.cost_em;

end
