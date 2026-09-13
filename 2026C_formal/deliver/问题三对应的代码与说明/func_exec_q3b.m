function out = func_exec_q3b(Gplan, load_a, pv_a, price_v, E_start, prm)
%FUNC_EXEC_Q3B  实际执行层（按段执行；问题三/问题四共用）
%
%   与问题二 func_exec_q2c 的规则**逐条相同**，只是允许一次执行一段（段长 = numel(Gplan)），
%   以便按"求解—执行—更新—再求解"的顺序推进并取得各阶段边界处的真实储电量（裁决 N2）。
%   不修改 func_exec_q2c 本身（问题二产物保持有效）。
%
%   逐槽优先级（裁决 X1，继承问题二建模手 C3）：
%     ① 光伏优先供负荷；② 当前生效正常购电补负荷；③ 仍不足先放电、再紧急购电；
%     ④ 负荷满足后光伏余电**优先**充储能；⑤ 其次用剩余正常购电充储能；
%     ⑥ 剩余光伏记 V、剩余已购电记 W（**分开**）；⑦ 同槽不得同时充放；⑧ 紧急购电不给储能充电。
%
%   输入  Gplan    n×1 该段的**最终生效**正常购电功率 kW（本段内已锁定）
%         load_a / pv_a  n×1 该段实际负荷 / 光伏 kW
%         price_v  n×1 电价 元/kWh
%         E_start  标量 该段起点的真实储电量 kWh
%         prm      参数结构体
%   输出  out.C/D/H/V/W（kWh，已乘 Δt）与 out.E（kWh，逐槽）
%         out.g2load/g2chg/pv2chg 逐槽分流明细（kW）
%         out.cost_plan（按完整计划量计费）/ cost_em / cost

dt = prm.dt;
Gplan = Gplan(:);  load_a = load_a(:);  pv_a = pv_a(:);  price_v = price_v(:);
n = numel(Gplan);
assert(numel(load_a) == n && numel(pv_a) == n && numel(price_v) == n, '执行层输入长度不一致');

g2load = zeros(n,1);  g2chg = zeros(n,1);  pv2chg = zeros(n,1);
C = zeros(n,1);  D = zeros(n,1);  H = zeros(n,1);  V = zeros(n,1);  W = zeros(n,1);
E = zeros(n,1);
Ecur = E_start;

for t = 1:n
    pv2load = min(pv_a(t), load_a(t));
    lrem    = load_a(t) - pv2load;
    g2load(t) = min(Gplan(t), lrem);
    lrem    = lrem - g2load(t);

    if lrem > 1e-12
        % 缺口：先放电、再紧急购电（此时必然光伏余电为 0、计划购电已用尽）
        d = min([lrem, prm.P_max, prm.eta_dis * (Ecur - prm.E_min) / dt]);
        d = max(d, 0);
        D(t) = d;
        H(t) = lrem - d;
        assert(abs(lrem - D(t) - H(t)) < 1e-9, '缺口槽恒等式被破坏');
    else
        pvsur = pv_a(t) - pv2load;
        gleft = Gplan(t) - g2load(t);
        room  = (prm.E_max - Ecur) / (prm.eta_ch * dt);
        c1 = max(min([pvsur, prm.P_max, room]), 0);
        c2 = max(min([gleft, prm.P_max - c1, room - c1]), 0);
        pv2chg(t) = c1;   g2chg(t) = c2;
        V(t) = pvsur - c1;
        W(t) = gleft - c2;
        assert(abs(pvsur - c1 - V(t)) < 1e-9, '光伏余电恒等式被破坏');
        assert(abs(gleft - c2 - W(t)) < 1e-9, '剩余计划购电恒等式被破坏');
    end

    C(t) = pv2chg(t) + g2chg(t);
    assert(C(t) * D(t) < 1e-12, '同槽同时充放');
    Ecur = Ecur + prm.eta_ch * C(t) * dt - D(t) * dt / prm.eta_dis;
    Ecur = min(max(Ecur, prm.E_min), prm.E_max);
    E(t) = Ecur;
end

out = struct();
out.C = C * dt;  out.D = D * dt;  out.E = E;      % 电量口径（kWh）
out.H = H * dt;  out.V = V * dt;  out.W = W * dt;
out.g2load = g2load;  out.g2chg = g2chg;  out.pv2chg = pv2chg;
out.E0 = E_start;
out.cost_plan = sum(price_v .* Gplan) * dt;       % 计划量全额计费（未用部分不退）
out.cost_em   = prm.kappa_em * sum(price_v .* H) * dt;
out.cost      = out.cost_plan + out.cost_em;

end
