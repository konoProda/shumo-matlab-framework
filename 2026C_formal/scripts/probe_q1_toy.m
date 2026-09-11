% probe_q1_toy.m — 问题一"显式分流"装配探针（组内产物，不交付）
%   case A：R1 手算算例，预期最优 89.3827 元
%   case B：真实数据 T=12 缩样（09:00-11:00），验证全链路

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

[f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q1(price, load_p, pv_p, prm);
[x, fval, ef, out] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opt);

T = prm.T;
blk = @(xx, TT, k) xx((k-1)*TT+1 : k*TT);   % 1=G^L 2=G^ch 3=PV^ch 4=C 5=D 6=E 7=V 8=u
% 注：匿名函数按值捕获，故把 x 与 T 作为实参传入，避免跨算例串用
GL = blk(x,T,1); GC = blk(x,T,2); PVC = blk(x,T,3); C = blk(x,T,4);
D = blk(x,T,5); E = blk(x,T,6); V = blk(x,T,7);
fprintf('=== case A: R1 手算算例 ===\n');
fprintf('  exitflag=%d  gap=%.2e\n', ef, out.absolutegap);
fprintf('  最优购电费 = %.6f 元   (手算预期 %.6f)\n', fval, 0.4*(600+600/0.81)/6);
fprintf('  相对误差   = %.3e\n', abs(fval - 0.4*(600+600/0.81)/6) / (0.4*(600+600/0.81)/6));
fprintf('  C_1 = %.4f kW (预期 740.7407)   D_2 = %.4f (预期 600)\n', C(1), D(2));
fprintf('  G^L = [%.2f %.2f]   G^ch = [%.4f %.4f]   PV^ch = [%.1f %.1f]\n', ...
        GL(1), GL(2), GC(1), GC(2), PVC(1), PVC(2));
fprintf('  E_0=%.1f  E_T=%.4f  (须相等)\n\n', prm.E_init, E(end));

%% case B —— 真实数据 T=12 缩样
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
price_all = cell2mat(raw(2:145, 2));
load_all  = cell2mat(raw(2:145, 3));
pv_all    = cell2mat(raw(2:145, 4));

idx = (55:66).';
prm.T = numel(idx);
[f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q1(price_all(idx), load_all(idx), pv_all(idx), prm);
[x, fval, ef, out] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opt);

T = prm.T; Lb = aux.Lbar; Pb = aux.PVbar;
GL = blk(x,T,1); GC = blk(x,T,2); PVC = blk(x,T,3); C = blk(x,T,4);
D = blk(x,T,5); E = blk(x,T,6); V = blk(x,T,7);
fprintf('=== case B: 真实数据 T=%d 缩样（09:00-11:00）===\n', T);
fprintf('  exitflag=%d  gap=%.2e   目标值 = %.4f 元\n', ef, out.absolutegap, fval);
fprintf('  max|负荷平衡| = %.3e   max|充电来源| = %.3e   max|光伏剩余| = %.3e\n', ...
        max(abs(GL + D - Lb)), max(abs(PVC + GC - C)), max(abs(PVC + V - Pb)));
fprintf('  max|状态残差| = %.3e\n', max(abs(diff([prm.E_init; E]) - prm.eta_ch*C*prm.dt + D*prm.dt/prm.eta_dis)));
fprintf('  E 范围 [%.2f, %.2f]  E_T=%.4f (须=6000)\n', min(E), max(E), E(end));
fprintf('  max min(C,D) = %.3e    min G^L=%.3e  min G^ch=%.3e  min PV^ch=%.3e\n', ...
        max(min(C,D)), min(GL), min(GC), min(PVC));
fprintf('  u 全为 0/1: %d\n', all(abs(blk(x,T,8) - round(blk(x,T,8))) < 1e-9));
fprintf('\n探针完成。\n');
