% main_q2.m —— 问题二：全年逐日的计划购电策略（显式分流 + 紧急购电模型）
% 每天电价相同、小区负载与光伏实际功率逐日逐槽变化；每天 0:00 按当天实际数据制定计划；
% 储能状态跨日传递、日末自由；供能不低于负载，不足部分由 5 倍电价的紧急购电兜底。
% 求解窗口 2025-01-01 ~ 12-31（1 月为过渡期，使用附录1 的初值），结果按模板自 02-01 报出。

clear; close all; clc;

%% 路径
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

%% 参数（附录1 与题面）
prm = struct( ...
    'T',        144, ...      % (P-1) 每日时段数
    'dt',       1/6, ...      % (P-2) 时段长度 h
    'eta_ch',   0.90, ...     % (P-3) 充电效率
    'eta_dis',  0.90, ...     % (P-4) 放电效率
    'E_init',   6000, ...     % (P-5) 2025-01-01 0:00 储电量 kWh
    'E_min',    1200, ...     % (P-6) 储电量下限
    'E_max',    10800, ...    % (P-7) 储电量上限
    'P_max',    5000, ...     % (P-8) 最大充放电功率 kW
    'kappa_em', 5);           % (P-9) 紧急购电电价倍数

%% 读取附件1 电价与附件2 负载/光伏
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = size(load_m, 1);
T = prm.T;

%% 报送窗口：题面要求 2025-02-01 ~ 12-31（结果模板共 334 行日期）
rep_start = find(day_list == datetime(2025,2,1), 1);
assert(~isempty(rep_start), '未找到 2025-02-01');
ri = (rep_start:D).';

%% 逐日求解：日末自由，储能状态跨日传递
opts = optimoptions('intlinprog', 'Display', 'off');
nS = T;
bx = @(xx, off) xx(off : off + nS - 1);

buy_m  = zeros(D,T);  em_m   = zeros(D,T);  chg_m = zeros(D,T);  dis_m  = zeros(D,T);
pvl_m  = zeros(D,T);  pvc_m  = zeros(D,T);  curt_m= zeros(D,T);
gl_m   = zeros(D,T);  gc_m   = zeros(D,T);  hl_m  = zeros(D,T);  hc_m   = zeros(D,T);
Eend_m = zeros(D,T);  E0_m   = zeros(D,1);
ef_log = zeros(D,1);  gap_log = zeros(D,1);  Z_log = zeros(D,1);
aux_cell = cell(D,1);                        % 逐日分流辅助量，供事后校验复用

E_now = prm.E_init;
t_start = tic;
for d = 1:D
    [f, intcon, A, b, Aeq, beq, lb, ub, aux] = ...
        func_build_q2(price_v, load_m(d,:).', pv_m(d,:).', E_now, prm, true);
    [x, Z, ef, out] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opts);

    GL = bx(x, aux.idx.GL);   GC = bx(x, aux.idx.GC);
    HL = bx(x, aux.idx.HL);   HC = bx(x, aux.idx.HC);
    PVC = bx(x, aux.idx.PVC); CC = bx(x, aux.idx.C);
    DD = bx(x, aux.idx.D);    EE = bx(x, aux.idx.E);
    VV = bx(x, aux.idx.V);

    buy_m(d,:)  = ((GL + GC) * prm.dt).';
    em_m(d,:)   = ((HL + HC) * prm.dt).';
    gl_m(d,:)   = (GL * prm.dt).';      gc_m(d,:) = (GC * prm.dt).';
    hl_m(d,:)   = (HL * prm.dt).';      hc_m(d,:) = (HC * prm.dt).';
    pvl_m(d,:)  = (aux.PVL * prm.dt).'; pvc_m(d,:) = (PVC * prm.dt).';
    chg_m(d,:)  = (CC * prm.dt).';      dis_m(d,:) = (DD * prm.dt).';
    curt_m(d,:) = (VV * prm.dt).';
    E0_m(d)     = E_now;
    Eend_m(d,:) = EE.';
    ef_log(d)   = ef;  gap_log(d) = out.absolutegap;  Z_log(d) = Z;
    aux_cell{d} = aux;
    E_now = EE(end);
    if mod(d, 30) == 0 || d == D
        fprintf('  第 %3d/%d 天  累计 %.1f s  当日费用 %.2f 元\n', d, D, toc(t_start), Z);
    end
