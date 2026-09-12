% probe_q3_toy.m —— 问题三 小规模探针：取前 ND 天跑通四阶段全链并做守恒自检
% 用法：改 ND（1 / 7 / 30）后运行；产出只用于自检，不写交付文件。

clear; close all; clc;

ND = 30;                                   % 探针天数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;  H = Inf;  stages = [true true true true];

[price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);

% ---- 小切片 ----
sl = 1:ND;
res = func_roll_q3(price_v, load_m(sl,:), pv_m(sl,:), day_list(sl), fc3(sl,:,:), ...
                   L1, PV1, prm, K, H, 'correct', stages, 0);

T = prm.T;  dt = prm.dt;
fprintf('\n=== 探针 %d 天：逐日费用 ===\n', ND);
for d = 1:ND
    fprintf('  %s  总 %12.2f  计划 %12.2f  调整 %10.2f  紧急 %10.2f  紧急购电 %8.1f kWh\n', ...
            char(day_list(d),'yyyy-MM-dd'), res.cost(d), res.cost_plan(d), res.cost_adj(d), ...
            res.cost_em(d), sum(res.em_m(d,:)));
end

% ---- 自检 1：执行层逐槽能量平衡 ----
net = res.Gadj_kw + pv_m(sl,:) - load_m(sl,:);          % 逐槽净功率 kW
Ck  = res.chg_m / dt;  Dk = res.dis_m / dt;
Vk  = res.curt_m / dt; Hk = res.em_m / dt;
sPlus  = net >= 0;
rPlus  = abs(net - (Ck + Vk));
rMinus = abs(net + (Dk + Hk));
fprintf('\n[自检1] 执行层逐槽平衡：富余槽最大残差 %.3e   缺口槽最大残差 %.3e\n', ...
        max(rPlus(sPlus)), max(rMinus(~sPlus)));

% ---- 自检 2：Δ 纯表示 ----
fprintf('[自检2] 调整量纯表示：max(dP.*dM) = %.3e（应为 0）\n', max(res.dP_m(:) .* res.dM_m(:)));

% ---- 自检 3：计划层紧急购电恒为 0 ----
fprintf('[自检3] 计划层紧急购电：阶段0 合计 %.3e kW，阶段1~3 合计 %.3e kW\n', ...
        sum(res.planH), sum(res.planH_s));

% ---- 自检 4：储能递推 ----
Erec = [res.E0_m, res.Eend_m(:,1:end-1)] + prm.eta_ch*res.chg_m - res.dis_m/prm.eta_dis;
fprintf('[自检4] 储能递推最大偏差 %.3e kWh\n', max(abs(Erec(:) - res.Eend_m(:))));

% ---- 自检 5：费用自洽 ----
fprintf('[自检5] 费用自洽：max|cost-(plan+adj+em)| = %.3e 元\n', ...
        max(abs(res.cost - (res.cost_plan + res.cost_adj + res.cost_em))));

% ---- 自检 6：与阶段对照口径（day1 四策略共用同一 0:00 计划） ----
res0 = func_roll_q3(price_v, load_m(sl,:), pv_m(sl,:), day_list(sl), fc3(sl,:,:), ...
                    L1, PV1, prm, K, H, 'correct', [true false false false], 0);
fprintf('[自检6] 第 1 天 0:00 计划：S3 与 S0 的最大差异 %.3e kW（初值相同，应一致）\n', ...
        max(abs(res.Gplan_kw(1,:) - res0.Gplan_kw(1,:))));
fprintf('        S0 的调整量应恒为 0：max(adj-plan) = %.3e kWh\n', ...
        max(abs(res0.adj_m(:) - res0.plan_m(:))));
fprintf('        S0 的调整费应为 0：%.3e 元\n', sum(res0.cost_adj));

% ---- 自检 7：互斥性 ----
fprintf('[自检7] 阶段0 同槽同时充放 %d 槽；阶段1~3 %d 槽（均应 0）\n', ...
        sum(res.mutex), sum(res.mutex_s(:)));

fprintf('\n探针完成（%d 天）。\n', ND);
