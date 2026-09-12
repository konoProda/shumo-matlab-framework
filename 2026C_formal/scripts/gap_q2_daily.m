% gap_q2_daily.m —— 逐日「LP 松弛下界 vs MILP 最优」对照（组内产物，不交付）
% 用途：量化整数互斥约束的代价，为「解已达全局最优」提供逐日证据。
% 输出：outputs/q2_gap_daily.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;
optM = optimoptions('intlinprog', 'Display', 'off');
optL = optimoptions('linprog',    'Display', 'off');

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = size(load_m, 1);

Zm = zeros(D,1); Zl = zeros(D,1); E_now = prm.E_init;
for d = 1:D
    E0d = E_now;                                  % 当日起点储电量：MILP 与 LP 必须一致
    [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
        func_build_q2(price_v, load_m(d,:).', pv_m(d,:).', E0d, prm, true);
    [x, Zm(d)] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
    E_now = x(aux.idx.E + T - 1);

    [fL, ~, ~, ~, AeqL, beqL, lbL, ubL] = ...
        func_build_q2(price_v, load_m(d,:).', pv_m(d,:).', E0d, prm, false);
    [~, Zl(d)] = linprog(fL, [], [], AeqL, beqL, lbL, ubL, optL);
end

ri = find(day_list == datetime(2025,2,1)) : D;
tab = table(day_list(ri), Zm(ri), Zl(ri), Zm(ri) - Zl(ri), ...
    'VariableNames', {'date','Z_milp','Z_lp','gap'});
writetable(tab, fullfile(PROJ_ROOT, 'outputs', 'q2_gap_daily.csv'));

fprintf('=== 逐日 LP 下界 vs MILP ===\n');
fprintf('  窗口合计  ΣZ_MILP = %.4f 元   ΣZ_LP = %.4f 元   差 %.4f 元（相对 %.2e）\n', ...
        sum(Zm(ri)), sum(Zl(ri)), sum(Zm(ri)) - sum(Zl(ri)), (sum(Zm(ri))-sum(Zl(ri)))/sum(Zm(ri)));
gv = Zm(ri) - Zl(ri);
[gmax, gi] = max(gv);
fprintf('  单日最大差 %.4f 元（出现在 %s）\n', gmax, char(day_list(ri(gi)), 'yyyy-MM-dd'));
fprintf('  无差异的天数 %d / %d\n', sum(abs(Zm(ri)-Zl(ri)) < 1e-6), numel(ri));
fprintf('  已写入 outputs/q2_gap_daily.csv\n');
