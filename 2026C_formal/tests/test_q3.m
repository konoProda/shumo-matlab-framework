% test_q3.m —— 问题三一致性测试（组内产物，不交付）
% 验证 src/ 的实现与 decisions_q3.md 的模型口径一致；全部通过后方可进入 /report。
% 结果写 outputs/test_results_q3.mat，日志写 outputs/test_log_q3.txt。
% 滚动类检查一律用前 NTS 天的小切片（秒级），不为测试跑全年。

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

log_path = fullfile(PROJ_ROOT, 'outputs', 'test_log_q3.txt');
if exist(log_path, 'file'); delete(log_path); end
diary(log_path); diary on;

fprintf('===== 问题三 一致性测试 =====\n');
fprintf('时间 %s\n\n', char(datetime('now'), 'yyyy-MM-dd HH:mm:ss'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;  dt = prm.dt;  NTS = 7;
optM = optimoptions('intlinprog', 'Display', 'off');
optL = optimoptions('linprog',    'Display', 'off');
R = struct('item', {{}}, 'pass', [], 'detail', {{}});

[price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D = size(load_m, 1);

%% T1 装配层：func_build_q3 与 func_build_q2 的同源关系
fprintf('T1 装配层\n');
p36 = price_v(109:T);  l36 = load_m(1,109:T).';  v36 = pv_m(1,109:T).';  gp36 = 100*ones(36,1);
[f3b, ic3b, A3b, b3b, Aeq3b, beq3b, lb3b, ub3b, aux3b] = ...
    func_build_q3(p36, l36, v36, gp36, 5000, prm, true);
R = rec(R, 'T1-1 阶段3 装配维度（12 块）', ...
    numel(f3b)==432 && numel(ic3b)==36 && size(Aeq3b,1)==180 && size(Aeq3b,2)==432 && size(A3b,1)==72, ...
    sprintf('n=%d intcon=%d Aeq=%dx%d A=%dx%d', numel(f3b), numel(ic3b), size(Aeq3b), size(A3b)));

[f3n, ic3n, A3n, b3n, Aeq3n, beq3n, lb3n, ub3n, aux3n] = ...
    func_build_q3(p36, l36, v36, gp36, 5000, prm, false);
R = rec(R, 'T1-2 阶段3 连续松弛维度（11 块）', ...
    numel(f3n)==396 && isempty(ic3n) && size(Aeq3n,1)==180 && size(Aeq3n,2)==396, ...
    sprintf('n=%d intcon=%d Aeq=%dx%d', numel(f3n), numel(ic3n), size(Aeq3n)));

% 追加块不改动基础约束
[fb, ~, Ab, ~, Aeqb, beqb, ~, ~, auxb] = func_build_q2(p36, l36, v36, 5000, prm, true);
dev_eq = max(max(abs(full(Aeq3b(1:144, 1:numel(fb)) - Aeqb))));
dev_b  = max(max(abs(full(A3b(:, 1:numel(fb))) - Ab)));
dev_be = max(abs(beq3b(1:144) - beqb));
R = rec(R, 'T1-3 基础约束与 func_build_q2 逐字相同', ...
    dev_eq < 1e-12 && dev_b < 1e-12 && dev_be < 1e-12 && ...
    aux3b.idx.GL==auxb.idx.GL && aux3b.idx.E==auxb.idx.E, ...
    sprintf('Aeq 偏差 %.1e  A 偏差 %.1e  beq 偏差 %.1e', dev_eq, dev_b, dev_be));

% 目标系数：Δ⁺ = 1.5p·dt、Δ⁻ = 0.5p·dt
fDP = f3b(aux3b.idx.DP + (0:35).');  fDM = f3b(aux3b.idx.DM + (0:35).');
R = rec(R, 'T1-4 调整量目标系数', ...
    max(abs(fDP - 1.5*p36*dt)) < 1e-12 && max(abs(fDM - 0.5*p36*dt)) < 1e-12, ...
    sprintf('Δ⁺ 系数 %.6f (=1.5p·dt)  Δ⁻ 系数 %.6f (=0.5p·dt)', fDP(1), fDM(1)));

% 约束 (9) 行：Δ⁺ − Δ⁻ − G^L − G^ch = −Gplan（逐列核对该行系数）
rowAD = 4*36 + 1;
cols = [aux3b.idx.DP, aux3b.idx.DM, aux3b.idx.GL, aux3b.idx.GC];
vals = full(Aeq3b(rowAD, cols));
R = rec(R, 'T1-5 约束(9) 行系数与右端', ...
    isequal(vals, [1 -1 -1 -1]) && abs(beq3b(rowAD) + gp36(1)) < 1e-12, ...
    sprintf('第 1 槽系数 [%g %g %g %g]，右端 %.1f (= -Gplan)', vals, beq3b(rowAD)));

%% T2 插值层：整点 → 10 分钟（C5 = B）
fprintf('\nT2 插值层\n');
fc = [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220 230 240];
a18 = func_interp_q3(fc, 36);                          % 18:00 阶段 36 槽 = 6 小时
R = rec(R, 'T2-1 18:00 阶段取自预报1..6小时', ...
    abs(a18(1)-10) < 1e-12 && abs(a18(6)-(10+5/6*10)) < 1e-12 && ...
    abs(a18(7)-20) < 1e-12 && abs(a18(31)-60) < 1e-12 && abs(a18(36)-68.3333) < 1e-3, ...
    sprintf('槽1=%.4f(预报1小时) 槽7=%.4f(预报2小时) 槽31=%.4f(预报6小时) 槽36=%.4f(向预报7小时过渡)', ...
            a18(1), a18(7), a18(31), a18(36)));

% 篡改超出该阶段所需范围的预报值，结果必须不受影响
% 18:00 阶段用到预报1..7小时（末槽需 P_7），故篡改 8..24 小时应无影响
fcX = fc;  fcX(8:24) = 99999;
c18 = func_interp_q3(fcX, 36);   c18r = func_interp_q3(fc, 36);
R = rec(R, 'T2-2 后续阶段不引用范围外的预报', ...
    max(abs(c18-c18r)) < 1e-12, ...
    sprintf('篡改预报8..24小时后 18:00 阶段偏差 %.1e kW', max(abs(c18-c18r))));

% 12:00 阶段用预报1..13小时，篡改 14..24 应无影响；而用"整天口径"取 13..24 就会变
fcY = fc;  fcY(14:24) = 99999;
a12 = func_interp_q3(fcY, 72);   a12r = func_interp_q3(fc, 72);
b12 = func_interp_q3(fcY, T);    b12r = func_interp_q3(fc, T);
R = rec(R, 'T2-3 阶段口径 vs 整天口径可区分', ...
    max(abs(a12-a12r)) < 1e-12 && max(abs(b12-b12r)) > 1e3, ...
    sprintf('阶段口径偏差 %.1e kW（应为 0）；整天口径偏差 %.1f kW（应显著）', ...
            max(abs(a12-a12r)), max(abs(b12-b12r))));

fcF = 100*ones(1,24);
full_ = func_interp_q3(fcF, T);
R = rec(R, 'T2-4 常数预报 → 常数插值', max(abs(full_ - 100)) < 1e-12, ...
    sprintf('全天最大偏差 %.1e kW', max(abs(full_ - 100))));

% 末槽需 P_25 而数据只给到 24 小时，按 P_25 = P_24 平延（不越界、不外推）
fcL = [10*ones(1,23), 40];
e0 = func_interp_q3(fcL, T);
R = rec(R, 'T2-5 末槽按 P_25 = P_24 平延', ...
    abs(e0(144) - 40) < 1e-12 && abs(e0(139) - 40) < 1e-12 && abs(e0(138) - 35) < 1e-12, ...
    sprintf('槽144=%.4f(=%d) 槽139=%.4f 槽138=%.4f(向预报24小时过渡)', ...
            e0(144), fcL(24), e0(139), e0(138)));

% 与实际光伏的支撑一致性：夜间区间预报为零
pv0 = func_interp_q3(fc3(1,1,:), T);
R = rec(R, 'T2-6 首日 0:00 预报夜间段为零', ...
    max(abs(pv0(1:4*6))) < 1e-12 && max(abs(pv0(19*6+1:T))) < 1e-12, ...
    sprintf('[00:00,04:00) 最大 %.1e ，[19:00,24:00) 最大 %.1e kW', ...
            max(abs(pv0(1:24))), max(abs(pv0(115:T)))));

%% T3 结算口径（A8 / A9，差额结算）
fprintf('\nT3 结算口径\n');
Gp = 100*ones(6,1);  Ga = 60*ones(6,1);   C0 = 50*ones(6,1);  D0 = zeros(6,1);
o = func_exec_q3(Gp, Ga, C0, D0, zeros(6,1), zeros(6,1), 1.0*ones(6,1), 6000, prm, 'plan');
R = rec(R, 'T3-1 下调：计划费按 min 计、差额 0.5 倍', ...
    abs(o.cost_plan - 60*6*dt) < 1e-9 && abs(o.cost_adj - 0.5*40*6*dt) < 1e-9, ...
    sprintf('计划费 %.4f 元（期望 %.4f）  调整费 %.4f 元（期望 %.4f）', ...
            o.cost_plan, 60*6*dt, o.cost_adj, 0.5*40*6*dt));
R = rec(R, 'T3-2 下调不采用"全额付费后加罚"读法', ...
    o.cost_plan + o.cost_adj < 100*6*dt, ...
    sprintf('实际合计 %.4f 元 < 全额计费 %.4f 元', o.cost_plan + o.cost_adj, 100*6*dt));

ob = func_exec_q3(Gp, 150*ones(6,1), C0, D0, zeros(6,1), zeros(6,1), 1.0*ones(6,1), 6000, prm, 'plan');
R = rec(R, 'T3-3 上调：超出部分按 1.5 倍', ...
    abs(ob.cost_plan - 100*6*dt) < 1e-9 && abs(ob.cost_adj - 1.5*50*6*dt) < 1e-9, ...
    sprintf('计划费 %.4f  调整费 %.4f 元（期望 %.4f）', ob.cost_plan, ob.cost_adj, 1.5*50*6*dt));

oz = func_exec_q3(Gp, Gp, C0, D0, zeros(6,1), zeros(6,1), 1.0*ones(6,1), 6000, prm, 'plan');
R = rec(R, 'T3-4 不调整时调整费为零', abs(oz.cost_adj) < 1e-12 && abs(oz.cost_plan - 100*6*dt) < 1e-9, ...
    sprintf('调整费 %.1e 元', oz.cost_adj));

R = rec(R, 'T3-5 三项相加 = 总费用', ...
    max(abs([o.cost, ob.cost] - [o.cost_plan+o.cost_adj+o.cost_em, ob.cost_plan+ob.cost_adj+ob.cost_em])) < 1e-9, ...
    sprintf('闭合偏差 %.1e 元', max(abs(o.cost - (o.cost_plan+o.cost_adj+o.cost_em)))));

% LP 自动取纯表示
[f,ic,A,b,Aeq,beq,lb,ub,aux] = func_build_q3(price_v(109:T), load_m(1,109:T).', ...
    pv_m(1,109:T).', 20*ones(36,1), 6000, prm, false);
[x,~,ef] = linprog(f,[],[],Aeq,beq,lb,ub,optL);
dP = x(aux.idx.DP + (0:35).');  dM = x(aux.idx.DM + (0:35).');
R = rec(R, 'T3-6 调整量纯表示（LP 自动）', ef==1 && max(dP.*dM) < 1e-12, ...
    sprintf('max(Δ⁺·Δ⁻) = %.1e', max(dP.*dM)));

%% T4 执行层构造性检查（C4 = A 物理层）
fprintf('\nT4 执行层\n');
l8 = [4000; 4000; 6000; 6000; 4000; 4000; 2000; 2000];
v8 = [3000; 3000; 1000; 1000; 3000; 3000; 8000; 8000];
g8 = [1000; 1000; 4000; 4000; 1000; 1000; 0; 0];
p8 = 0.5*ones(8,1);
oc = func_exec_q3(g8, g8, zeros(8,1), zeros(8,1), l8, v8, p8, 6000, prm, 'correct');
net = g8 + v8 - l8;
R = rec(R, 'T4-1 富余槽恒等式 R = C + V', ...
    max(abs(net(net>=0) - (oc.C(net>=0)/dt + oc.V(net>=0)/dt))) < 1e-9, ...
    sprintf('残差 %.1e kW', max(abs(net(net>=0) - (oc.C(net>=0)/dt + oc.V(net>=0)/dt)))));
R = rec(R, 'T4-2 缺口槽恒等式 -R = D + H', ...
    max(abs(-net(net<0) - (oc.D(net<0)/dt + oc.H(net<0)/dt))) < 1e-9, ...
    sprintf('残差 %.1e kW', max(abs(-net(net<0) - (oc.D(net<0)/dt + oc.H(net<0)/dt)))));

% 满储且全程富余：只能弃光，不得再充
lS = 2000*ones(8,1);  vS = 8000*ones(8,1);  gS = zeros(8,1);
om = func_exec_q3(gS, gS, zeros(8,1), zeros(8,1), lS, vS, p8, prm.E_max, prm, 'correct');
R = rec(R, 'T4-3 满储时富余全部弃光', ...
    max(om.E) <= prm.E_max + 1e-9 && max(om.C) < 1e-9 && abs(sum(om.V) - 6000*8*dt) < 1e-9, ...
    sprintf('MaxE %.1f  充电合计 %.1e kWh  弃光合计 %.1f kWh', ...
            max(om.E), sum(om.C), sum(om.V)));

% 空储后缺口只能紧急购电
oe = func_exec_q3(g8, g8, zeros(8,1), zeros(8,1), l8, v8, p8, prm.E_min, prm, 'correct');
R = rec(R, 'T4-4 储电量不越下限', min(oe.E) >= prm.E_min - 1e-9 && max(oe.D) < 1e-9 && sum(oe.H) > 0, ...
    sprintf('末值 %.1f kWh  MinE %.1f  紧急购电合计 %.1f kWh', oe.E(end), min(oe.E), sum(oe.H)));

% 不带纠偏口径：照计划的充放电量执行
oP = func_exec_q3(g8, g8, 300*ones(8,1), zeros(8,1), l8, v8, p8, 6000, prm, 'plan');
R = rec(R, 'T4-5 plan 口径照计划充放电', ...
    max(abs(oP.C/dt - 300)) < 1e-12 && max(abs(oP.D)) < 1e-12, ...
    sprintf('充电功率恒 %.0f kW', oP.C(1)/dt));

%% T5 阶段推进与拼接（小切片滚动）
fprintf('\nT5 阶段推进与拼接（前 %d 天）\n', NTS);
sl = 1:NTS;
rS3 = func_roll_q3(price_v, load_m(sl,:), pv_m(sl,:), day_list(sl), fc3(sl,:,:), ...
                   L1, PV1, prm, 4, Inf, 'correct', [true true true true], 0);
rS0 = func_roll_q3(price_v, load_m(sl,:), pv_m(sl,:), day_list(sl), fc3(sl,:,:), ...
                   L1, PV1, prm, 4, Inf, 'correct', [true false false false], 0);
rS1 = func_roll_q3(price_v, load_m(sl,:), pv_m(sl,:), day_list(sl), fc3(sl,:,:), ...
                   L1, PV1, prm, 4, Inf, 'correct', [true true false false], 0);

R = rec(R, 'T5-1 S0：生效购电量 = 原计划', max(abs(rS0.adj_m(:) - rS0.plan_m(:))) < 1e-12, ...
    sprintf('最大偏差 %.1e kWh', max(abs(rS0.adj_m(:) - rS0.plan_m(:)))));
R = rec(R, 'T5-2 S0：调整费恒为 0', max(abs(rS0.cost_adj)) < 1e-12, ...
    sprintf('max %.1e 元', max(abs(rS0.cost_adj))));
d36 = max(abs(rS1.adj_m(:,1:36) - rS1.plan_m(:,1:36)), [], 'all');
dT  = max(abs(rS1.adj_m(:,37:T) - rS1.plan_m(:,37:T)), [], 'all');
R = rec(R, 'T5-3 S1 只改 6:00 之后、不动 0:00-6:00', d36 < 1e-12 && dT > 0, ...
    sprintf('前 36 槽偏差 %.1e；37 槽后偏差 %.1f kWh', d36, dT));

% 0:00-6:00 段未被任何后续阶段覆盖，生效值应恰为阶段 0 计划
dS3 = max(abs(rS3.adj_m(:,1:36) - rS3.plan_m(:,1:36)), [], 'all');
R = rec(R, 'T5-4 四阶段拼接：生效值按最后覆盖阶段取', dS3 < 1e-12, ...
    sprintf('0:00-6:00 段与阶段0 计划偏差 %.1e kWh', dS3));

% 储能跨日传递
R = rec(R, 'T5-5 日末储电量传递到次日 0:00', ...
    max(abs(rS3.E0_m(2:end) - rS3.Eend_m(1:end-1, T))) < 1e-9, ...
    sprintf('最大偏差 %.1e kWh', max(abs(rS3.E0_m(2:end) - rS3.Eend_m(1:end-1,T)))));

% 首日四策略共用同一份 0:00 计划（初值相同）
R = rec(R, 'T5-6 首日 0:00 计划与策略无关', ...
    max(abs(rS3.Gplan_kw(1,:) - rS0.Gplan_kw(1,:))) < 1e-9, ...
    sprintf('S3 与 S0 首日计划最大偏差 %.1e kW', max(abs(rS3.Gplan_kw(1,:) - rS0.Gplan_kw(1,:)))));

%% T6 全天守恒与结构性质
fprintf('\nT6 守恒与结构性质\n');
net3 = rS3.Gadj_kw + pv_m(sl,:) - load_m(sl,:);
Cp = rS3.chg_m/dt;  Dp = rS3.dis_m/dt;  Vp = rS3.curt_m/dt;  Hp = rS3.em_m/dt;
sPlus = net3 >= 0;
R = rec(R, 'T6-1 逐槽能量平衡（富余/缺口两式）', ...
    max(abs(net3(sPlus) - (Cp(sPlus)+Vp(sPlus)))) < 1e-9 && ...
    max(abs(net3(~sPlus) + (Dp(~sPlus)+Hp(~sPlus)))) < 1e-9, ...
    sprintf('残差 %.1e / %.1e kW', max(abs(net3(sPlus)-(Cp(sPlus)+Vp(sPlus)))), ...
            max(abs(net3(~sPlus)+(Dp(~sPlus)+Hp(~sPlus))))));
Erec = [rS3.E0_m, rS3.Eend_m(:,1:T-1)] + prm.eta_ch*rS3.chg_m - rS3.dis_m/prm.eta_dis;
R = rec(R, 'T6-2 储能递推式', max(abs(Erec(:) - rS3.Eend_m(:))) < 1e-9, ...
    sprintf('最大偏差 %.1e kWh', max(abs(Erec(:) - rS3.Eend_m(:)))));
R = rec(R, 'T6-3 储电量始终在 [1200,10800]', ...
    min(rS3.Eend_m(:)) >= prm.E_min-1e-6 && max(rS3.Eend_m(:)) <= prm.E_max+1e-6, ...
    sprintf('实测 [%.1f, %.1f] kWh', min(rS3.Eend_m(:)), max(rS3.Eend_m(:))));
R = rec(R, 'T6-4 互斥性：阶段0 LP 与阶段1~3 MILP 均无同槽充放', ...
    sum(rS3.mutex) == 0 && sum(rS3.mutex_s(:)) == 0, ...
    sprintf('阶段0 %d 槽；阶段1~3 %d 槽', sum(rS3.mutex), sum(rS3.mutex_s(:))));
R = rec(R, 'T6-5 计划层紧急购电恒为 0', ...
    sum(rS3.planH) < 1e-6 && sum(rS3.planH_s) < 1e-6, ...
    sprintf('阶段0 %.1e kW，阶段1~3 %.1e kW', sum(rS3.planH), sum(rS3.planH_s)));
R = rec(R, 'T6-6 调整量纯表示（滚动结果）', max(rS3.dP_m(:).*rS3.dM_m(:)) < 1e-12, ...
    sprintf('max(Δ⁺·Δ⁻) = %.1e', max(rS3.dP_m(:).*rS3.dM_m(:))));
R = rec(R, 'T6-7 费用自洽（三项之和）', ...
    max(abs(rS3.cost - (rS3.cost_plan + rS3.cost_adj + rS3.cost_em))) < 1e-9, ...
    sprintf('最大偏差 %.1e 元', max(abs(rS3.cost-(rS3.cost_plan+rS3.cost_adj+rS3.cost_em)))));

%% T7 信息无泄漏（因果性构造检验）
fprintf('\nT7 信息无泄漏\n');
pvX = pv_m(sl,:);
pvX(1, 37:T) = pvX(1, 37:T) * 0.5;              % 篡改首日 6:00 之后的**实际**光伏
rX = func_roll_q3(price_v, load_m(sl,:), pvX, day_list(sl), fc3(sl,:,:), ...
                  L1, PV1, prm, 4, Inf, 'correct', [true true true true], 0);
R = rec(R, 'T7-1 阶段0 计划不受当日实际光伏影响', ...
    max(abs(rX.Gplan_kw(1,:) - rS3.Gplan_kw(1,:))) < 1e-9, ...
    sprintf('篡改后首日计划偏差 %.1e kW', max(abs(rX.Gplan_kw(1,:) - rS3.Gplan_kw(1,:)))));
R = rec(R, 'T7-2 阶段1 的解不受 6:00 之后实际光伏影响', ...
    max(abs(rX.Gadj_kw(1,37:72) - rS3.Gadj_kw(1,37:72))) < 1e-9, ...
    sprintf('6:00-12:00 段偏差 %.1e kW', max(abs(rX.Gadj_kw(1,37:72) - rS3.Gadj_kw(1,37:72)))));
R = rec(R, 'T7-3 篡改确实生效（后段/次日受影响）', ...
    max(abs(rX.Gadj_kw(1,109:T) - rS3.Gadj_kw(1,109:T))) > 0 || ...
    max(abs(rX.cost(2:end) - rS3.cost(2:end))) > 1e-6, ...
    sprintf('末段偏差 %.1f kW，次日费用差 %.1f 元', ...
            max(abs(rX.Gadj_kw(1,109:T) - rS3.Gadj_kw(1,109:T))), abs(rX.cost(2)-rS3.cost(2))));

% 阶段 0 的远端预测只用严格早于决策日的实际数据（沿用 func_forecast_q2 的自检）
[Lh, PVh, usedMax] = func_forecast_q2(load_m, pv_m, L1, PV1, 4, 50);
R = rec(R, 'T7-4 远端预测无未来信息（引用日 < 决策日）', all(usedMax < 50), ...
    sprintf('第 50 天引用最晚历史日 = %d', max(usedMax)));

%% T8 导出层（构造性：小切片写临时文件后核对网格）
fprintf('\nT8 导出层\n');
tmp_x = fullfile(PROJ_ROOT, 'outputs', 'tmp_test_q3.xlsx');
resT = rS3;
tabT = func_write_q3(resT, prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result3.xlsx'), tmp_x);
R = rec(R, 'T8-1 result3 四张表均可写出', ...
    exist(tmp_x, 'file') == 2 && numel(tabT.t2_E0) == 4, ...
    sprintf('文件大小 %d 字节', dir(tmp_x).bytes));

% 计划购电量表的逐槽网格与日期-槽号配对
sh1 = readcell(tmp_x, 'Sheet', '计划购电量');
dt1 = sh1(2:1+NTS, 1);
sl1 = cell2mat(sh1(2:1+NTS, 2:1+T));
dev1 = max(abs(sl1 - resT.plan_m(1:NTS,:)), [], 'all');
R = rec(R, 'T8-2 计划购电量表：逐槽值与模型一致', ...
    isequal(size(sl1), [NTS T]) && dev1 < 1e-9, ...
    sprintf('%d 行 × %d 列，逐槽最大偏差 %.1e kWh', size(sl1,1), size(sl1,2), dev1));

shA = readcell(tmp_x, 'Sheet', '调整购电量');
slA = cell2mat(shA(2:1+NTS, 2:1+T));
devA = max(abs(slA - resT.adj_m(1:NTS,:)), [], 'all');
R = rec(R, 'T8-3 调整购电量表填最终生效值', ...
    devA < 1e-9, sprintf('逐槽最大偏差 %.1e kWh', devA));

sh2 = readcell(tmp_x, 'Sheet', '充放电量');
chg2 = cell2mat(sh2(2:1+NTS*6, 3));
dis2 = cell2mat(sh2(2:1+NTS*6, 4));
R = rec(R, 'T8-4 充放电量表按 4 小时块汇总', ...
    abs(chg2(1) - sum(resT.chg_m(1,1:24))) < 1e-9 && abs(dis2(7) - sum(resT.dis_m(2,1:24))) < 1e-9, ...
    sprintf('第1日 0:00-4:00 充 %.1f kWh（期望 %.1f）', chg2(1), sum(resT.chg_m(1,1:24))));

R = rec(R, 'T8-5 逐日期行与模型逐行配对', ...
    numel(dt1) == NTS && max(abs(sl1(end,:) - resT.plan_m(NTS,:))) < 1e-9, ...
    sprintf('%d 个日期行，末行与模型一致', numel(dt1)));
delete(tmp_x);

%% 汇总
nP = sum(R.pass); nT = numel(R.pass);
fprintf('\n===== 测试汇总：%d / %d 项通过 =====\n', nP, nT);
if nP == nT
    fprintf('结论：全部通过，可进入 /report\n');
else
    fprintf('结论：**存在未通过项**，请编程手介入\n');
    for k = find(~R.pass).'
        fprintf('  未通过：%s  %s\n', R.item{k}, R.detail{k});
    end
end
R.summary = sprintf('%d/%d', nP, nT);
R.time = char(datetime('now'), 'yyyy-MM-dd HH:mm:ss');
save(fullfile(PROJ_ROOT, 'outputs', 'test_results_q3.mat'), 'R');
diary off;
disp('测试日志已写入 outputs/test_log_q3.txt');

% ---------------------------------------------------------------- 局部函数
function R = rec(R, name, ok, txt)
R.item{end+1}   = name;
R.pass(end+1)   = ok;
R.detail{end+1} = txt;
if ok; tag = 'PASS'; else; tag = 'FAIL'; end
fprintf('  [%s] %-38s %s\n', tag, name, txt);
end
