% probe_q2_correct.m —— 问题二第二部分：日内储能实时纠偏（建模手 C1=B 口径）对照原型
% 组内产物，不交付。
%
% 与「储能严格照计划执行」口径的区别：
%   计划购电量 G^plan 仍由 0:00 的预测 MILP 决定并全天锁定；
%   但计划的充放电功率不再执行，改为按当前时段已实现数据的因果性实时平衡：
%     R_t = G^plan_t + PV^act_t - L^act_t
%     R_t >= 0 ：D=0，C = min(R, P_max, (E_max-E)/(eta_c*dt))，V = R-C，H = 0
%     R_t <  0 ：C=0，D = min(-R, P_max, eta_d*(E-E_min)/dt)，H = max(-R-D, 0)
%   库容按实际充放电更新，日末状态传递到下一天；不设日末归位目标。

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T; D = 365; K = 4; dt = prm.dt;
optM = optimoptions('intlinprog', 'Display', 'off');

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);

%% ① 同星期滚动均值预测（只用 τ < d）
Lhat = zeros(D,T); PVhat = zeros(D,T);
for d = 1:D
    if d == 1
        Lhat(d,:) = L1.';  PVhat(d,:) = PV1.';
    else
        S = (d-7):-7:max(1, d-7*(K-1));  S = S(S >= 1);
        if isempty(S)
            Lhat(d,:) = mean(load_m(1:d-1,:),1);  PVhat(d,:) = mean(pv_m(1:d-1,:),1);
        else
            Lhat(d,:) = mean(load_m(S,:),1);      PVhat(d,:) = mean(pv_m(S,:),1);
        end
    end
end

