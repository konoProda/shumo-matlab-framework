% data_q3_sens.m —— 图 08/09 数据：预报使用策略 S0~S3 对照与边际收益
% 注意：四种策略各自独立跑全年（储能轨迹随策略分化），差异含"储能路径反馈"的二阶效应。
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3_sens.mat'), 'R', 'sens');
R = S.R;  SET = S.sens.SET;  nam = S.sens.NAM;
n = numel(R);

Cs = zeros(n,1);  Cp = zeros(n,1);  Ca = zeros(n,1);  Ce = zeros(n,1);
em = zeros(n,1);  chg = zeros(n,1);  curt = zeros(n,1);  endE = zeros(n,1);
for k = 1:n
    ri = R{k}.rep_idx;
    Cs(k) = sum(R{k}.cost(ri));
    Cp(k) = sum(R{k}.cost_plan(ri));
    Ca(k) = sum(R{k}.cost_adj(ri));
    Ce(k) = sum(R{k}.cost_em(ri));
    em(k) = sum(R{k}.em_m(ri,:), 'all');
    chg(k) = sum(R{k}.chg_m(ri,:), 'all');
    curt(k) = sum(R{k}.curt_m(ri,:), 'all');
    endE(k) = mean(R{k}.Eend_m(ri, end));
end

% 费用变化：加入该时刻预报后，总费用相对上一策略的变化（正值 = 费用上升）
% 行序 S3,S2,S1,S0 → 变化依次为 S0→S1、S1→S2、S2→S3
dcost = [Cs(3)-Cs(4); Cs(2)-Cs(3); Cs(1)-Cs(2)];
topp = {'加入 6:00 预报', '再加入 12:00 预报', '再加入 18:00 预报'};

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '08 策略对照与边际收益');
if ~exist(outdir, 'dir'); mkdir(outdir); end
T = table((1:n).', nam.', Cs, Cp, Ca, Ce, em, chg, curt, endE, ...
    'VariableNames', {'idx','policy','cost_yuan','plan_yuan','adj_yuan','em_yuan','em_kwh','chg_kwh','curt_kwh','Eend_mean'});
writetable(T, fullfile(outdir, 'data.csv'));

T2 = table((1:3).', dcost, 'VariableNames', {'idx','dcost_yuan'});   % 仅数值列，展示标签放绘图脚本
writetable(T2, fullfile(outdir, 'data_marginal.csv'));

outdir2 = fullfile(PROJ_ROOT, 'figures', '问题三', '09 策略间的费用结构变化');
if ~exist(outdir2, 'dir'); mkdir(outdir2); end
writetable(T, fullfile(outdir2, 'data.csv'));

for k = 1:n
    fprintf('  %-14s 总 %12.0f  计划 %11.0f  调整 %9.0f  紧急 %10.0f  紧急购电 %8.0f kWh  日末储电均值 %6.0f\n', ...
            nam{k}, Cs(k), Cp(k), Ca(k), Ce(k), em(k), endE(k));
end
fprintf('费用变化：6:00 %+.0f 元、12:00 %+.0f 元、18:00 %+.0f 元（正值=费用上升）\n', dcost);
fprintf('已写 %s 与 %s\n', outdir, outdir2);
