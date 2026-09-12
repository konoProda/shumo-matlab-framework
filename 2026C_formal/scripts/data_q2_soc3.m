% data_q2_soc3.m —— 生成图件「问题二 06 三情况日末储电量轨迹」的绘图数据
% 组内产物，不交付。
% 三条线对应三种情况：
%   ① 理想状态        —— 完美信息下的全年联合最优（outputs/q2_year_daily.csv）
%   ② 无纠偏带预测    —— 年视野滚动 + 储能严格照计划（final_results_q2_roll_plan.mat）
%   ③ 有纠偏带预测    —— 年视野滚动 + 负载优先实时纠偏（final_results_q2_roll_corr.mat）
% 输出：figures/问题二/06 三情况日末储电量轨迹/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

A = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_plan.mat'));
B = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_corr.mat'));
Y = readtable(fullfile(PROJ_ROOT, 'outputs', 'q2_year_daily.csv'));

D = size(A.res.em_m, 1);
assert(height(Y) == D, '全年联合的日数与滚动结果不一致');

E_ideal = Y.E24_kwh;                              % ① 理想：全年联合的日末储电量
E_noc   = A.res.Eend_m(:,end);                    % ② 无纠偏
E_cor   = B.res.Eend_m(:,end);                    % ③ 有纠偏
dt_     = Y.date;

T = table(dt_, E_ideal, E_noc, E_cor, ...
    'VariableNames', {'date','E_ideal','E_nocorr','E_corr'});
out_dir = fullfile(PROJ_ROOT, 'figures', '问题二', '06 三情况日末储电量轨迹');
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
writetable(T, fullfile(out_dir, 'data.csv'));

ri = (find(dt_ == datetime(2025,2,1)):D).';
fprintf('=== 三情况日末储电量（kWh）===\n');
fprintf('%-14s %12s %12s %12s\n', '区间', '① 理想', '② 无纠偏', '③ 有纠偏');
fprintf('%-14s %12.1f %12.1f %12.1f\n', '全年均值', mean(E_ideal), mean(E_noc), mean(E_cor));
fprintf('%-14s %12.1f %12.1f %12.1f\n', '报送窗口均值', mean(E_ideal(ri)), mean(E_noc(ri)), mean(E_cor(ri)));
fprintf('%-14s %12.1f %12.1f %12.1f\n', '全年最小值', min(E_ideal), min(E_noc), min(E_cor));
fprintf('%-14s %12.1f %12.1f %12.1f\n', '触底(1200)天数', sum(E_ideal<=1200.001), sum(E_noc<=1200.001), sum(E_cor<=1200.001));
fprintf('已写入 %s\n', fullfile(out_dir, 'data.csv'));
