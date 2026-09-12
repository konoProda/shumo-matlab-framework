% data_q3_stage.m —— 图 11 数据：四阶段锁定与拼接的结构证据
% 口径：0:00-6:00 段未被任何后续阶段覆盖，生效值应恒等于原计划；
%       6:00 之后的段可见调整，且调整幅度按段递增（越靠近实时、预报越准）。
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'res');
res = S.res;  ri = res.rep_idx;
seg = [1 37 73 109 145];
nam = {'0:00-6:00', '6:00-12:00', '12:00-18:00', '18:00-24:00'};
T = 144;

dev = zeros(numel(ri), 4);          % 各段的平均 |生效 - 计划|
for b = 1:4
    sl = seg(b):seg(b+1)-1;
    dev(:, b) = mean(abs(res.adj_m(ri, sl) - res.plan_m(ri, sl)), 2);
end
mdev = mean(dev, 1).';

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '11 四阶段锁定与拼接');
if ~exist(outdir, 'dir'); mkdir(outdir); end
Tb = table((1:4).', nam.', mdev, ...
    'VariableNames', {'stage','label','mean_abs_dev_kwh'});
writetable(Tb, fullfile(outdir, 'data.csv'));
fprintf('各段平均 |生效-计划|（kWh/槽）：%.2f / %.2f / %.2f / %.2f\n', mdev);
fprintf('第 1 段恒为 0 的天数：%d / %d\n', nnz(dev(:,1) < 1e-9), numel(ri));
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
