% probe_q1_toy.m — 问题一装配探针（组内产物，不交付）
% 目的：在全量 144 槽之前，先验证 func_build_q1 的矩阵装配与求解链路
%   case A：R1 手算算例（建模手确认单 §4），预期最优 89.3827 元
%   case B：真实数据 T=12 缩样（09:00-11:00），验证含弃光/充电的全链路

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

opt = optimoptions('intlinprog', 'Display', 'off');

%% case A —— R1 手算算例
prm = struct('T', 2, 'dt', 1/6, 'eta_ch', 0.90, 'eta_dis', 0.90, ...
             'E_init', 6000, 'E_min', 1200, 'E_max', 10800, 'P_max', 5000);
price = [0.4; 0.5];
load_p = [600; 600];
pv_p = [0; 0];

[f, intcon, A, b, Aeq, beq, lb, ub] = func_build_q1(price, load_p, pv_p, prm);
[x, fval, ef, out] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opt);

T = prm.T;
G = x(1:T); C = x(T+1:2*T); D = x(2*T+1:3*T); E = x(3*T+1:4*T); V = x(4*T+1:5*T);
fprintf('=== case A: R1 手算算例 ===\n');
fprintf('  exitflag=%d  gap=%.2e\n', ef, out.absolutegap);
fprintf('  最优购电费 = %.4f 元   (手算预期 89.3827)\n', fval);
fprintf('  相对误差   = %.3e\n', abs(fval - 89.3827) / 89.3827);
fprintf('  C_1 = %.4f kW  (预期 740.7407)   D_1 = %.4f\n', C(1), D(1));
fprintf('  C_2 = %.4f      D_2 = %.4f     (预期 600)\n', C(2), D(2));
fprintf('  E_0=%.1f  E_T=%.4f  (须相等)\n', prm.E_init, E(end));
fprintf('  u = [%g %g]\n\n', x(5*T+1), x(5*T+2));

%% case B —— 真实数据 T=12 缩样
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
price_all = cell2mat(raw(2:145, 2));
load_all  = cell2mat(raw(2:145, 3));
pv_all    = cell2mat(raw(2:145, 4));

idx = (55:66).';                     % 09:00-11:00
prm.T = numel(idx);
[f, intcon, A, b, Aeq, beq, lb, ub] = func_build_q1(price_all(idx), load_all(idx), pv_all(idx), prm);
[x, fval, ef, out] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opt);

T = prm.T;
G = x(1:T); C = x(T+1:2*T); D = x(2*T+1:3*T); E = x(3*T+1:4*T); V = x(4*T+1:5*T);
fprintf('=== case B: 真实数据 T=%d 缩样（09:00-11:00）===\n', T);
fprintf('  exitflag=%d  gap=%.2e\n', ef, out.absolutegap);
fprintf('  目标值 = %.4f 元\n', fval);
fprintf('  max|平衡残差| = %.3e\n', max(abs(G + pv_all(idx) + D - load_all(idx) - C - V)));
fprintf('  max|状态残差| = %.3e\n', max(abs(diff([prm.E_init; E]) - prm.eta_ch*C*prm.dt + D*prm.dt/prm.eta_dis)));
fprintf('  E 范围 [%.2f, %.2f]  E_T=%.4f  (须=6000)\n', min(E), max(E), E(end));
fprintf('  max min(C,D) = %.3e  (须≈0，无同时充放)\n', max(min(C, D)));
fprintf('  min G = %.3e  (须>=0)\n', min(G));
fprintf('  弃光合计 = %.4f kWh   充电合计 = %.4f kWh   放电合计 = %.4f kWh\n', ...
        sum(V)*prm.dt, sum(C)*prm.dt, sum(D)*prm.dt);
fprintf('  u 全为 0/1: %d\n', all(abs(x(5*T+1:6*T) - round(x(5*T+1:6*T))) < 1e-9));
fprintf('\n探针完成。\n');
