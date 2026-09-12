% base_q1_nostorage.m — 问题一 无储能基准对照（组内产物，不交付）
% 目的：量化储能的价值。基准方案储能闲置（C=D=0），购电量 = max(L-PV,0)。

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

[price_v, load_p, pv_p] = func_read_q1(PROJ_ROOT);
dt = 1/6;

% 基准：储能不动作
base_buy = max(load_p - pv_p, 0);
base_kwh = sum(base_buy) * dt;
base_cost = sum(price_v .* base_buy) * dt;

% 最优：读正式运行结果
S = readtable(fullfile(PROJ_ROOT, 'outputs', 'q1_solution.csv'));
opt_kwh  = sum(S.buy_kwh);
opt_cost = sum(S.price .* S.buy_kwh);

fprintf('=== 问题一 无储能基准对照 ===\n');
fprintf('%-22s %14s %14s\n', '方案', '购电量(kWh)', '购电费(元)');
fprintf('%s\n', repmat('-', 1, 54));
fprintf('%-22s %14.4f %14.4f\n', '无储能基准', base_kwh, base_cost);
fprintf('%-22s %14.4f %14.4f\n', '含储能最优', opt_kwh, opt_cost);
fprintf('%s\n', repmat('-', 1, 54));
fprintf('%-22s %14.4f %14.4f\n', '差额', opt_kwh - base_kwh, opt_cost - base_cost);
fprintf('%-22s %13.4f%% %13.4f%%\n', '降幅', ...
        100*(base_kwh-opt_kwh)/base_kwh, 100*(base_cost-opt_cost)/base_cost);
fprintf('\n结论：购电量仅降 %.2f%%，购电费降 %.2f%%——储能收益主要来自峰谷价差套利。\n', ...
        100*(base_kwh-opt_kwh)/base_kwh, 100*(base_cost-opt_cost)/base_cost);
