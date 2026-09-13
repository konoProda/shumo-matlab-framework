% data_q3_adj.m —— 图 05 数据：调整量的逐日演化
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'res');
res = S.res;  ri = res.rep_idx;

up = sum(res.dP_m(ri,:), 2);          % 高于原计划 kWh
dn = sum(res.dM_m(ri,:), 2);          % 低于原计划 kWh
net = sum(res.adj_m(ri,:), 2) - sum(res.plan_m(ri,:), 2);
d39 = day(res.day_list(ri), 'dayofyear');

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '05 调整量的逐日演化');
if ~exist(outdir, 'dir'); mkdir(outdir); end
T = table(d39, up, dn, net, res.cost_adj(ri).', ...
    'VariableNames', {'doy','up_kwh','down_kwh','net_kwh','adj_cost_yuan'});
writetable(T, fullfile(outdir, 'data.csv'));
fprintf('全年上调 %.0f kWh（%d 天）、下调 %.0f kWh（%d 天）；净调整 %+.0f kWh\n', ...
        sum(up), nnz(up>1e-6), sum(dn), nnz(dn>1e-6), sum(net));
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