end
t_solve = toc(t_start);

fprintf('\n=== 问题二 逐日模型 ===\n');
fprintf('  求解天数 %d  耗时 %.1f s  exitflag 全为 1：%s\n', D, t_solve, string(all(ef_log == 1)));
fprintf('  绝对间隙：最大 %.3e 元，间隙 > 1e-6 的天数 %d / %d\n', ...
        max(gap_log), sum(gap_log > 1e-6), D);

%% 数值零清理（求解器可能返回 -0.00 量级的负零）
zer = @(M) M .* (abs(M) > 1e-9);
[buy_m, em_m, chg_m, dis_m, pvl_m, pvc_m, curt_m, gl_m, gc_m, hl_m, hc_m] = ...
    deal(zer(buy_m), zer(em_m), zer(chg_m), zer(dis_m), zer(pvl_m), zer(pvc_m), ...
         zer(curt_m), zer(gl_m), zer(gc_m), zer(hl_m), zer(hc_m));

%% 校验（按日逐段校验，报送窗口内任一日不通过即报错）
rep_bad = 0;
for d = ri.'
    aux = aux_cell{d};
    x_chk = zeros(10*T, 1);          % 用已存结果回填，校验独立于求解器
    x_chk(aux.idx.GL : aux.idx.GL+nS-1)   = gl_m(d,:).' / prm.dt;
    x_chk(aux.idx.GC : aux.idx.GC+nS-1)   = gc_m(d,:).' / prm.dt;
    x_chk(aux.idx.HL : aux.idx.HL+nS-1)   = hl_m(d,:).' / prm.dt;
    x_chk(aux.idx.HC : aux.idx.HC+nS-1)   = hc_m(d,:).' / prm.dt;
    x_chk(aux.idx.PVC: aux.idx.PVC+nS-1)  = pvc_m(d,:).' / prm.dt;
    x_chk(aux.idx.C  : aux.idx.C+nS-1)    = chg_m(d,:).' / prm.dt;
    x_chk(aux.idx.D  : aux.idx.D+nS-1)    = dis_m(d,:).' / prm.dt;
    x_chk(aux.idx.E  : aux.idx.E+nS-1)    = Eend_m(d,:).';
    x_chk(aux.idx.V  : aux.idx.V+nS-1)    = (aux.PVbar - pvc_m(d,:).' / prm.dt);
    rep = func_check_q2(x_chk, price_v, load_m(d,:).', pv_m(d,:).', prm, aux, E0_m(d));
    if ~rep.pass; rep_bad = rep_bad + 1; end
end
fprintf('  报送窗口 %d 天全部通过约束校验：%s（不通过 %d 天）\n', numel(ri), string(rep_bad == 0), rep_bad);

%% 落盘：逐槽明细与逐日汇总
res = struct('buy_m', buy_m, 'em_m', em_m, 'chg_m', chg_m, 'dis_m', dis_m, ...
             'curt_m', curt_m, 'pvl_m', pvl_m, 'pvc_m', pvc_m, 'gl_m', gl_m, 'gc_m', gc_m, ...
             'hl_m', hl_m, 'hc_m', hc_m, 'Eend_m', Eend_m, 'E0_m', E0_m, ...
             'price_v', price_v, 'day_list', day_list, 'rep_idx', ri, 'kappa_em', prm.kappa_em);

day_cost = sum(price_v(:).' .* buy_m(ri,:), 2) + prm.kappa_em * sum(price_v(:).' .* em_m(ri,:), 2);
day_tbl = table(day_list(ri), sum(buy_m(ri,:),2), sum(em_m(ri,:),2), day_cost, ...
    sum(chg_m(ri,:),2), sum(dis_m(ri,:),2), sum(curt_m(ri,:),2), ...
    sum(pvl_m(ri,:),2), sum(pvc_m(ri,:),2), E0_m(ri), Eend_m(ri,T), ef_log(ri), gap_log(ri), ...
    'VariableNames', {'date','buy_kwh','em_kwh','cost_yuan','chg_kwh','dis_kwh','curt_kwh', ...
                      'pv_load_kwh','pv_chg_kwh','E0_kwh','E24_kwh','exitflag','abs_gap'});
writetable(day_tbl, fullfile(PROJ_ROOT, 'outputs', 'q2_daily.csv'));

mins = ((0:T-1) * 10).';
lab = arrayfun(@(m) sprintf('%02d:%02d-%02d:%02d', floor(m/60), mod(m,60), ...
              floor((m+10)/60), mod(m+10,60)), mins, 'UniformOutput', false);
nR = numel(ri);
slot_tbl = table( ...
    repelem(day_list(ri), T), ...
    repmat((1:T).', nR, 1), ...
    repmat(lab, nR, 1), ...
    repmat(price_v, nR, 1), ...
    reshape(buy_m(ri,:).', [], 1), reshape(em_m(ri,:).',  [], 1), ...
    reshape(pvl_m(ri,:).', [], 1), reshape(pvc_m(ri,:).', [], 1), ...
    reshape(chg_m(ri,:).', [], 1), reshape(dis_m(ri,:).', [], 1), ...
    reshape(curt_m(ri,:).',[], 1), reshape(Eend_m(ri,:).',[], 1), ...
    'VariableNames', {'date','slot','period','price','buy_kwh','em_kwh','pv_load_kwh', ...
                      'pv_chg_kwh','chg_kwh','dis_kwh','curt_kwh','E_kwh'});
writetable(slot_tbl, fullfile(PROJ_ROOT, 'outputs', 'q2_solution.csv'));

%% 写结果文件 result2.xlsx，并取回论文表1/表2/表3
% 本入口属情形① 对照，正式交付文件由 main_q2_roll_corr.m 写出；
% 此处改写到旁路文件，避免误覆盖交付件（2026-09-12 修正）
tab = func_write_q2(res, prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result2.xlsx'), ...
    fullfile(PROJ_ROOT, 'outputs', 'result2_ideal_daily.xlsx'));

%% 汇总
E_use = prm.E_max - prm.E_min;
fprintf('\n=== 报送窗口 2025-02-01 ~ 12-31（%d 天）汇总 ===\n', nR);
fprintf('  全天购电量合计   %.4f kWh\n', sum(day_tbl.buy_kwh));
fprintf('  全天购电费合计   %.4f 元\n', sum(day_tbl.cost_yuan));
fprintf('  紧急购电量合计   %.4f kWh（%d 天出现）\n', sum(day_tbl.em_kwh), sum(day_tbl.em_kwh > 1e-6));
fprintf('  光伏供负载 %.2f kWh   光伏充电 %.2f kWh   弃光 %.2f kWh\n', ...
        sum(sum(pvl_m(ri,:))), sum(sum(pvc_m(ri,:))), sum(sum(curt_m(ri,:))));
fprintf('  储能充电   %.2f kWh   储能放电 %.2f kWh   等效循环 %.2f 次\n', ...
        sum(sum(chg_m(ri,:))), sum(sum(dis_m(ri,:))), sum(sum(dis_m(ri,:)))/E_use);
fprintf('  日均购电费 %.4f 元\n', mean(day_tbl.cost_yuan));

% 流向交叉校验：残差应为 0，否则说明取块有遗漏
pv_tot  = sum(sum(pv_m(ri,:))) * prm.dt;
bal_pv  = pv_tot - sum(sum(pvl_m(ri,:))) - sum(sum(pvc_m(ri,:))) - sum(sum(curt_m(ri,:)));
bal_ld  = sum(sum(load_m(ri,:)))*prm.dt - sum(sum(pvl_m(ri,:))) - sum(sum(gl_m(ri,:))) ...
          - sum(sum(hl_m(ri,:))) - sum(sum(dis_m(ri,:)));
bal_chg = sum(sum(chg_m(ri,:))) - sum(sum(pvc_m(ri,:))) - sum(sum(gc_m(ri,:))) - sum(sum(hc_m(ri,:)));
bal_buy = sum(sum(buy_m(ri,:))) + sum(sum(em_m(ri,:))) - sum(sum(gl_m(ri,:))) ...
          - sum(sum(gc_m(ri,:))) - sum(sum(hl_m(ri,:))) - sum(sum(hc_m(ri,:)));
fprintf('  流向交叉校验残差：光伏 %.2e  负载 %.2e  充电 %.2e  购电 %.2e kWh\n', ...
        bal_pv, bal_ld, bal_chg, bal_buy);

fprintf('\n=== 论文表1 指定时段购电量（kWh）===\n');
for k = 1:numel(tab.date_str)
    fprintf('  %s ：', tab.date_str{k});
    fprintf('%s %.2f  ', tab.t1_label{1}, tab.t1_buy(k,1));
    for j = 2:numel(tab.t1_label)
        fprintf('| %s %.2f ', tab.t1_label{j}, tab.t1_buy(k,j));
    end
    fprintf('|| 全天 %.2f kWh，%.2f 元\n', tab.t1_total(k), tab.t1_cost(k));
end

fprintf('\n=== 论文表2 储能充放电量（kWh）===\n');
for k = 1:numel(tab.date_str)
    fprintf('  %s  0:00 %.2f / 24:00 %.2f\n', tab.date_str{k}, tab.t2_E0(k), tab.t2_ET(k));
    for b = 1:tab.nB
        fprintf('      %-11s 充 %9.4f  放 %9.4f\n', tab.t2_label{b}, tab.t2_chg(k,b), tab.t2_dis(k,b));
    end
end

fprintf('\n=== 论文表3 紧急购电量 ===\n');
nz = find(tab.t3_kwh > 1e-6);
if isempty(nz)
    fprintf('  %d 天全部为 0（表3 各日填“无”）\n', nR);
else
    fprintf('  %d 天出现紧急购电，合计 %.4f kWh\n', numel(nz), sum(tab.t3_kwh));
    for k = nz.'
        fprintf('  %s  %s  %.4f\n', tab.t3_date{k}, tab.t3_win{k}, tab.t3_kwh(k));
    end
end

%% 绘图数据落盘（写入各图件文件夹，与绘图脚本同目录；plot 脚本只读不算）
figA = fullfile(PROJ_ROOT, 'figures', '问题二', '01 全年购电与弃光');
figC = fullfile(PROJ_ROOT, 'figures', '问题二', '03 指定日期_购电与储能');
DT = (datetime(2025,2,1) + days(0:nR-1)).';

% ① 全年逐日购电、弃光与费用
writetable(table(DT, day_tbl.buy_kwh, day_tbl.curt_kwh, day_tbl.cost_yuan, ...
    'VariableNames', {'date','buy_kwh','curt_kwh','cost_yuan'}), fullfile(figA, 'data.csv'));

% ② 二分二至四日的逐槽购电与储电量
keyD = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];
kd = find(ismember(day_list, keyD));
nK = numel(kd);
writetable(table(repelem(day_list(kd), T), repmat((1:T).', nK, 1), repmat(lab(:), nK, 1), ...
    repmat(price_v, nK, 1), reshape(buy_m(kd,:).', [], 1), reshape(Eend_m(kd,:).', [], 1), ...
    'VariableNames', {'date','slot','period','price','buy_kwh','E_kwh'}), fullfile(figC, 'data.csv'));

save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2.mat'), 'res', 'prm', 'tab', ...
     'day_tbl', 'ef_log', 'gap_log', 't_solve');
fprintf('\n结果已写入 outputs/result2_ideal_daily.xlsx（旁路）、q2_daily.csv、q2_solution.csv、final_results_q2.mat\n');
fprintf('绘图数据已写入 figures/问题二/01、03 两个图件文件夹\n');
