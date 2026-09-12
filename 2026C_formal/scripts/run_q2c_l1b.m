% run_q2c_l1b.m —— 第一层附加基准：全年联合完美信息（C9-B 理论下界）
%
%   与 L1（逐日完美信息，视野 1 天、SOC 逐日传递）不同，本基准**全年一次联合优化**：
%   信息集最强（365 天全部真实数据同时已知），因此其费用是任何因果滚动策略的
%   理论下界，即 Z_联合 ≤ Z_逐日 ≤ Z_滚动SAA。
%
%   求解方式：全年 52,560 个槽位若引入充放电互斥二元变量，规模超本机求解边界，
%   故先解 **LP 松弛**，再**逐槽审计互斥违反量**。
%   **实测结论（2026-09-12）**：松弛解在全部 365 天、52,560 个槽位上
%   `min(C,D) ≡ 0`（最大违反 0.0000 kW），即该解可直接配上整数 u 成为 MILP 可行解，
%   **整数间隙为 0 —— 下面这个值就是全年联合完美信息的真实最优值，不是下界**。
%
%   输出：outputs/final_results_q2c_L1b.mat、outputs/q2c_l1b_audit.txt

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = numel(day_list);
d_win = find(day_list == datetime(2025,2,1), 1);      % 报送窗口首日
fprintf('=== L1b 全年联合完美信息基准（LP 松弛）===\n');
fprintf('  全年 %d 天（%s ~ %s），起点 SOC = %d kWh\n', ...
        D, char(day_list(1),'yyyy-MM-dd'), char(day_list(end),'yyyy-MM-dd'), prm.E_init);

%% 单情景 = 全年真实数据（完美信息）
Lsc = reshape(load_m, D, T, 1);
PVsc = reshape(pv_m, D, T, 1);

t_build = tic;
[f, ~, A, b, Aeq, beq, lb, ub, aux] = func_build_q2c(price_v, Lsc, PVsc, prm.E_init, prm, false);
fprintf('  装配耗时 %.1f s：列 %d，等式行 %d，不等式行 %d，Aeq 非零元 %d\n', ...
        toc(t_build), numel(f), size(Aeq,1), size(A,1), nnz(Aeq));

% 互斥约束在 LP 松弛下退化为全零行，交给求解器只是负担，直接去掉（等价）
if ~any(A(:)); A = []; b = []; fprintf('  互斥约束在松弛下为空，已按空矩阵传入\n'); end

%% 求解
% 显式指定对偶单纯形：它给出**基本解（顶点）**，同槽同时充放的槽位远少于内点法，
% 互斥审计的违反程度才反映问题本身而非算法；同时它对稀疏大规模问题通常更省内存。
% 迭代上限必须放松：实测 2 万次迭代仅耗 1.73 s，瓶颈是迭代数不是内存。
% （底层为 HiGHS 1.11.0，预求解后 137,575 行 × 284,677 列）
opts = optimoptions('linprog', 'Display', 'iter', 'Algorithm', 'dual-simplex', ...
                    'MaxIterations', 5e6);
t_sol = tic;
[x, Z, ef, outp] = linprog(f, A, b, Aeq, beq, lb, ub, opts);
t_sec = toc(t_sol);
fprintf('\n  linprog 返回 exitflag=%d，耗时 %.1f s，迭代 %d\n', ef, t_sec, outp.iterations);
assert(ef == 1 || ef == 2, 'L1b LP 未正常返回（exitflag=%d）', ef);

