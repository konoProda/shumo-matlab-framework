% data_q3_tariff.m —— 图 10 数据：调整结算的分段线性费用结构（解析构造）
% 取平均电价 p̄ 为计价基准，计划购电量固定为 100 kWh，
% 扫描最终生效购电量 Q，给出结算费用（计划部分 + 调整部分）；
% 另给出三档边际价对照，用于解释"低于计划"的经济激励。
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

p_bar = 0.7662;                 % 全年平均电价 元/kWh（问题一实测口径）
Q_plan = 100;                   % 计划购电量 kWh（示意尺度）
Q = (0:2:250).';

c_plan = p_bar * min(Q, Q_plan);
c_adj  = 0.5*p_bar*max(Q_plan - Q, 0) + 1.5*p_bar*max(Q - Q_plan, 0);
c_all  = c_plan + c_adj;
slope  = [0.5; 1.5; 5] * p_bar; % 低于计划 / 高于计划 / 紧急购电 三档边际价

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '10 结算的分段线性费用结构');
if ~exist(outdir, 'dir'); mkdir(outdir); end
T = table(Q, c_plan, c_adj, c_all, repmat(Q_plan, numel(Q), 1), repmat(p_bar, numel(Q), 1), ...
    'VariableNames', {'Q','c_plan','c_adj','c_all','Q_plan','p_bar'});
writetable(T, fullfile(outdir, 'data.csv'));

marg = table([0.5; 1.5; 5], slope, {'调整后低于原计划'; '调整后高于原计划'; '实际运行紧急购电'}, ...
    'VariableNames', {'coef','price_yuan','label'});
writetable(marg, fullfile(outdir, 'data_marginal.csv'));
fprintf('平均电价 %.4f 元/kWh；三档边际价 %.4f / %.4f / %.4f 元/kWh\n', p_bar, 0.5*p_bar, 1.5*p_bar, 5*p_bar);
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
