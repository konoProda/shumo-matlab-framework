function out = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, H, policy, verbose)
%FUNC_ROLL_Q2  问题二 全年视野滚动：每天重解剩余视界、只执行当天
%
%   第 d 天 0:00：用【截止 d 之前】的实际数据预测第 d..min(d+H-1,D) 天，在该视界上求
%   计划 LP（连续松弛），但只把第 d 天的计划交给执行层；实际日末储电量传到次日再重解。
%   视界末储电量自由——H 覆盖到年末时，年末自由即题目本身的边界，不引入人为放空。
%
%   输入  price_v / load_m / pv_m / day_list  数据（同 func_read_q2）
%         L1 / PV1    附件1 典型日曲线（冷启动用）
%         prm         参数（含 T / dt / 效率 / 储电量上下限 / 紧急购电倍数）
%         K           同星期回溯周数
%         H           视界天数；>= 剩余天数即"全年视野"
%         policy      执行层口径：'correct'（负载优先，正式）| 'plan'（仅经济层，消融）
%         verbose     （可选）每多少天输出一次进度，默认 0 不输出
%   输出  out         逐日矩阵与费用，字段与 main_q2_forecast 的结果结构一致
%         out.mutex   每天计划解中"同槽同时充放"的槽数（LP 松弛的互斥性自检）
%         out.Eh_end  每天视界末的计划储电量（诊断终末行为用）

if nargin < 11 || isempty(verbose); verbose = 0; end
T = prm.T;  dt = prm.dt;
[D, ~] = size(load_m);
optL = optimoptions('linprog', 'Display', 'off');

out = struct();
fld = {'buy_m','buy_kw','em_m','chg_m','dis_m','curt_m','Eend_m'};
for k = 1:numel(fld); out.(fld{k}) = zeros(D, T); end
out.E0_m = zeros(D,1);  out.cost = zeros(1,D);
out.cost_plan = zeros(1,D);  out.cost_em = zeros(1,D);
out.mutex = zeros(1,D);  out.Eh_end = zeros(D,1);  out.nH = zeros(D,1);

E_now = prm.E_init;
t0 = tic;
for d = 1:D
    dEnd = min(D, d + H - 1);
    nH   = dEnd - d + 1;
    out.nH(d) = nH;

    [Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d);
    Lh = Lh(1:nH,:);  PVh = PVh(1:nH,:);

    [fL, ~, ~, ~, AeqL, beqL, lbL, ubL, auxL] = func_build_q2( ...
        repmat(price_v(:), nH, 1), reshape(Lh.', [], 1), reshape(PVh.', [], 1), ...
        E_now, prm, false);
    [xL, ~, efL] = linprog(fL, [], [], AeqL, beqL, lbL, ubL, optL);
    assert(efL == 1, '第 %d 天视界 LP 未正常收敛（exitflag=%d）', d, efL);

    gx = @(o) xL(o + (0:T-1).');            % 取当天 144 槽（视界首日）的变量
    Gpl = gx(auxL.idx.GL) + gx(auxL.idx.GC);
    out.mutex(d)  = sum(min(gx(auxL.idx.C), gx(auxL.idx.D)) > 1e-6);
    out.Eh_end(d) = xL(auxL.idx.E(end));

    o = func_exec_q2(Gpl, gx(auxL.idx.C), gx(auxL.idx.D), gx(auxL.idx.E), ...
                     load_m(d,:).', pv_m(d,:).', price_v, E_now, prm, policy);

    out.buy_kw(d,:)  = Gpl.';             out.buy_m(d,:)  = (Gpl*dt).';
    out.em_m(d,:)    = o.H.';             out.curt_m(d,:) = o.V.';
    out.chg_m(d,:)   = o.C.';             out.dis_m(d,:)  = o.D.';
    out.E0_m(d)      = E_now;             out.Eend_m(d,:) = o.E.';
    out.cost(d)      = o.cost;            out.cost_plan(d) = o.cost_plan;
    out.cost_em(d)   = o.cost_em;

    E_now = o.E(end);

    if verbose > 0 && mod(d, verbose) == 0
        fprintf('    [%3d/%3d] %s  视界 %3d 天  累计费用 %12.2f 元  累计紧急购电 %10.1f kWh  已用 %.1f min\n', ...
                d, D, char(day_list(d), 'yyyy-MM-dd'), nH, ...
                sum(out.cost(1:d)), sum(out.em_m(1:d,:), 'all'), toc(t0)/60);
    end
end
out.policy = policy;  out.H = H;  out.K = K;  out.time = toc(t0);

end
