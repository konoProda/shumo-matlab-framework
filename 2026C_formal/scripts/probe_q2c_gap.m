% probe_q2c_gap.m —— 退化（确定性）算例的间隙收敛探针：默认容差 vs 收紧容差
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
d0 = find(day_list == datetime(2025,2,1), 1);
arch = func_resid_q2(load_m, pv_m, L1, PV1, 4, d0);

R = 3;  K = 1;                       % 退化：确定性单情景
cfg = struct('gamma',1,'W',28,'min_days',5,'Kfc',4,'libW',28,'seed',2026,'d_start',d0,'use_bin',true);
optL = optimoptions('linprog','Display','off');

for d = [4 5 6 60 200]
    Lc = load_m(d:d+R-1,:);  PVc = pv_m(d:d+R-1,:);
    [Lsc, PVsc] = func_scen_q2c(arch.eL, arch.ePV, arch.ok, d, K, R, Lc, PVc, 28, 2026);
    [f, ic, A, b, Aeq, beq, lb, ub] = func_build_q2c(price_v, Lsc, PVsc, 6000, prm, true);
    t = tic; [x0, Z0, ef0] = linprog(f, A, b, Aeq, beq, lb, ub, optL); tLP = toc(t);
    t = tic; [~, Z1, ef1, o1] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, x0, ...
              optimoptions('intlinprog','Display','off')); t1 = toc(t);
    t = tic; [~, Z2, ef2, o2] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, x0, ...
              optimoptions('intlinprog','Display','off','RelativeGapTolerance',1e-8, ...
                           'AbsoluteGapTolerance',1e-8,'MaxTime',600)); t2 = toc(t);
    fprintf(['d=%3d | LP  %.2f 元 (%5.2fs) | 默认 %.2f (%5.2fs, gap %.3f, ef=%d) | ' ...
             '收紧 %.2f (%6.2fs, gap %.3f, ef=%d)\n'], ...
            d, Z0, tLP, Z1, t1, o1.absolutegap, ef1, Z2, t2, o2.absolutegap, ef2);
end
