% probe_q2c_size.m —— 7 日滚动 SAA 两阶段 MILP 的规模与耗时探针（决定求解策略）
%
% 只做一件事：按真实数据构造一次 R=7 / K=4 的实例，分别测 LP 松弛与 MILP 的装配与求解耗时。
% 不写任何正式结果。

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);

d = 60;                                  % 任取一个决策日
for R = [1 3 7]
    for K = [4 8]
        Lsc = zeros(R, prm.T, K);  PVsc = zeros(R, prm.T, K);
        for j = 1:R
            Lc = load_m(d+j-1, :).';   PVc = pv_m(d+j-1, :).';
            for w = 1:K
                f = 1 + 0.1*((1:prm.T).' - 1) / prm.T * (mod(w,3)-1);   % 逐槽造一点情景差异（T×1）
                Lsc(j,:,w)  = (Lc .* f).';
                PVsc(j,:,w) = (PVc .* f).';
            end
        end

        tB = tic;
        [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q2c(price_v, Lsc, PVsc, 6000, prm, false);
        tBuild = toc(tB);
        tS = tic;
        [xL, ZL, efL] = linprog(f, A, b, Aeq, beq, lb, ub, optimoptions('linprog','Display','off'));
        tLP = toc(tS);

        tB2 = tic;
        [f2, ic2, A2, b2, Aeq2, beq2, lb2, ub2] = func_build_q2c(price_v, Lsc, PVsc, 6000, prm, true);
        tBuild2 = toc(tB2);
        tS2 = tic;
        [xM, ZM, efM, outM] = intlinprog(f2, ic2, A2, b2, Aeq2, beq2, lb2, ub2, ...
            optimoptions('intlinprog','Display','off','MaxTime',120));
        tMILP = toc(tS2);

        fprintf(['R=%d K=%d | 列 %6d 二元 %5d | 装配 %5.2fs/%5.2fs | ' ...
                 'LP %6.2fs (ef=%d, Z=%.1f) | MILP %7.2fs (ef=%d, Z=%.1f, gap=%.2e)\n'], ...
            R, K, numel(f2), numel(ic2), tBuild, tBuild2, tLP, efL, ZL, ...
            tMILP, efM, ZM, outM.absolutegap);
        if efM == 1 || efM == 2
            nViol = sum(min(xM(aux.blk{1,1}+aux.offB.C*prm.T + (1:prm.T).'), ...
                            xM(aux.blk{1,1}+aux.offB.D*prm.T + (1:prm.T).')) > 1e-6);
            fprintf('            情景1 当日同槽同时充放违例：%d 槽\n', nViol);
        end
    end
end

% 全年外推（仅按本次实测的 MILP 单次耗时估算，取 R=7/K=4）
fprintf('\n提示：全年 365 次求解的耗时 ≈ 365 × MILP 单次耗时，请据此判断策略。\n');
