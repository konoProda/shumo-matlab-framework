% data_q2b_bias.m —— 生成图 11 的绘图数据（组内产物，不交付）
%   图 11 净负荷预测误差的改善：B0（原预测）与 B3（联合校正）的净负荷误差月度 Bias
%   净负荷 = 负荷 − 光伏；误差 = 预测净负荷 − 实际净负荷（正 = 预测偏高）
% 数据源：outputs/final_results_q2b_{B0,B3}.mat 的 corr 字段（Lraw/PVraw 与 Lcor/PVcor）
% 输出：figures/问题二/11 净负荷预测误差的改善/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

S0 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2b_B0.mat'));
S3 = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2b_B3.mat'));
c0 = S0.res.corr;   c3 = S3.res.corr;

[~, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';      % 报送窗口 334 天

mm = (2:12).';
b0 = zeros(numel(mm),1);  b3 = zeros(numel(mm),1);
for k = 1:numel(mm)
    sel = ri(month(day_list(ri)) == mm(k));
    b0(k) = mean( (c0.Lraw(sel,:) - c0.PVraw(sel,:)) - (load_m(sel,:) - pv_m(sel,:)), 'all');
    b3(k) = mean( (c3.Lcor(sel,:) - c3.PVcor(sel,:)) - (load_m(sel,:) - pv_m(sel,:)), 'all');
end
T = table(mm, b0, b3, 'VariableNames', {'month', 'bias_b0_kw', 'bias_b3_kw'});
d11 = fullfile(PROJ_ROOT, 'figures', '问题二', '11 净负荷预测误差的改善');
if ~exist(d11, 'dir'); mkdir(d11); end
writetable(T, fullfile(d11, 'data.csv'));

fprintf('=== 图 11 净负荷误差月度 Bias（kW，正 = 预测偏高）===\n');
fprintf('%5s %12s %12s %12s\n', '月份', 'B0', 'B3', '绝对值变化');
for k = 1:numel(mm)
    fprintf('%4d 月 %12.1f %12.1f %12.1f\n', mm(k), b0(k), b3(k), abs(b3(k)) - abs(b0(k)));
end
fprintf('  月均 |Bias|：B0 %.1f kW → B3 %.1f kW（%+.1f%%）\n', ...
        mean(abs(b0)), mean(abs(b3)), 100*(mean(abs(b3))/mean(abs(b0)) - 1));
fprintf('已写入 %s\n', fullfile(d11, 'data.csv'));
