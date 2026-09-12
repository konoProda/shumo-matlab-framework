% sens_q2_horizon.m —— 视野灵敏度：H = 1 / 7 / 30 / 90 / 全年 五档（组内产物，不交付）
% 正式口径（负载优先 + 实时纠偏）。H=1 即改造前的"只看当天"，用作回归校验：
% 应与逐日 MILP 的结果接近，差异来自"计划用 LP 松弛而非 MILP"（预期约 5e-6 相对量级）。
% 输出 outputs/q2_horizon_sens.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D  = size(load_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';

Hs   = [1 7 30 90 Inf];
labs = {'1 天（只看当天）', '7 天', '30 天', '90 天', '全年视野'};
nH   = numel(Hs);
Z = zeros(nH, 1);  EM = zeros(nH,1);  SLOT = zeros(nH,1);  EEND = zeros(nH,1);
CURT = zeros(nH,1);  MTX = zeros(nH,1);  T = zeros(nH,1);

for k = 1:nH
    fprintf('\n===== 视界 %s =====\n', labs{k});
    r = func_roll_q2(price_v, load_m, pv_m, day_list, L1, PV1, prm, K, Hs(k), 'correct', 60);
    Z(k)    = sum(r.cost(ri));
    EM(k)   = sum(r.em_m(ri,:), 'all');
    SLOT(k) = nnz(r.em_m(ri,:) > 1e-6);
    EEND(k) = mean(r.Eend_m(ri, end));
    CURT(k) = sum(r.curt_m(ri,:), 'all');
    MTX(k)  = sum(r.mutex);
    T(k)    = r.time;
    save(fullfile(PROJ_ROOT, 'outputs', sprintf('q2_hz_%s.mat', string(Hs(k)))), 'r');
end

Z1_win = 12182837.88;
fprintf('\n===== 视野灵敏度汇总（报送窗口 334 天）=====\n');
fprintf('%-18s %14s %14s %10s %12s %10s %8s\n', ...
        '视界', '总费用(元)', '紧急购电(kWh)', '出现槽数', '日末SOC均值', '弃光(kWh)', '耗时(min)');
for k = 1:nH
    fprintf('%-18s %14.2f %14.1f %10d %12.1f %10.1f %8.1f\n', ...
            labs{k}, Z(k), EM(k), SLOT(k), EEND(k), CURT(k), T(k)/60);
end
fprintf('\n相对理想下界（%.2f 元）的差距：\n', Z1_win);
for k = 1:nH
    fprintf('  %-18s %10.2f 元（%.2f%%）\n', labs{k}, Z(k) - Z1_win, 100*(Z(k)-Z1_win)/Z1_win);
end

fprintf('\n--- 回归校验：H=1 与改造前逐日 MILP 的差异 ---\n');
fprintf('  改造前逐日 MILP：窗口 17,678,185.84 元；紧急购电 971,075.28 kWh\n');
fprintf('  本脚本 H=1    ：窗口 %14.2f 元；紧急购电 %12.1f kWh\n', Z(1), EM(1));
fprintf('  相对差 %.2e（计划用 LP 松弛而非 MILP 所致）\n', abs(Z(1)-17678185.84)/17678185.84);

out = table(string(Hs(:)), Z, EM, SLOT, EEND, CURT, T, ...
    'VariableNames', {'H','cost_win','em_kwh_win','em_slots_win','Eend_mean','curt_win','time_s'});
writetable(out, fullfile(PROJ_ROOT, 'outputs', 'q2_horizon_sens.csv'));
fprintf('\n已写入 outputs/q2_horizon_sens.csv\n');
