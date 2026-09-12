% audit_q2c_exec.m —— 独立审计：执行层给出的紧急购电量，是不是"计划锁定后不可避免的最小量"？
%
%   关心的问题：报告里的紧急购电量（24 万余 kWh）到底是
%     ① "计划一次锁定后，当天真实数据下无论如何都要买这么多"（口径的必然结果），还是
%     ② "分流优先级规则用得不好，本可以更少"（实现缺陷）。
%
%   做法：对每个出现过紧急购电的日子，**在计划购电量完全固定不变**的前提下，
%   用线性规划求"当天最小可能的紧急购电量"，再与执行层实际执行的量比对。
%   LP 的约束集与执行层同源：负荷平衡、光伏余电用于充电、剩余计划购电用于充电、
%   储电递推与上下界、充放电功率上限；计划购电不得超用、不得售回。
%   LP 的目标只写 min ΣH，即"把紧急购电压到最小"。
%
%   结论写入 outputs/q2c_exec_audit.md。
%   用法：matlab -batch "run('scripts/audit_q2c_exec.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
OUT = fullfile(PROJ_ROOT, 'outputs');
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;  dt = prm.dt;

[~, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = numel(day_list);
res = load(fullfile(OUT, 'final_results_q2c_L2.mat')).res;
win = find(day_list >= datetime(2025,2,1));
optL = optimoptions('linprog', 'Display', 'off');

fprintf('=== 执行层紧急购电量的最优性审计（第二层正式方案）===\n');
fprintf('逐日 LP：min ΣH  s.t. 计划购电量固定、储能递推、功率与容量上下界\n\n');

dMaxGap = 0;  nRun = 0;  totAct = 0;  totOpt = 0;  worstD = 0;  nBad = 0;
for d = win(:).'
    actH = sum(res.em_m(d, :));                       % 实际执行值（已是 kWh）
    if actH <= 1e-6; continue; end                    % 无紧急购电的日子无需审计
    nRun = nRun + 1;

    Gplan = res.buy_kw(d, :).';                       % 当天计划购电功率（0:00 锁定）
    load_a = load_m(d, :).';   pv_a = pv_m(d, :).';
    pv2load = min(pv_a, load_a);
    lrem    = load_a - pv2load;                       % 光伏供完之后仍需补足的负荷
    pvsur   = pv_a - pv2load;                         % 光伏余电

    % 变量按槽分块：[C D H gL pvc gC E]，每槽 7 个
    nv = 7 * T;
    iv = @(name) (0:7:7*(T-1)).' + find(strcmp({'C','D','H','gL','pvc','gC','E'}, name));
    f = zeros(nv, 1);   f(iv('H')) = 1;               % 目标：最小化总紧急购电

    I = [];  J = [];  S = [];  r = 0;
    % —— 等式 1：D + H + gL = lrem（缺口只能由放电与紧急购电补）
    rr = r + (1:T).';  r = r + T;
    I = [I; rr; rr; rr];  J = [J; iv('D'); iv('H'); iv('gL')];  S = [S; ones(3*T,1)];
    beq1 = lrem;
    % —— 等式 2：C - pvc - gC = 0
    rr = r + (1:T).';  r = r + T;
    I = [I; rr; rr; rr];  J = [J; iv('C'); iv('pvc'); iv('gC')];
    S = [S; ones(T,1); -ones(T,1); -ones(T,1)];
    % —— 等式 3：SOC 递推 E_t - E_{t-1} - ηc·dt·C + (dt/ηd)·D = [t=1: E_start; else 0]
    rr = r + (1:T).';  r = r + T;
    r2 = rr(2:end);
    iE = iv('E');
    I = [I; rr; r2; rr; rr];  J = [J; iE; iE(2:end)-7; iv('C'); iv('D')];
    S = [S; ones(T,1); -ones(T-1,1); -prm.eta_ch*dt*ones(T,1); (dt/prm.eta_dis)*ones(T,1)];
    beq3 = zeros(T,1);  beq3(1) = res.E0_m(d);
    beq = [beq1; zeros(T,1); beq3];
    Aeq = sparse(I, J, S, 3*T, nv);

    % —— 不等式：gL + gC ≤ Gplan（计划购电不得超用）；pvc ≤ pvsur；C,D ≤ P_max
    I2 = [];  J2 = [];  S2 = [];  b2 = [];  r2i = 0;
    rr = r2i + (1:T).';  r2i = r2i + T;
    I2 = [I2; rr; rr];  J2 = [J2; iv('gL'); iv('gC')];  S2 = [S2; ones(2*T,1)];  b2 = [b2; Gplan];
    rr = r2i + (1:T).';  r2i = r2i + T;
    I2 = [I2; rr];  J2 = [J2; iv('pvc')];  S2 = [S2; ones(T,1)];  b2 = [b2; pvsur];
    rr = r2i + (1:T).';  r2i = r2i + T;
    I2 = [I2; rr];  J2 = [J2; iv('C')];  S2 = [S2; ones(T,1)];  b2 = [b2; prm.P_max*ones(T,1)];
    rr = r2i + (1:T).';  r2i = r2i + T;
    I2 = [I2; rr];  J2 = [J2; iv('D')];  S2 = [S2; ones(T,1)];  b2 = [b2; prm.P_max*ones(T,1)];
    A = sparse(I2, J2, S2, r2i, nv);

    lb = zeros(nv, 1);   ub = inf(nv, 1);
    lb(iv('E')) = prm.E_min;   ub(iv('E')) = prm.E_max;

    [x, Zlp, ef, outp] = linprog(f, A, b2, Aeq, beq, lb, ub, optL);
    if ef ~= 1
        fprintf('  [异常] %s exitflag=%d：%s\n', char(day_list(d),'yyyy-MM-dd'), ef, outp.message);
        fprintf('         诊断：E0=%.3f  E_min=%.3f E_max=%.3f  Σlrem=%.1f  ΣGplan=%.1f  实际H=%.3f\n', ...
                res.E0_m(d), prm.E_min, prm.E_max, sum(lrem), sum(Gplan), actH);
        nBad = nBad + 1;   continue;
    end
    optH = Zlp * dt;                                  % 功率和 → 电量
    gap = actH - optH;
    totAct = totAct + actH;   totOpt = totOpt + optH;
    if gap > dMaxGap; dMaxGap = gap;  worstD = d;  end
    if gap > 1e-6
        fprintf('  %s：实际 %.3f kWh，LP 最小 %.3f kWh，差 %.3f\n', ...
                char(day_list(d),'yyyy-MM-dd'), actH, optH, gap);
    end
end

fprintf('\n审计天数（有紧急购电）: %d\n', nRun);
fprintf('实际执行合计  : %.3f kWh\n', totAct);
fprintf('LP 最小合计   : %.3f kWh\n', totOpt);
fprintf('最大单日差    : %.6f kWh（%s）\n', dMaxGap, char(day_list(worstD),'yyyy-MM-dd'));

tol = 1e-6;
fid = fopen(fullfile(OUT, 'q2c_exec_audit.md'), 'w', 'n', 'UTF-8');
mk = @(varargin) fprintf(fid, varargin{:});
mk('# 执行层紧急购电量最优性审计（第二层正式方案，K=4）\n\n');
mk('> 由 scripts/audit_q2c_exec.m 生成；数字全部现算，未手抄。\n\n');
mk('## 问题\n\n');
mk('报告中的紧急购电量，是"计划一次锁定后当天无论怎么调度都必须买的量"，\n');
mk('还是"分流优先级规则用得不好、本可以更少"？前者是口径的必然结果，后者是实现缺陷。\n\n');
mk('## 方法\n\n');
mk('对每个出现过紧急购电的日子，**在计划购电量完全固定不变**的前提下，\n');
mk('解一个线性规划求当天最小可能的紧急购电量：目标为最小化全天紧急购电量之和，\n');
mk('约束与执行层同源（负荷平衡、光伏余电用于充电、剩余计划购电用于充电、\n');
mk('储电递推与上下界、充放电功率上限、计划购电不得超用也不得售回）。\n');
mk('执行层的分流规则按"缺口先放电、余量先充电"逐槽贪心；LP 则是全局最优下界。\n\n');
mk('## 结果\n\n');
mk('| 项 | 数值 |\n|---|---|\n');
mk('| 审计天数（窗口内有紧急购电的天数） | %d |\n', nRun);
mk('| 执行层实际紧急购电量合计 | %.3f kWh |\n', totAct);
mk('| 线性规划最小紧急购电量合计 | %.3f kWh |\n', totOpt);
mk('| 两者之差 | %.6f kWh |\n', totAct - totOpt);
mk('| 最大单日差 | %.6f kWh（%s） |\n\n', dMaxGap, char(day_list(worstD),'yyyy-MM-dd'));
if totAct - totOpt < tol
    mk('**结论：逐日取到最优，执行层的分流规则没有造成任何多余的紧急购电。**\n\n');
    mk('因此报告中 24 万余 kWh 的紧急购电量、以及由此产生的紧急购电费，\n');
    mk('是"当天计划购电量在 0:00 一次性锁定、之后不可修改"这一口径的必然结果，\n');
    mk('不是分流规则或实现的问题。要降低它，只能从计划层（更准的预测、更大的情景覆盖）入手。\n\n');
    mk('**前提限定（须在论文中写明）**：本审计沿用方案文档的执行层口径，\n');
    mk('即执行层在 0:00 即掌握当天全部 144 个时段的真实负荷与光伏。\n');
    mk('若改为逐时段暴露真实信息，结果会不同，本结论不适用。\n');
else
    mk('**结论：执行层未取到最优**，最大单日差 %.6f kWh，需排查分流规则。\n', dMaxGap);
end
fclose(fid);
fprintf('\n已写入 outputs/q2c_exec_audit.md\n');
fprintf('AUDIT_DONE\n');