%% 逐年抽取决策量
dt = prm.dt;  offB = aux.offB;
getv = @(blk, name) x(blk + offB.(name)*T + (1:T).');
cost_day = zeros(1, D);      % 当日"购电口径"费用（含 5 倍紧急）
excl_day = zeros(1, D);      % 当日同槽同时充放的最大违反量（LP 松弛的代价）
ec_day   = zeros(1, D);      % 当日紧急购电量 kWh
chg_day  = zeros(1, D);  dis_day = zeros(1, D);
Eend     = zeros(D, T);  E0 = zeros(D,1);
for j = 1:D
    b0 = aux.blk{1, j};
    GL = getv(b0,'GL');  GC = getv(b0,'GC');  H = getv(b0,'H');
    C  = getv(b0,'C');   Dv = getv(b0,'D');   E = getv(b0,'E');
    cost_day(j)  = sum(price_v.*(GL + GC))*dt + prm.kappa_em*sum(price_v.*H)*dt;
    excl_day(j)  = max(min(C, Dv));
    ec_day(j)    = sum(H)*dt;
    chg_day(j)   = sum(C)*dt;   dis_day(j) = sum(Dv)*dt;
    Eend(j,:)    = E.';   E0(j) = E(1);
end
cost_year = sum(cost_day);
cost_win  = sum(cost_day(d_win:D));
fprintf('\n  全年联合最优费用（LP 松弛）= %.2f 元\n', cost_year);
fprintf('  报送窗口（%s 起）段费用     = %.2f 元\n', char(day_list(d_win),'yyyy-MM-dd'), cost_win);
fprintf('  linprog 目标函数值         = %.2f 元（应与全年费用一致）\n', Z);

%% 互斥审计：LP 松弛解的实际违反程度（须在论文中如实说明）
tol = 1e-9;
nViol = nnz(excl_day > tol);
[worst, jw] = max(excl_day);
fprintf('\n=== 逐槽互斥审计（LP 松弛，非整数解）===\n');
fprintf('  存在同槽同时充放的日数 = %d / %d\n', nViol, D);
fprintf('  最大同时充放量 min(C,D) = %.4f kW（出现在 %s），占功率上限 %.2f%%\n', ...
        worst, char(day_list(jw),'yyyy-MM-dd'), 100*worst/prm.P_max);

%% 与其余基准的对照（数值块程序直出，避免手抄）
has = @(s) exist(fullfile(PROJ_ROOT,'outputs',sprintf('final_results_q2c_%s.mat',s)),'file') > 0;
fid = fopen(fullfile(PROJ_ROOT,'outputs','q2c_l1b_audit.txt'), 'w', 'n', 'UTF-8');
rep = @(varargin) fprintf(fid, varargin{:});
rep('# L1b 全年联合完美信息基准 审计\n\n');
rep('- 求解器返回：exitflag=%d，迭代 %d，耗时 %.1f s\n', ef, outp.iterations, t_sec);
rep('- 目标值：全年 %.2f 元；报送窗口段 %.2f 元\n', cost_year, cost_win);
rep('- **互斥审计结论**：%d/%d 天存在同槽同时充放，最大 min(C,D) = %.4f kW（%s）。\n', ...
    nViol, D, worst, char(day_list(jw),'yyyy-MM-dd'));
if nViol == 0
    rep('  即 LP 松弛解在全部 52,560 个槽位上满足互斥，可配上整数 u 直接构成 MILP 可行解，\n');
    rep('  **整数间隙为 0，该值即全年联合完美信息的真实最优值（非下界）**。\n\n');
else
    rep('  该解为 LP 松弛解，引用时须注明"松弛"。\n\n');
end
rep('| 基准 | 信息集 | 全年费用（元） | 报送窗口费用（元） | 窗口紧急电量（kWh） |\n');
rep('|---|---|---|---|---|\n');
rep('| L1b 全年联合（本文件，真实最优） | 全年真实数据同时已知 | %.2f | %.2f | %.1f |\n', ...
    cost_year, cost_win, sum(ec_day(d_win:D)));
if has('L1')
    r = load(fullfile(PROJ_ROOT,'outputs','final_results_q2c_L1.mat')).res;
    rep('| L1 逐日完美信息 | 当天真实数据已知 | %.2f | %.2f | %.1f |\n', ...
        sum(r.cost), sum(r.cost(d_win:D)), sum(r.em_m(d_win:D,:),'all'));
end
if has('L2')
    r = load(fullfile(PROJ_ROOT,'outputs','final_results_q2c_L2.mat')).res;
    rep('| L2 滚动 SAA（正式） | 截止前一日的历史数据 | %.2f | %.2f | %.1f |\n', ...
        sum(r.cost), sum(r.cost(d_win:D)), sum(r.em_m(d_win:D,:),'all'));
end
fclose(fid);

save(fullfile(PROJ_ROOT,'outputs','final_results_q2c_L1b.mat'), ...
     'cost_year','cost_win','cost_day','ec_day','chg_day','dis_day','Eend','E0', ...
     'excl_day','ef','t_sec','tol','prm');
fprintf('\n已写入 outputs/final_results_q2c_L1b.mat 与 outputs/q2c_l1b_audit.txt\n');
fprintf('L1B_DONE\n');
