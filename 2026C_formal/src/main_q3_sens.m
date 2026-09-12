% main_q3_sens.m —— 问题三 预报使用策略对照（题面末句：是否需要引入其他时刻的预报）
%   S0 = {0:00}              只用 0:00 预报，全天不调整
%   S1 = {0:00, 6:00}
%   S2 = {0:00, 6:00, 12:00}
%   S3 = {0:00, 6:00, 12:00, 18:00}
% 四种策略各自独立跑全年：策略不同 → 最终生效购电量不同 → 实际充放电不同 →
% 当天 24:00 储电量不同 → 次日 0:00 的初始储电量不同，故不可共用同一份 0:00 计划。
% 执行层统一为负载优先（正式口径）。本入口不写交付文件。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;
H = Inf;

% 行 = 策略；列 = 0:00 / 6:00 / 12:00 / 18:00 是否使用。
% 第 1 位（0:00 计划）是题面要求的必做环节，恒被执行，仅用于标注与打印；
% 求解分支只读第 2~4 位，故 S_k 的"用到的时刻"= 前 k+1 个。
SET = [true true  true  true ;     % S3：0:00 + 6:00 + 12:00 + 18:00
       true true  true  false;     % S2：0:00 + 6:00 + 12:00
       true true  false false;     % S1：0:00 + 6:00
       true false false false];    % S0：仅 0:00
NAM = {'S3 四阶段', 'S2 至 12:00', 'S1 至 6:00', 'S0 仅 0:00'};
TAG = {'0:00', '6:00', '12:00', '18:00'};

%% 数据
[price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D  = size(load_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';

fprintf('=== 问题三 预报使用策略对照 ===\n');
R = cell(4,1);
for k = 1:4
    fprintf('\n--- %s（启用时刻：%s）---\n', NAM{k}, strjoin(TAG(SET(k,:)), '、'));
    lvl  = 4 - k;                                  % 行序为 S3→S0，第 k 行对应 S_{4-k}
    want = [lvl>=1, lvl>=2, lvl>=3];               % 应启用 6:00/12:00/18:00 中的前 lvl 个
    assert(isequal(SET(k,2:4), want), '策略 %d 的阶段标志与定义不符', k);
    R{k} = func_roll_q3(price_v, load_m, pv_m, day_list, fc3, L1, PV1, prm, K, H, 'correct', SET(k,:), 60);
    fprintf('    耗时 %.1f min\n', R{k}.time/60);
end

%% 对照表（报送窗口口径）
fprintf('\n=== 策略对照（报送窗口 2025-02-01 ~ 12-31）===\n');
fprintf('%-14s %14s %14s %14s %14s %12s\n', ...
        '策略', '总费用(元)', '计划购电费', '调整费', '紧急购电费', '紧急购电(kWh)');
C = zeros(1,4);
for k = 1:4
    C(k) = sum(R{k}.cost(ri));
    fprintf('%-14s %14.2f %14.2f %14.2f %14.2f %12.0f\n', NAM{k}, C(k), ...
            sum(R{k}.cost_plan(ri)), sum(R{k}.cost_adj(ri)), sum(R{k}.cost_em(ri)), ...
            sum(R{k}.em_m(ri,:), 'all'));
end

%% 边际收益（加入某时刻预报带来的费用变化，负值 = 省钱）
fprintf('\n=== 引入各时刻预报的边际收益 ===\n');
fprintf('  ΔC(6:00)  = C(S0) - C(S1) = %12.2f 元\n', C(4) - C(3));
fprintf('  ΔC(12:00) = C(S1) - C(S2) = %12.2f 元\n', C(3) - C(2));
fprintf('  ΔC(18:00) = C(S2) - C(S3) = %12.2f 元\n', C(2) - C(1));

%% 落盘（旁路，不覆盖交付件）
sens = struct('SET', SET, 'NAM', {NAM}, 'C', C);
save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3_sens.mat'), 'R', 'sens', 'prm', 'K', 'H');

TT = table(NAM.', C.', ...
    arrayfun(@(k) sum(R{k}.cost_plan(ri)), 1:4).', ...
    arrayfun(@(k) sum(R{k}.cost_adj(ri)), 1:4).', ...
    arrayfun(@(k) sum(R{k}.cost_em(ri)), 1:4).', ...
    arrayfun(@(k) sum(R{k}.em_m(ri,:), 'all'), 1:4).', ...
    arrayfun(@(k) sum(R{k}.chg_m(ri,:), 'all'), 1:4).', ...
    arrayfun(@(k) sum(R{k}.curt_m(ri,:), 'all'), 1:4).', ...
    'VariableNames', {'policy','cost_yuan','cost_plan','cost_adj','cost_em','em_kwh','chg_kwh','curt_kwh'});
writetable(TT, fullfile(PROJ_ROOT, 'outputs', 'q3_sens.csv'));
fprintf('\n对照结果已写入 outputs/q3_sens.csv 与 final_results_q3_sens.mat（旁路，不覆盖交付件）。\n');
