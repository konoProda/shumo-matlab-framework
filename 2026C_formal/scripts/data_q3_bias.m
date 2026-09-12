% data_q3_bias.m —— 图 02 数据：题面预报的系统性形状偏差（逐小时平均偏差）
% 偏差 = 0:00 发布的预报（10 分钟插值后）− 实际光伏，逐小时平均；
% 同时给出扣除该偏差后的残差水平，用于说明偏差对总误差的贡献。
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
[price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT);
D = size(load_m, 1);  T = 144;

act_h = zeros(D, 24);
for h = 0:23
    act_h(:, h+1) = sum(pv_m(:, 6*h+1 : 6*h+6), 2)/6;
end

% 预报侧取"整点预报值"本身，不做插值后平均——这样与"预报值 ↔ 实际小时均值"的
% 常规误差口径一致（预处理日志、致建模手确认单均用此口径）。
% 注：模型中实际使用的是线性插值后的 10 分钟序列，插值会把早晨爬坡段的
%     小时内均值抬高，故模型侧的等效偏差大于本图口径（见报告风险项 R3）。
fc_h = zeros(D, 24);
for d = 1:D
    fc_h(d, :) = reshape(fc3(d,1,:), 1, 24);
end

bias = mean(fc_h - act_h, 1);

% 偏差对误差的贡献（白天时段）
day = 7:19;                                    % 6:00-19:00（1 基取 7..19）
e_raw = fc_h(:, day) - act_h(:, day);
e_fix = e_raw - repmat(bias(day), D, 1);
mae_raw = mean(abs(e_raw(:)));
mae_fix = mean(abs(e_fix(:)));

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '02 预报的系统性形状偏差');
if ~exist(outdir, 'dir'); mkdir(outdir); end
hour = (0:23).';
T2 = table(hour, bias.', repmat(mae_raw,24,1), repmat(mae_fix,24,1), ...
    'VariableNames', {'hour','bias_kw','mae_raw_kw','mae_corrected_kw'});
writetable(T2, fullfile(outdir, 'data.csv'));
fprintf('逐小时偏差：最大正偏差 %+.1f kW（%d 时），最大负偏差 %+.1f kW（%d 时）\n', ...
        max(bias), find(bias==max(bias))-1, min(bias), find(bias==min(bias))-1);
fprintf('白天 MAE：原始 %.1f kW，扣除逐小时偏差后 %.1f kW（偏差贡献 %.0f%%）\n', ...
        mae_raw, mae_fix, 100*(1 - mae_fix/mae_raw));
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
