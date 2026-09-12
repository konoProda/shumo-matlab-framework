function [f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q3(price_v, load_p, pv_p, Gplan_p, E_start, prm, use_bin)
%FUNC_BUILD_Q3  在问题二标准型上追加"调整量"两块，装配问题三阶段模型
%
%   调整费用（差额结算，C1 = A）：
%       单时段费用 = p*min(G, Gplan) + 0.5p*max(Gplan-G,0) + 1.5p*max(G-Gplan,0)
%   等价地引入 Δ⁺ ≥ 0、Δ⁻ ≥ 0 与一条等式
%       约束 (9)  Δ⁺_s - Δ⁻_s - G^L_s - G^ch_s = -Gplan_s
%   目标系数 1.5p·dt（Δ⁺）、0.5p·dt（Δ⁻）。两个系数均为正，最优解自动取纯表示
%   （不会同时出现 Δ⁺>0 与 Δ⁻>0），故不需二元变量。
%
%   基础约束一律**复用** func_build_q2（等式 4nS 行 + 互斥 2nS 行），本函数只追加两块：
%       DP: n0+1 : n0+nS      DM: n0+nS+1 : n0+2nS      （n0 = func_build_q2 的变量数）
%
%   输入  Gplan_p  nS×1 当天 0:00 原计划购电功率 kW（阶段 1~3 的结算基准，必填）
%         其余同 func_build_q2
%   输出  标准型（intlinprog / linprog）；aux.idx 增加 DP / DM 两个起始下标

[f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q2(price_v, load_p, pv_p, E_start, prm, use_bin);

nS = numel(price_v);
if numel(Gplan_p) ~= nS
    error('Gplan 长度 %d 与段内槽数 %d 不一致', numel(Gplan_p), nS);
end
dt = prm.dt;
n0 = numel(f);

iDP = (n0 + 1 : n0 + nS).';
iDM = (n0 + nS + 1 : n0 + 2*nS).';
aux.idx.DP = iDP(1);
aux.idx.DM = iDM(1);

f2 = zeros(n0 + 2*nS, 1);
f2(1:n0) = f;
f2(iDP) = 1.5 * price_v(:) * dt;
f2(iDM) = 0.5 * price_v(:) * dt;
f = f2;

lb2 = zeros(n0 + 2*nS, 1);  lb2(1:n0) = lb;
ub2 = inf(n0 + 2*nS, 1);    ub2(1:n0) = ub;
lb = lb2;  ub = ub2;

% 约束 (9)：Δ⁺ - Δ⁻ - G^L - G^ch = -Gplan
I = [(1:nS).'; (1:nS).'; (1:nS).'; (1:nS).'];      % 块内行号（拼接到 Aeq 之后）
J = [iDP; iDM; aux.idx.GL + (0:nS-1).'; aux.idx.GC + (0:nS-1).'];
S = [ones(nS,1); -ones(nS,1); -ones(nS,1); -ones(nS,1)];
Aeq = [[Aeq, sparse(size(Aeq,1), 2*nS)]; sparse(I, J, S, nS, n0 + 2*nS)];
beq = [beq; -Gplan_p(:)];

A = [A, sparse(size(A,1), 2*nS)];

end
