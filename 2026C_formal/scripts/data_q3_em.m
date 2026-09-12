% data_q3_em.m —— 图 06 数据：紧急购电的逐时分布（问题三正式口径 + 问题二对照）
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
S3 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'res');
S2 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_corr.mat'), 'res');
r3 = S3.res;  r2 = S2.res;
T = 144;
[~, ~, ~, day_list] = func_read_q2(PROJ_ROOT);
ri3 = r3.rep_idx;
ri2 = (find(day_list == datetime(2025,2,1)):numel(r2.E0_m)).';

% 逐槽 → 逐小时（每 6 槽一小时）
h  = (0:23).';
s3 = sum(r3.em_m(r3.rep_idx,:), 1);
s2 = sum(r2.em_m(ri2,:), 1);
e3 = sum(reshape(s3, 6, 24), 1).' / 1e4;        % 万 kWh
e2 = sum(reshape(s2, 6, 24), 1).' / 1e4;

p3 = 100 * e3 / sum(e3);
p2 = 100 * e2 / sum(e2);

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '06 紧急购电的逐时分布');
if ~exist(outdir, 'dir'); mkdir(outdir); end
Tb = table(h, e3, p3, e2, p2, 'VariableNames', {'hour','q3_wankwh','q3_pct','q2_wankwh','q2_pct'});
writetable(Tb, fullfile(outdir, 'data.csv'));
fprintf('问题三紧急购电合计 %.1f 万 kWh；晚峰 19-21 时占 %.1f%%、早峰 8-10 时占 %.1f%%\n', ...
        sum(e3), sum(p3(h>=19 & h<=21)), sum(p3(h>=8 & h<=10)));
fprintf('问题二同期对照：合计 %.1f 万 kWh，晚峰占 %.1f%%\n', sum(e2), sum(p2(h>=19 & h<=21)));
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
