% main_q2_forecast.m —— 问题二 第二部分：预测驱动的现实改进模型
% 链路：历史同星期滚动均值预测 → 每天 0:00 求解计划 MILP（预测数据）→ 实际数据分两种口径执行结算
%   口径 'plan'    储能严格照当天 0:00 计划执行（消融对照）
%   口径 'correct' 日内储能实时纠偏（正式口径）
% 计划购电量 G^plan 一经 0:00 确定即全天锁定，日内不得按实际数据修改（与问题三的调整机制相区别）。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;                       % 同星期回溯周数
T = prm.T;  dt = prm.dt;
optM = optimoptions('intlinprog', 'Display', 'off');

%% 数据与预测
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D = size(load_m, 1);
[Lhat, PVhat, used_max] = func_forecast_q2(load_m, pv_m, L1, PV1, K);
fprintf('=== 问题二 第二部分（预测驱动）===\n');
fprintf('  预测器：同星期滚动均值（K=%d 周）；冷启动 d=1 用附件1 典型日，d=2..7 用扩展均值\n', K);
fprintf('  信息泄漏自检：第 d 天引用的最晚历史日恒 < d  ——  %s\n', string(all(used_max < (1:D).')));

%% 两种执行口径各自独立跑完整年（各自携带实际 SOC 跨日反馈）
pol   = {'plan', 'correct'};
polcn = {'照计划执行（消融对照）', '日内实时纠偏（正式口径）'};
NP = numel(pol);

R = struct();
for k = 1:NP
    r = struct();
    r.buy_m = zeros(D,T);  r.em_m = zeros(D,T);  r.chg_m = zeros(D,T);
    r.dis_m = zeros(D,T);  r.curt_m = zeros(D,T);
    r.chg_kw = zeros(D,T); r.dis_kw = zeros(D,T);
    r.Eend_m = zeros(D,T); r.E0_m = zeros(D,1);  r.buy_kw = zeros(D,T);
    E_now = prm.E_init;
    t0 = tic;
    for d = 1:D
        [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
            func_build_q2(price_v, Lhat(d,:).', PVhat(d,:).', E_now, prm, true);
        ub(aux.idx.HL : aux.idx.HL+T-1) = 0;     % 计划阶段不含紧急购电
        ub(aux.idx.HC : aux.idx.HC+T-1) = 0;
        [x, ~] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
        bx = @(o) x(o : o+T-1);
        Gpl = bx(aux.idx.GL) + bx(aux.idx.GC);   % 计划购电功率 kW（全天锁定）
        out = func_exec_q2(Gpl, bx(aux.idx.C), bx(aux.idx.D), bx(aux.idx.E), ...
                           load_m(d,:).', pv_m(d,:).', price_v, E_now, prm, pol{k});
        r.buy_kw(d,:)  = Gpl.';          r.buy_m(d,:)  = (Gpl*dt).';
        r.em_m(d,:)    = out.H.';        r.curt_m(d,:) = out.V.';
        r.chg_m(d,:)   = out.C.';        r.dis_m(d,:)  = out.D.';
        r.chg_kw(d,:)  = out.C.'/dt;     r.dis_kw(d,:) = out.D.'/dt;
        r.E0_m(d)      = E_now;          r.Eend_m(d,:) = out.E.';
        r.cost(d)      = out.cost;       r.cost_plan(d) = out.cost_plan;  r.cost_em(d) = out.cost_em;
        E_now = out.E(end);                       % 实际日末 SOC → 次日 0:00
    end
    r.time = toc(t0);
    R.(pol{k}) = r;
end

%% 对照表
ri = (find(day_list == datetime(2025,2,1)):D).';
% 第一部分（完美信息基准）的对照值：窗口值取自其运行输出，全年值由其运行日志记录
dly1 = readtable(fullfile(PROJ_ROOT, 'outputs', 'q2_daily.csv'));
Z1_win  = sum(dly1.cost_yuan);
Z1_year = 13735609.64;
Z1_plan = Z1_year;   % 第一部分无紧急购电，故其全年费用即计划购电费
fprintf('\n=== 两部分结果对照 ===\n');
fprintf('%-26s %18s %18s %18s\n', '指标', '第一部分(完美信息)', '第二部分·照计划', '第二部分·实时纠偏');
fprintf('%-26s %18.2f %18.2f %18.2f\n', '全年总费用(元)', Z1_year, sum(R.plan.cost), sum(R.correct.cost));
fprintf('%-26s %18.2f %18.2f %18.2f\n', '报送窗口总费用(元)', Z1_win, sum(R.plan.cost(ri)), sum(R.correct.cost(ri)));
fprintf('%-26s %18.2f %18.2f %18.2f\n', '  其中: 计划购电费', Z1_plan, sum(R.plan.cost_plan), sum(R.correct.cost_plan));
fprintf('%-26s %18.2f %18.2f %18.2f\n', '  其中: 紧急购电费', 0, sum(R.plan.cost_em), sum(R.correct.cost_em));
fprintf('%-26s %18.0f %18.0f %18.0f\n', '紧急购电量(全年 kWh)', 0, sum(R.plan.em_m(:)), sum(R.correct.em_m(:)));
fprintf('%-26s %18d %18d %18d\n', '紧急购电出现天数', 0, nnz(sum(R.plan.em_m,2)>1e-6), nnz(sum(R.correct.em_m,2)>1e-6));
fprintf('%-26s %18d %18d %18d\n', '紧急购电出现槽数', 0, nnz(R.plan.em_m(:)>1e-6), nnz(R.correct.em_m(:)>1e-6));
fprintf('%-26s %18.2f %18.2f %18.2f\n', '最大单槽紧急购电(kWh)', 0, max(R.plan.em_m(:)), max(R.correct.em_m(:)));
fprintf('%-26s %18.1f %18.1f %18.1f\n', '弃光/富余(全年 kWh)', 0, sum(R.plan.curt_m(:)), sum(R.correct.curt_m(:)));
fprintf('%-26s %18.1f %18.1f %18.1f\n', '储能充电(全年 kWh)', 0, sum(R.plan.chg_m(:)), sum(R.correct.chg_m(:)));
fprintf('%-26s %18.1f %18.1f %18.1f\n', '储能放电(全年 kWh)', 0, sum(R.plan.dis_m(:)), sum(R.correct.dis_m(:)));
fprintf('%-26s %18.1f %18.1f %18.1f\n', '日末 SOC 均值(kWh)', 1200, mean(R.plan.Eend_m(:,T)), mean(R.correct.Eend_m(:,T)));
for k = 1:NP
    fprintf('  VoI（%s）= %.2f%%\n', polcn{k}, ...
            100*(sum(R.(pol{k}).cost(ri)) - Z1_win)/Z1_win);
end
fprintf('\n  求解耗时：照计划 %.1f s   实时纠偏 %.1f s\n', R.plan.time, R.correct.time);

%% 紧急购电的月度与时段分布
mon = month(day_list(ri));
h   = floor(((0:T-1)*10)/60) + 1;
fprintf('\n=== 紧急购电量（报送窗口，kWh）===\n');
fprintf('%-8s %16s %16s\n', '月份', '照计划', '实时纠偏');
for m = 2:12
    fprintf('%6d 月 %16.1f %16.1f\n', m, ...
            sum(R.plan.em_m(ri(mon==m),:),'all'), sum(R.correct.em_m(ri(mon==m),:),'all'));
end

%% 净负荷预测误差与紧急购电
en = (load_m - pv_m) - (Lhat - PVhat);
fprintf('\n  预测误差（报送窗口）：负荷 MAE %.1f / RMSE %.1f kW；光伏 MAE %.1f / RMSE %.1f kW\n', ...
        mean(abs(Lhat(ri,:)-load_m(ri,:)),'all'), sqrt(mean((Lhat(ri,:)-load_m(ri,:)).^2,'all')), ...
        mean(abs(PVhat(ri,:)-pv_m(ri,:)),'all'), sqrt(mean((PVhat(ri,:)-pv_m(ri,:)).^2,'all')));
% 槽级 corr(en,H|H>0) 会被「按门槛截断」稀释（H 是缺口超出兜底能力后的残差），
% 故改用逐日聚合口径：日误差水平 ↔ 日紧急购电量
Hd = sum(R.correct.em_m(ri,:), 2);   ed = mean(en(ri,:), 2);
mhd = Hd > 1e-6;
fprintf('  逐日聚合 corr(日均净负荷误差, 日紧急购电量) = %.4f（H>0 的天 n=%d）\n', ...
        corr(ed(mhd), Hd(mhd)), nnz(mhd));

%% 落盘
res = struct('buy_m', R.correct.buy_m, 'em_m', R.correct.em_m, 'chg_m', R.correct.chg_m, ...
             'dis_m', R.correct.dis_m, 'curt_m', R.correct.curt_m, ...
             'Eend_m', R.correct.Eend_m, 'E0_m', R.correct.E0_m, ...
             'price_v', price_v, 'day_list', day_list, 'rep_idx', ri, 'kappa_em', prm.kappa_em);
% 本入口已被年视野入口取代，不再写正式交付文件（2026-09-12 修正）
tab = func_write_q2(res, prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result2.xlsx'), ...
    fullfile(PROJ_ROOT, 'outputs', 'result2_forecast_daily.xlsx'));
fprintf('\n对照结果已写入 outputs/result2_forecast_daily.xlsx（旁路，不覆盖交付件）。\n');

tabl = table(day_list(ri), sum(R.plan.buy_m(ri,:),2), sum(R.plan.em_m(ri,:),2), R.plan.cost(ri).', ...
    sum(R.correct.em_m(ri,:),2), R.correct.cost(ri).', ...
    'VariableNames', {'date','buy_kwh','em_kwh_plan','cost_plan_pol','em_kwh_corr','cost_corr_pol'});
writetable(tabl, fullfile(PROJ_ROOT, 'outputs', 'q2_forecast_daily.csv'));

save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_forecast.mat'), ...
     'R', 'prm', 'Lhat', 'PVhat', 'used_max', 'tab', 'en', 'D', 'K', 'pol');
fprintf('明细已写入 outputs/q2_forecast_daily.csv 与 final_results_q2_forecast.mat\n');
