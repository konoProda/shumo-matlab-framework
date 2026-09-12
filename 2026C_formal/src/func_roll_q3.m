function out = func_roll_q3(price_v, load_m, pv_m, day_list, fc3, L1, PV1, prm, K, H, policy, stages, verbose)
%FUNC_ROLL_Q3  问题三 全年滚动：每天 0:00 全年视野定计划，6:00/12:00/18:00 分段调整
%
%   单日流程（段边界 = 槽号 1 / 37 / 73 / 109 / 145，对应 0/6/12/18/24 时）：
%     （1）阶段 0：以当天实际负载、附件3 当天 0:00 预报、次日起自建预测，在 H 天视野上
%         解计划 LP（连续松弛），取当天 144 槽作为原计划 G^plan；
%     （2）按段推进：执行段 k 得到该段末的实际储电量；若启用阶段 k+1，则以该实际储电量
%         为初值、以附件3 在 τ_{k+1} 发布的预报重解 τ_{k+1} 至当日 24:00 的剩余时段，
%         其解覆盖 G^adj 与计划充放电的对应区间（后续阶段会再覆盖其后的段）。
%     （3）最终生效购电量按"最后一个覆盖该槽的阶段"拼装；每个槽与当日 0:00 原计划比较。
%
%   输入  price_v / load_m / pv_m / day_list  数据（同 func_read_q2）
%         fc3          D×4×24 附件3 光伏预报（同 func_read_q3）
%         L1 / PV1     附件1 典型日曲线（自建预测的冷启动用）
%         prm          参数（含 T / dt / 效率 / 储电量上下限 / 紧急购电倍数）
%         K            同星期回溯周数
%         H            阶段 0 的视野天数；>= 剩余天数即全年视野
%         policy       执行层口径：'correct'（负载优先，正式）| 'plan'（照计划，消融）
%         stages       1×4 逻辑，逐位标记 0:00 / 6:00 / 12:00 / 18:00 四个阶段是否使用；
%                      **第 1 位仅作标注**——0:00 计划阶段是题面要求的必做环节，恒被执行，
%                      求解分支只读第 2~4 位（即 6:00 / 12:00 / 18:00 三个调整阶段）
%         verbose      （可选）每多少天打印一次进度，默认 0
%   输出  out          逐日矩阵与费用
%         out.mutex    阶段 0 计划解中同槽同时充放的槽数（LP 松弛的互斥性自检）
%         out.mutex_s  阶段 1~3 的对应计数（精确 MILP，应恒为 0）

if nargin < 13 || isempty(verbose); verbose = 0; end
assert(stages(1), '阶段 0（0:00 制定计划）为必做阶段，stages(1) 必须为 true');
T = prm.T;  dt = prm.dt;
[D, ~] = size(load_m);
seg = [1 37 73 109 T+1];
optL = optimoptions('linprog', 'Display', 'off');
optM = optimoptions('intlinprog', 'Display', 'off');

fld = {'plan_m','adj_m','dP_m','dM_m','em_m','chg_m','dis_m','curt_m','Eend_m','Gplan_kw','Gadj_kw'};
out = struct();
for k = 1:numel(fld); out.(fld{k}) = zeros(D, T); end
out.E0_m = zeros(D,1);
out.cost = zeros(1,D); out.cost_plan = zeros(1,D);
out.cost_adj = zeros(1,D); out.cost_em = zeros(1,D);
out.mutex = zeros(1,D);  out.mutex_s = zeros(D,3);
out.planH = zeros(1,D);  out.planH_s = zeros(1,D);   % 计划层紧急购电（应恒为 0，被正常购电支配）
out.stages = stages;  out.policy = policy;  out.H = H;  out.K = K;
out.day_list = day_list;
out.rep_idx = (find(day_list == datetime(2025,2,1)):D).';   % 报送窗口（2025-02-01 起）

