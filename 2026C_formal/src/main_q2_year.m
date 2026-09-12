% main_q2_year.m —— 问题二：全年联合优化基准（理想基准，非可执行策略）
% 与 main_q2.m 同模型，但把全年所有时段作为一个整体求解，储能状态全年连续；
% 因含"同时段不同时充放电"的整数变量共 4.8 万个、远超本机求解边界，
% 故求解其连续松弛，再检验互斥性是否自然成立：
%   若成立，则该连续解即为整数模型的全局最优解（互斥约束不改变最优值）。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T', 144, 'dt', 1/6, 'eta_ch', 0.90, 'eta_dis', 0.90, 'E_init', 6000, ...
             'E_min', 1200, 'E_max', 10800, 'P_max', 5000, 'kappa_em', 5);

%% 数据与展平（按槽顺序铺开：第 d 天第 t 槽 → 位置 (d-1)T + t）
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = size(load_m, 1);
T = prm.T;
nS = D * T;
price_all = repmat(price_v, D, 1);
load_all  = reshape(load_m.', [], 1);
pv_all    = reshape(pv_m.',  [], 1);

%% 装配全年连续松弛（无二元变量、无互斥约束行）
t_b = tic;
[f, ~, ~, ~, Aeq, beq, lb, ub, aux] = func_build_q2(price_all, load_all, pv_all, prm.E_init, prm, false);
t_build = toc(t_b);
fprintf('=== 问题二 全年联合模型（连续松弛）===\n');
fprintf('  时段 %d 天 × %d 槽 = %d 槽\n', D, T, nS);
fprintf('  变量 %d（全连续）  等式 %d 行  非零元 %d\n', numel(f), size(Aeq,1), nnz(Aeq));
fprintf('  装配耗时 %.2f s\n', t_build);

%% 求解
opts = optimoptions('linprog', 'Display', 'final', 'MaxIterations', 1e5);
t_s = tic;
[x, Z, ef, out] = linprog(f, [], [], Aeq, beq, lb, ub, opts);
t_solve = toc(t_s);
assert(ef > 0, 'linprog 未正常收敛，exitflag = %d（%s）', ef, out.message);

%% 取解并检验互斥性
bx = @(off) x(off : off + nS - 1);
o = aux.idx;
GL = bx(o.GL); GC = bx(o.GC); HL = bx(o.HL); HC = bx(o.HC);
PVC = bx(o.PVC); CC = bx(o.C); DD = bx(o.D); EE = bx(o.E); VV = bx(o.V);
n_both = sum(min(CC, DD) > 1e-6);

fprintf('\n=== 求解结果 ===\n');
fprintf('  退出标记 exitflag = %d   迭代 %d 次   耗时 %.1f s\n', ef, out.iterations, t_solve);
fprintf('  全年购电费 Z = %.4f 元\n', Z);
fprintf('  **互斥性检验**：同时充放电的槽 %d / %d（max min(C,D) = %.3e kW）\n', ...
        n_both, nS, max(min(CC, DD)));
if n_both == 0
    fprintf('  结论：连续松弛解满足互斥约束 → 该解即整数模型的全局最优解\n');
else
    fprintf('  结论：互斥性**未自然成立**，Z 仅可作为整数模型的下界\n');
end

%% 年度与逐日汇总
dt = prm.dt;
E0 = [prm.E_init; EE(1:end-1)];
rep = struct();
rep.cost = Z;
rep.buy  = (sum(GL) + sum(GC)) * dt;
rep.em   = (sum(HL) + sum(HC)) * dt;
rep.pv_load = sum(aux.PVL) * dt;
rep.pv_chg  = sum(PVC) * dt;
rep.curt    = sum(VV) * dt;
rep.chg_tot = sum(CC) * dt;
rep.dis_tot = sum(DD) * dt;
rep.g_load  = sum(GL) * dt;   rep.g_chg = sum(GC) * dt;
rep.h_load  = sum(HL) * dt;   rep.h_chg = sum(HC) * dt;
fprintf('\n  购电量 %.2f kWh（其中紧急 %.4f）\n', rep.buy, rep.em);
fprintf('  光伏供负载 %.2f   光伏充电 %.2f   弃光 %.2f kWh\n', rep.pv_load, rep.pv_chg, rep.curt);
fprintf('  储能充电 %.2f   放电 %.2f   等效循环 %.2f 次\n', rep.chg_tot, rep.dis_tot, rep.dis_tot/(prm.E_max-prm.E_min));
fprintf('  储电量区间 %.2f ~ %.2f kWh（限值 %.0f ~ %.0f）   年末储电量 %.2f kWh（年末自由）\n', ...
        min(EE), max(EE), prm.E_min, prm.E_max, EE(end));

E_mat  = reshape(EE, T, D).';
chg_d  = reshape(CC, T, D).' * dt;
dis_d  = reshape(DD, T, D).' * dt;
buy_d  = (reshape(GL + GC, T, D).' ) * dt;
emb_d  = (reshape(HL + HC, T, D).') * dt;
curt_d = reshape(VV, T, D).' * dt;
E0_d   = reshape(E0, T, D).';

cost_d = sum(price_v(:).' .* buy_d, 2) + prm.kappa_em * sum(price_v(:).' .* emb_d, 2);

year_tbl = table(day_list, sum(buy_d,2), sum(emb_d,2), cost_d, sum(chg_d,2), sum(dis_d,2), ...
    sum(curt_d,2), E0_d(:,1), E_mat(:,T), ...
    'VariableNames', {'date','buy_kwh','em_kwh','cost_yuan','chg_kwh','dis_kwh','curt_kwh','E0_kwh','E24_kwh'});
writetable(year_tbl, fullfile(PROJ_ROOT, 'outputs', 'q2_year_daily.csv'));

%% 与逐日模型对照（若逐日结果已存在）
daily_csv = fullfile(PROJ_ROOT, 'outputs', 'q2_daily.csv');
if exist(daily_csv, 'file')
    dly  = readtable(daily_csv);
    win  = year_tbl.date >= datetime(2025,2,1);
    Zd_w = sum(dly.cost_yuan);                    % 逐日模型：报送窗口合计
    Zy_w = sum(year_tbl.cost_yuan(win));          % 全年联合：同一窗口合计
    fprintf('\n=== 两模型对照 ===\n');
    fprintf('  全年合计（含 1 月过渡期）  全年联合 %.4f 元\n', Z);
    fprintf('  报送窗口 2.1-12.31        逐日 %.4f 元   全年联合 %.4f 元\n', Zd_w, Zy_w);
    fprintf('                            差 %.4f 元（逐日高出 %.2f%%）\n', ...
            Zd_w - Zy_w, 100*(Zd_w - Zy_w)/Zy_w);
    fprintf('  说明：全年联合为完美预见的理想基准，逐日模型为其可执行对照\n');
end

%% 绘图数据：两模型每日 0:00 储电量对照
fig_dir = fullfile(PROJ_ROOT, 'figures', '问题二', '02 储能_逐日与全年对照');
win   = year_tbl.date >= datetime(2025,2,1);
E0_y  = year_tbl.E0_kwh(win);
if exist(daily_csv, 'file')
    E0_daily = readtable(daily_csv).E0_kwh;     % 逐日模型的 0:00 储电量序列
else
    E0_daily = nan(numel(E0_y), 1);
end
writetable(table(year_tbl.date(win), E0_daily, E0_y, ...
    'VariableNames', {'date','E0_daily_kwh','E0_year_kwh'}), ...
    fullfile(fig_dir, 'data.csv'));

save(fullfile(PROJ_ROOT, 'outputs', 'q2_year_result.mat'), 'rep', 'prm', 'out', 'ef', ...
     't_build', 't_solve', 'E_mat', 'chg_d', 'dis_d', 'buy_d', 'emb_d', 'curt_d', 'E0_d', 'Z');
fprintf('\n结果已写入 outputs/q2_year_daily.csv 与 q2_year_result.mat\n');
fprintf('绘图数据已写入 figures/问题二/02 图件文件夹\n');