%% ② 两种执行口径并行
E_plan = prm.E_init;   % 口径甲：储能严格照计划
E_corr = prm.E_init;   % 口径乙：日内实时纠偏
Gplan = zeros(D,T);
cost_plan = zeros(D,1);
Cp = zeros(D,T); Dp = zeros(D,T);
Hp = zeros(D,T); Vp = zeros(D,T);   % 甲：结算
Hc = zeros(D,T); Vc = zeros(D,T); Cc = zeros(D,T); Dc = zeros(D,T); Ec = zeros(D,T); % 乙
for d = 1:D
    % ---- 0:00 计划 MILP（预测数据；紧急购电不入计划）----
    [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
        func_build_q2(price_v, Lhat(d,:).', PVhat(d,:).', E_plan, prm, true);
    ub(aux.idx.HL : aux.idx.HL+T-1) = 0;
    ub(aux.idx.HC : aux.idx.HC+T-1) = 0;
    [x, Z] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
    bx = @(o) x(o : o+T-1);
    GL = bx(aux.idx.GL); GC = bx(aux.idx.GC);
    Ct = bx(aux.idx.C);  Dt = bx(aux.idx.D);  Et = bx(aux.idx.E);
    Gplan(d,:) = (GL + GC).';  cost_plan(d) = Z;
    Cp(d,:) = Ct.';  Dp(d,:) = Dt.';  E_plan = Et(T);

    % ---- 口径甲：照计划执行、实际结算 ----
    Pn = GL + GC + pv_m(d,:).' + Dt - Ct;
    Hp(d,:) = (max(load_m(d,:).' - Pn, 0)*dt).';
    Vp(d,:) = (max(Pn - load_m(d,:).', 0)*dt).';

    % ---- 口径乙：日内实时纠偏 ----
    E = E_corr;
    for t = 1:T
        R = Gplan(d,t) + pv_m(d,t) - load_m(d,t);
        if R >= 0
            C = min([R, prm.P_max, (prm.E_max - E)/(prm.eta_ch*dt)]);
            Dd = 0;  H = 0;  V = R - C;
        else
            Dd = min([-R, prm.P_max, prm.eta_dis*(E - prm.E_min)/dt]);
            C = 0;  H = max(-R - Dd, 0);  V = 0;
        end
        C = max(C, 0);  Dd = max(Dd, 0);
        Cc(d,t) = C*dt;  Dc(d,t) = Dd*dt;  Hc(d,t) = H*dt;  Vc(d,t) = V*dt;
        E = E + prm.eta_ch*C*dt - Dd*dt/prm.eta_dis;
        E = min(max(E, prm.E_min), prm.E_max);
    end
    Ec(d,:) = E;
    E_corr = E;
end

cost_em_p = 5 * sum(price_v(:).' .* (Hp/dt), 2) * dt;
cost_em_c = 5 * sum(price_v(:).' .* (Hc/dt), 2) * dt;
Zp = cost_plan + cost_em_p;
Zc = cost_plan + cost_em_c;
ri = (find(day_list == datetime(2025,2,1)):D).';

fprintf('=== 第二部分：两种执行口径对照 ===\n');
fprintf('%-34s %18s %18s\n', '指标', '甲:储能照计划', '乙:日内实时纠偏');
fprintf('%-34s %18.2f %18.2f\n', '全年总费用(元)', sum(Zp), sum(Zc));
fprintf('%-34s %18.2f %18.2f\n', '  其中：计划购电费', sum(cost_plan), sum(cost_plan));
fprintf('%-34s %18.2f %18.2f\n', '  其中：紧急购电费', sum(cost_em_p), sum(cost_em_c));
fprintf('%-34s %18.2f %18.2f\n', '报送窗口总费用(元)', sum(Zp(ri)), sum(Zc(ri)));
fprintf('%-34s %18.1f %18.1f\n', '紧急购电量(全年 kWh)', sum(Hp(:)), sum(Hc(:)));
fprintf('%-34s %18d %18d\n', '紧急购电出现天数', sum(sum(Hp,2)>1e-6), sum(sum(Hc,2)>1e-6));
fprintf('%-34s %18d %18d\n', '紧急购电出现槽数', sum(Hp(:)>1e-6), sum(Hc(:)>1e-6));
fprintf('%-34s %18.2f %18.2f\n', '最大单槽紧急购电(kWh)', max(Hp(:)), max(Hc(:)));
fprintf('%-34s %18.1f %18.1f\n', '弃光/富余(全年 kWh)', sum(Vp(:)), sum(Vc(:)));
fprintf('%-34s %18.1f %18.1f\n', '储能充电量(全年 kWh)', sum(Cp(:))*dt, sum(Cc(:)));
fprintf('%-34s %18.1f %18.1f\n', '储能放电量(全年 kWh)', sum(Dp(:))*dt, sum(Dc(:)));
fprintf('%-34s %18.1f %18.1f\n', '日末 SOC 均值(kWh)', mean(E_plan*0+nan), mean(Ec(:,T)));

fprintf('\n=== 与第一部分（完美信息基准）的对照 ===\n');
fprintf('  第一部分 全年 %.2f 元 / 窗口 %.2f 元（紧急购电 0）\n', 13735609.64, 12210827.42);
fprintf('  第二部分-甲 全年 %.2f 元 / 窗口 %.2f 元  VoI=%.2f%%\n', ...
        sum(Zp), sum(Zp(ri)), 100*(sum(Zp(ri))-12210827.42)/12210827.42);
fprintf('  第二部分-乙 全年 %.2f 元 / 窗口 %.2f 元  VoI=%.2f%%\n', ...
        sum(Zc), sum(Zc(ri)), 100*(sum(Zc(ri))-12210827.42)/12210827.42);
fprintf('\n  口径乙相对甲的节省 %.2f 元（%.1f%%）\n', sum(Zp)-sum(Zc), 100*(sum(Zp)-sum(Zc))/sum(Zp));
fprintf('  回执中归因的「计划充电诱发紧急购电」368456 kWh 中，纠偏后剩余 %.1f kWh\n', ...
        sum(Hc(:)) - (sum(Hp(:)) - 368456));

%% ③ 紧急购电的时段分布（诊断：纠偏后为何费用不降）
h = floor(((0:T-1)*10)/60) + 1;
Ep_h = zeros(24,1); Ec_h = zeros(24,1); Kp_h = zeros(24,1); Kc_h = zeros(24,1);
for t = 1:T
    Ep_h(h(t)) = Ep_h(h(t)) + sum(Hp(:,t));
    Kp_h(h(t)) = Kp_h(h(t)) + 5*price_v(t)*sum(Hp(:,t));
    Ec_h(h(t)) = Ec_h(h(t)) + sum(Hc(:,t));
    Kc_h(h(t)) = Kc_h(h(t)) + 5*price_v(t)*sum(Hc(:,t));
end
fprintf('\n=== 紧急购电的时段分布（全年 kWh）===\n');
fprintf(' 小时     甲:照计划     乙:实时纠偏   甲单价   乙单价\n');
for k = 1:24
    if Ep_h(k) < 1 && Ec_h(k) < 1, continue; end
    fprintf('%4d %13.0f %13.0f %9.4f %9.4f\n', k-1, Ep_h(k), Ec_h(k), ...
            Kp_h(k)/max(Ep_h(k),eps), Kc_h(k)/max(Ec_h(k),eps));
end
fprintf('  平均单价：甲 %.4f 元/kWh   乙 %.4f 元/kWh\n', ...
        sum(cost_em_p)/sum(Hp(:)), sum(cost_em_c)/sum(Hc(:)));
fprintf('  日末实际 SOC 均值（乙）%.1f kWh\n', mean(Ec(:,T)));