E_now = prm.E_init;
t0 = tic;
for d = 1:D
    % ---------------- 阶段 0：全年视野计划 ----------------
    dEnd = min(D, d + H - 1);  nH = dEnd - d + 1;
    [Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d);
    Lh = Lh(1:nH, :);  PVh = PVh(1:nH, :);
    Lh(1,:)  = load_m(d,:);                              % 当天负载：已知
    PVh(1,:) = func_interp_q3(fc3(d,1,:), T);             % 当天光伏：题面 0:00 预报

    [f0, ~, ~, ~, Aeq0, beq0, lb0, ub0, aux0] = func_build_q2( ...
        repmat(price_v(:), nH, 1), reshape(Lh.', [], 1), reshape(PVh.', [], 1), ...
        E_now, prm, false);
    [x0, ~, ef0] = linprog(f0, [], [], Aeq0, beq0, lb0, ub0, optL);
    assert(ef0 == 1, '第 %d 天阶段 0 未正常收敛（exitflag=%d）', d, ef0);

    g0 = @(o) x0(o + (0:T-1).');
    Gplan = g0(aux0.idx.GL) + g0(aux0.idx.GC);
    Cadj  = g0(aux0.idx.C);
    Dadj  = g0(aux0.idx.D);
    Gadj  = Gplan;
    out.mutex(d) = sum(min(Cadj, Dadj) > 1e-6);
    out.planH(d) = sum(g0(aux0.idx.HL) + g0(aux0.idx.HC));

    % ---------------- 分段执行 + 后续阶段调整 ----------------
    XC = zeros(T,1);  XD = zeros(T,1);  XH = zeros(T,1);  XV = zeros(T,1);  XE = zeros(T,1);
    XdP = zeros(T,1); XdM = zeros(T,1);
    cplan = 0;  cadj = 0;  cem = 0;
    Ecur = E_now;

    for k = 0:3
        s = seg(k+1);  e = seg(k+2) - 1;  idx = (s:e).';
        o = func_exec_q3(Gplan(idx), Gadj(idx), Cadj(idx), Dadj(idx), ...
                         load_m(d, idx).', pv_m(d, idx).', price_v(idx), Ecur, prm, policy);
        XC(idx) = o.C;  XD(idx) = o.D;  XH(idx) = o.H;  XV(idx) = o.V;  XE(idx) = o.E;
        XdP(idx) = o.dP;  XdM(idx) = o.dM;
        cplan = cplan + o.cost_plan;  cadj = cadj + o.cost_adj;  cem = cem + o.cost_em;
        Ecur = o.E(end);

        % 求解下一阶段（若启用）：只重解当天剩余时段，初值取当前实际储电量
        if k < 3 && stages(k+2)
            s2 = seg(k+2);  n2 = T - s2 + 1;
            pv_hat = func_interp_q3(fc3(d, k+2, :), n2);
            [f3, ic3, A3, b3, Aeq3, beq3, lb3, ub3, aux3] = func_build_q3( ...
                price_v(s2:T), load_m(d, s2:T).', pv_hat.', Gplan(s2:T), Ecur, prm, true);
            [x3, ~, ef3] = intlinprog(f3, ic3, A3, b3, Aeq3, beq3, lb3, ub3, optM);
            assert(ef3 == 1, '第 %d 天阶段 %d 未正常收敛（exitflag=%d）', d, k+1, ef3);
            gi = @(o_) x3(o_ + (0:n2-1).');
            Gadj(s2:T) = gi(aux3.idx.GL) + gi(aux3.idx.GC);
            Cadj(s2:T) = gi(aux3.idx.C);
            Dadj(s2:T) = gi(aux3.idx.D);
            out.mutex_s(d, k+1) = sum(min(gi(aux3.idx.C), gi(aux3.idx.D)) > 1e-6);
            out.planH_s(d) = out.planH_s(d) + sum(gi(aux3.idx.HL) + gi(aux3.idx.HC));
        end
    end

    % ---------------- 记录 ----------------
    Erec = [E_now; XE(1:end-1)];
    assert(max(abs(Erec + prm.eta_ch*XC - XD/prm.eta_dis - XE)) < 1e-6, ...
           '第 %d 天储能递推式不成立', d);

    out.plan_m(d,:)   = Gplan.' * dt;
    out.adj_m(d,:)    = Gadj.' * dt;
    out.Gplan_kw(d,:) = Gplan.';       out.Gadj_kw(d,:) = Gadj.';
    out.dP_m(d,:) = XdP.';             out.dM_m(d,:) = XdM.';
    out.em_m(d,:) = XH.';              out.curt_m(d,:) = XV.';
    out.chg_m(d,:) = XC.';             out.dis_m(d,:) = XD.';
    out.E0_m(d) = E_now;               out.Eend_m(d,:) = XE.';
    out.cost_plan(d) = cplan;  out.cost_adj(d) = cadj;  out.cost_em(d) = cem;
    out.cost(d) = cplan + cadj + cem;

    E_now = XE(end);

    if verbose > 0 && mod(d, verbose) == 0
        fprintf('    [%3d/%3d] %s  视界 %3d 天  累计费用 %12.2f 元  调整费 %10.2f  紧急购电 %10.1f kWh  已用 %.1f min\n', ...
                d, D, char(day_list(d), 'yyyy-MM-dd'), nH, ...
                sum(out.cost(1:d)), sum(out.cost_adj(1:d)), sum(out.em_m(1:d,:), 'all'), toc(t0)/60);
    end
end
out.time = toc(t0);

end
