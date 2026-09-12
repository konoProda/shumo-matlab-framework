% counter_q2_forecast.m —— 问题二 反事实对照：计划基于「附件1 单日预测」而非当天实际光伏
% 目的：回答「题目表3 为何为空」——紧急购电为零是信息假设（计划用当天实际值）的结果，
%       不是漏建了紧急购电变量。
%
% 结算规则（本对照的全部假设，论文须写明）：
%   ① 计划：第 d 天以「当天负载 + 附件1 的光伏预测曲线」求解单日模型，得到计划正常购电量
%      与计划充放电量；储能状态按计划逐日传递。
%   ② 计划是承诺：正常购电费按**计划量**结算，与实际是否用尽无关（题面"其他时间段的购电
%      费用均按计划购电量计算"）。
%   ③ 实际：光伏为附件2 的实际值。若实际负荷缺口超过计划的供负载能力
%      （G^L_plan + D_plan），超出部分由紧急购电以 5 倍电价补足。
%   ④ 计划充放电仍按计划执行，储能状态与计划一致。
%
% 输出：figures/问题二/04 检验_紧急购电反事实对照/data.csv、outputs/q2_counter_daily.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;
optM = optimoptions('intlinprog', 'Display', 'off');

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, ~, pv_fore] = func_read_q1(PROJ_ROOT);        % 附件1 的光伏预测曲线（逐日复用）
D = size(load_m, 1);
ri = find(day_list == datetime(2025,2,1)) : D;

cost_norm = zeros(D,1); cost_em = zeros(D,1); em_kwh = zeros(D,1);
E_now = prm.E_init;
for d = 1:D
    L = load_m(d,:).';  PVa = pv_m(d,:).';
    % ① 以「当天负载 + 附件1 预测光伏」制定计划
    [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
        func_build_q2(price_v, L, pv_fore, E_now, prm, true);
    [x, ~] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
    bx = @(off) x(off : off + T - 1);
    GL = bx(aux.idx.GL); GC = bx(aux.idx.GC); DD = bx(aux.idx.D);
    E_now = x(aux.idx.E + T - 1);

    % ② 计划量结算（承诺）
    cost_norm(d) = sum(price_v .* (GL + GC)) * prm.dt;

    % ③ 按实际光伏结算：负荷缺口超出计划供负载能力的部分 → 紧急购电
    Lbar_act = max(L - PVa, 0);
    H = max(Lbar_act - (GL + DD), 0);
    em_kwh(d)    = sum(H) * prm.dt;
    cost_em(d)   = sum(price_v .* H) * prm.dt * prm.kappa_em;
end

cost_tot = cost_norm + cost_em;
fprintf('=== 反事实对照：计划基于附件1 单日预测 ===\n');
fprintf('  窗口 %d 天\n', numel(ri));
fprintf('  正常购电费（按计划量）  %.2f 元\n', sum(cost_norm(ri)));
fprintf('  紧急购电量              %.2f kWh（%d 天出现）\n', sum(em_kwh(ri)), sum(em_kwh(ri) > 1e-6));
fprintf('  紧急购电费              %.2f 元\n', sum(cost_em(ri)));
fprintf('  合计                    %.2f 元\n', sum(cost_tot(ri)));
fprintf('  —— 基准口径（计划用当天实际光伏）：12210827.42 元，紧急购电 0 kWh\n');
fprintf('  差额 %.2f 元（+%.2f%%）\n', sum(cost_tot(ri)) - 12210827.42, ...
        100*(sum(cost_tot(ri)) - 12210827.42)/12210827.42);
[emax, ei] = max(em_kwh(ri));
fprintf('  紧急购电最多的日期 %s  当日 %.2f kWh\n', char(day_list(ri(ei)), 'yyyy-MM-dd'), emax);

fig_dir = fullfile(PROJ_ROOT, 'figures', '问题二', '04 检验_紧急购电反事实对照');
writetable(table(day_list(ri), em_kwh(ri), cost_em(ri), cost_norm(ri), ...
    'VariableNames', {'date','em_kwh','em_cost_yuan','norm_cost_yuan'}), ...
    fullfile(fig_dir, 'q2_counter.csv'));
writetable(table(day_list, em_kwh, cost_tot, ...
    'VariableNames', {'date','em_kwh','cost_total_yuan'}), ...
    fullfile(PROJ_ROOT, 'outputs', 'q2_counter_daily.csv'));
fprintf('已写入 figures/问题二/04 图件文件夹与 outputs/q2_counter_daily.csv\n');
