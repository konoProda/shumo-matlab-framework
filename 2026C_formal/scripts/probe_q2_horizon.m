% probe_q2_horizon.m —— 全年视野滚动的探针验证（组内产物，不交付）
% 在投入全量计算前，验证四件事：
%   P1 逐日模式是否逐位复现改造前的预测（用已保存的预测做回归基准）
%   P2 地平线模式在 τ=d0 处是否等于逐日模式第 d0 天（两种模式的自洽性）
%   P3 地平线模式对全部决策日是否都满足"只引用决策日之前的数据"
%   P4 单次全年视野 LP 的规模、耗时与互斥性；随后滚动若干天看耗时与 SOC 轨迹

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
optL = optimoptions('linprog', 'Display', 'off');

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;  T = prm.T;  dt = prm.dt;
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D = size(load_m, 1);

%% P1 逐日模式回归
fprintf('=== P1 逐日模式回归（对照改造前已保存的预测）===\n');
REF = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_forecast.mat'), ...
           'Lhat', 'PVhat', 'used_max');
[Ld, PVd, ud] = func_forecast_q2(load_m, pv_m, L1, PV1, K);
dL = max(abs(Ld - REF.Lhat), [], 'all');
dP = max(abs(PVd - REF.PVhat), [], 'all');
dU = max(abs(ud - REF.used_max));
fprintf('  负荷预测最大偏差 %.3e kW ；光伏 %.3e kW ；引用日最大偏差 %d\n', dL, dP, dU);
fprintf('  结论：%s\n', string(dL == 0 && dP == 0 && dU == 0));

%% P2 两种模式的自洽性
fprintf('\n=== P2 地平线模式在 τ=d0 处应等于逐日模式 ===\n');
worst = 0;
for d0 = [1 2 7 8 32 100 200 365]
    [Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d0);
    worst = max([worst, max(abs(Lh(1,:) - Ld(d0,:))), max(abs(PVh(1,:) - PVd(d0,:)))]);
end
fprintf('  抽 8 个决策日，第 1 行与逐日模式对应行的最大偏差 %.3e kW\n', worst);
fprintf('  结论：%s\n', string(worst == 0));

%% P3 全决策日的泄漏检查
fprintf('\n=== P3 地平线模式泄漏检查（全部 %d 个决策日）===\n', D);
ok = true; worst_used = 0;
for d0 = 1:D
    [~, ~, um] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d0);
    if any(um >= d0); ok = false; end
    worst_used = max(worst_used, max(um));
end
fprintf('  全部决策日均满足 used_max < d0 ：%s（历史引用日最大到 %d）\n', string(ok), worst_used);

%% P4 单次全年视野 LP：规模、耗时、互斥性
fprintf('\n=== P4 单次全年视野 LP（决策日 d0=1，视界 %d 天）===\n', D);
d0 = 1;
[Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d0);
nH  = D - d0 + 1;
price_h = repmat(price_v(:), nH, 1);
load_h  = reshape(Lh.', [], 1);
pv_h    = reshape(PVh.', [], 1);
t0 = tic;
[fL, ~, ~, ~, AeqL, beqL, lbL, ubL, auxL] = ...
    func_build_q2(price_h, load_h, pv_h, prm.E_init, prm, false);
tB = toc(t0);
t0 = tic;
[xL, ZL, efL] = linprog(fL, [], [], AeqL, beqL, lbL, ubL, optL);
tS = toc(t0);
nS = nH * T;
Ck = xL(auxL.idx.C);  Dk = xL(auxL.idx.D);
mutex = sum(min(Ck, Dk) > 1e-6);
fprintf('  变量 %d（%d 槽 ×%d）等式行 %d；装配 %.2f s，求解 %.2f s，exitflag=%d\n', ...
        numel(fL), nS, 9, size(AeqL,1), tB, tS, efL);
fprintf('  目标值（预测口径、理想视野）%.2f 元\n', ZL);
fprintf('  互斥性：同槽同时充放非零的槽数 %d / %d（%.3f%%）\n', mutex, nS, 100*mutex/nS);
fprintf('  首日计划购电量 %.1f kWh\n', sum(xL(auxL.idx.GL + (0:T-1).') + xL(auxL.idx.GC + (0:T-1).'))*dt);
fprintf('  视界末储电量 %.1f kWh（区间 %.0f~%.0f，自由终端）\n', ...
        xL(auxL.idx.E(end)), prm.E_min, prm.E_max);

%% P5 滚动摸底：前 5 天
fprintf('\n=== P5 滚动前 5 天（每天重解剩余全年）===\n');
Enow = prm.E_init;
for d = 1:5
    [Lh, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d);
    nH = D - d + 1;
    t0 = tic;
    [fL, ~, ~, ~, AeqL, beqL, lbL, ubL, auxL] = func_build_q2( ...
        repmat(price_v(:), nH, 1), reshape(Lh.',[],1), reshape(PVh.',[],1), Enow, prm, false);
    [xL, ZL] = linprog(fL, [], [], AeqL, beqL, lbL, ubL, optL);
    el = toc(t0);
    G1 = xL(auxL.idx.GL + (0:T-1).') + xL(auxL.idx.GC + (0:T-1).');
    fprintf('  d=%3d 视界 %3d 天  耗时 %5.2f s  首日购电 %7.1f kWh  %s\n', ...
            d, nH, el, sum(G1)*dt, day_list(d));
end
