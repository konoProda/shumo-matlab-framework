% probe_q2_toy.m —— 问题二 小规模探针（组内产物，不交付）
% 目的：在缩样数据（T=12 槽 × 3 天）上验证装配与求解链路，秒级完成。
% 检查项：① 多段（跨日）状态衔接装配正确；② 约束残差；③ 紧急购电变量 H^L/H^ch 的取值；
%         ④ LP 松弛下界 <= MILP 最优值；⑤ 互斥性在 LP 解中是否自然成立；
%         ⑥ 逐段独立求解（日末自由）与联合求解的费用关系。

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

%% 缩样数据：3 天 × 12 槽
T = 12;
prm = struct('dt', 1/6, 'eta_ch', 0.90, 'eta_dis', 0.90, 'E_init', 6000, ...
             'E_min', 1200, 'E_max', 10800, 'P_max', 5000, 'kappa_em', 5);

price_day = [0.40; 0.40; 0.50; 0.90; 1.20; 1.30; 1.00; 0.70; 0.50; 0.45; 0.42; 0.40];
load_day  = [3000; 3000; 3500; 4500; 5500; 6000; 5000; 4000; 3500; 3250; 3100; 3000];
% 光伏：第 1 天富余、第 2 天匮乏、第 3 天居中——检验跨日储能的价值
pv_day1 = [0; 0; 0; 2000; 4500; 6000; 5000; 2500; 1000; 0; 0; 0];
pv_day2 = [0; 0; 0; 500; 1500; 2000; 1750; 750; 250; 0; 0; 0];
pv_day3 = [0; 0; 0; 1000; 2500; 3500; 3000; 1500; 500; 0; 0; 0];

D = 3;
price_v = repmat(price_day, D, 1);
load_p  = repmat(load_day,  D, 1);
pv_p    = [pv_day1; pv_day2; pv_day3];
nS = D * T;

opts = optimoptions('intlinprog', 'Display', 'off');

%% ① 联合模型（整段 36 槽，含二元）
[f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q2(price_v, load_p, pv_p, prm.E_init, prm, true);
[xj, Zj, efj, oj] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opts);

%% ② 联合 LP 松弛（无二元、无互斥行）
[f2, ~, ~, ~, Aeq2, beq2, lb2, ub2] = func_build_q2(price_v, load_p, pv_p, prm.E_init, prm, false);
[xl, Zlp] = linprog(f2, [], [], Aeq2, beq2, lb2, ub2, optimoptions('linprog', 'Display', 'off'));

%% ③ 逐日独立求解（日末自由，储能状态跨日传递）
nB = 10 * T;                        % 单日解向量长度（10 块 × T 槽）
Z_day = 0; E_now = prm.E_init; xd = zeros(D * nB, 1);
for d = 1:D
    r = (d-1)*nB + (1:nB);
    [fd, icd, Ad, bd, Aeqd, beqd, lbd, ubd] = ...
        func_build_q2(price_v((d-1)*T+(1:T)), load_p((d-1)*T+(1:T)), pv_p((d-1)*T+(1:T)), E_now, prm, true);
    [xd_d, Zd, efd] = intlinprog(fd, icd, Ad, bd, Aeqd, beqd, lbd, ubd, opts);
    assert(efd == 1, '第 %d 天求解失败', d);
    xd(r) = xd_d;
    E_now = xd_d(7*T + T);          % 当日末储电量 = 下一日起点
    Z_day = Z_day + Zd;
end

%% 约束残差（联合解）
blk = @(xx, k) xx(aux.idx.GL + (k-1)*nS : aux.idx.GL + k*nS - 1);   % 第 k 块
GL = blk(xj,1); GC = blk(xj,2); HL = blk(xj,3); HC = blk(xj,4);
PVC = blk(xj,5); CC = blk(xj,6); DD = blk(xj,7); EE = blk(xj,8); VV = blk(xj,9);

res = zeros(4,1);
res(1) = max(abs(GL + HL + DD - aux.Lbar));                       % (1)
res(2) = max(abs(PVC + GC + HC - CC));                            % (2)
res(3) = max(abs(PVC + VV - aux.PVbar));                          % (3)
Eprev = [prm.E_init; EE(1:end-1)];
res(4) = max(abs(EE - Eprev - prm.eta_ch*prm.dt*CC + DD*prm.dt/prm.eta_dis));

% LP 解的互斥性检查
CCl = xl(5*nS+1 : 6*nS); DDl = xl(6*nS+1 : 7*nS);
n_both = sum(min(CCl, DDl) > 1e-6);

fprintf('=== 问题二 探针（T=%d × D=%d = %d 槽）===\n', T, D, nS);
fprintf('  联合 MILP    : Z = %10.4f 元   exitflag = %d   gap = %.2e\n', Zj, efj, oj.absolutegap);
fprintf('  联合 LP 松弛 : Z = %10.4f 元   （应 <= MILP）\n', Zlp);
fprintf('  逐日独立     : Z = %10.4f 元   （应 >= 联合 MILP，差 %.4f 元）\n', Z_day, Z_day - Zj);
fprintf('\n  约束残差 (1)负荷 %.2e  (2)充电来源 %.2e  (3)光伏剩余 %.2e  (4)状态 %.2e\n', res);
fprintf('  购电/充电    : 购电>0 的槽 %d/%d   充电>0 的槽 %d/%d\n', ...
        sum(GL+GC+HL+HC > 1e-6), nS, sum(CC > 1e-6), nS);
fprintf('  紧急购电     : max H^L = %.4f   max H^ch = %.4f kW\n', max(abs(HL)), max(abs(HC)));
fprintf('  联合解互斥   : max min(C,D) = %.2e\n', max(min(CC, DD)));
fprintf('  LP 解互斥    : 同时充放电的槽数 = %d / %d\n', n_both, nS);
fprintf('\n  首日/末日储电量: %.1f -> %.1f kWh   跨日衔接残差 %.2e\n', ...
        prm.E_init, EE(end), max(abs(Eprev(2:end) - EE(1:end-1))));

ok = all(res < 1e-6) && (Zlp <= Zj + 1e-6) && (Z_day >= Zj - 1e-6) && max(abs(HL)) < 1e-6;
fprintf('\n探针结论：%s\n', string(ok) + " (true = 装配与求解链路正常)");
