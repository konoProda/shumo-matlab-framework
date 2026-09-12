% data_q3_cost.m —— 图 03 数据：全年费用的三项分解（逐月 + 全年）
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'res');
res = S.res;  ri = res.rep_idx;  dl = res.day_list(ri);
m = month(dl);
mon = (2:12).';

c_plan = zeros(12,1);  c_adj = zeros(12,1);  c_em = zeros(12,1);  em_kwh = zeros(12,1);
for k = 1:12
    if ~any(m == k); continue; end
    sel = ri(m == k);
    c_plan(k) = sum(res.cost_plan(sel));
    c_adj(k)  = sum(res.cost_adj(sel));
    c_em(k)   = sum(res.cost_em(sel));
    em_kwh(k) = sum(res.em_m(sel,:), 'all');
end

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '03 全年费用的三项分解');
if ~exist(outdir, 'dir'); mkdir(outdir); end
T = table(mon, c_plan(2:12), c_adj(2:12), c_em(2:12), em_kwh(2:12), ...
    'VariableNames', {'month','plan_yuan','adj_yuan','em_yuan','em_kwh'});
writetable(T, fullfile(outdir, 'data.csv'));
fprintf('全年：计划 %.0f / 调整 %.0f / 紧急 %.0f 元，合计 %.0f 元\n', ...
        sum(c_plan), sum(c_adj), sum(c_em), sum(c_plan)+sum(c_adj)+sum(c_em));
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
