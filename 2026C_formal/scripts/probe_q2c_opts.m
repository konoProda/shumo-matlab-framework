% probe_q2c_opts.m —— intlinprog 选项调优探针（R=7/K=4，看能否用热启动压缩耗时）
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[price_v, load_m, pv_m, ~] = func_read_q2(PROJ_ROOT);
R = 7;  K = 4;  d = 60;
Lsc = zeros(R,prm.T,K);  PVsc = zeros(R,prm.T,K);
for j = 1:R
    Lc = load_m(d+j-1,:).';  PVc = pv_m(d+j-1,:).';
    for w = 1:K
        f = 1 + 0.1*((1:prm.T).'-1)/prm.T*(mod(w,3)-1);
        Lsc(j,:,w) = (Lc.*f).';  PVsc(j,:,w) = (PVc.*f).';
    end
end
[f, ic, A, b, Aeq, beq, lb, ub] = func_build_q2c(price_v, Lsc, PVsc, 6000, prm, true);

optL = optimoptions('linprog','Display','off');
t = tic; [x0, Z0, ef0] = linprog(f, A, b, Aeq, beq, lb, ub, optL); tLP = toc(t);
u0 = x0(ic);
fprintf('LP: %.2fs  Z=%.2f  ef=%d  u 的小数分量数 %d\n', tLP, Z0, ef0, nnz(abs(u0 - round(u0)) > 1e-6));

cases = { '默认',        optimoptions('intlinprog','Display','off') ;
          '热启动 x0',   optimoptions('intlinprog','Display','off') ;
          '只给二元热启动', optimoptions('intlinprog','Display','off') };
for k = 1:size(cases,1)
    if k == 1
        t = tic; [x, Z, ef, o] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, cases{k,2}); tt = toc(t);
    else
        t = tic; [x, Z, ef, o] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, x0, cases{k,2}); tt = toc(t);
    end
    fprintf('%-16s %7.2fs  Z=%.2f  ef=%d  gap=%.1e\n', cases{k,1}, tt, Z, ef, o.absolutegap);
end
