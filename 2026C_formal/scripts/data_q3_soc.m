% data_q3_soc.m —— 图 07 数据：储能储电量轨迹与日末分布（问题三 vs 问题二年视野口径）
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
S3 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'res');
S2 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_corr.mat'), 'res');
r3 = S3.res;  r2 = S2.res;  ri = r3.rep_idx;

E0_3 = r3.E0_m(ri);            E1_3 = r3.Eend_m(ri, end);
E0_2 = r2.E0_m(ri);            E1_2 = r2.Eend_m(ri, end);
doy  = day(r3.day_list(ri), 'dayofyear');

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '07 储能储电量轨迹与日末分布');
if ~exist(outdir, 'dir'); mkdir(outdir); end
T = table(doy, E0_3, E1_3, E0_2, E1_2, ...
    'VariableNames', {'doy','E0_q3','Eend_q3','E0_q2','Eend_q2'});
writetable(T, fullfile(outdir, 'data.csv'));
fprintf('问题三 日初储电均值 %.1f、日末均值 %.1f kWh；低于下限+5%% 的天数 %d/%d\n', ...
        mean(E0_3), mean(E1_3), nnz(E1_3 < 1200+0.05*9600), numel(E1_3));
fprintf('问题二 日初均值 %.1f、日末均值 %.1f kWh\n', mean(E0_2), mean(E1_2));
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
