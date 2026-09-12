% data_q2_sens.m —— 生成图件「问题二 05 视野灵敏度」的绘图数据
% 组内产物，不交付。数据源：outputs/q2_horizon_sens.csv（视野五档）与
% outputs/q2_year_daily.csv（完美信息全年联合基准，用于"理想下界"参考线）
% 输出：figures/问题二/05 视野灵敏度_费用与紧急购电/data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

S = readtable(fullfile(PROJ_ROOT, 'outputs', 'q2_horizon_sens.csv'));
Y = readtable(fullfile(PROJ_ROOT, 'outputs', 'q2_year_daily.csv'));

% 理想下界：完美信息全年联合，截取报送窗口（2025-02-01 起）
Z1 = sum(Y.cost_yuan(Y.date >= datetime(2025,2,1)));

Hs = S.H;
lab = {'1天','7天','30天','90天','全年'};
gap_wan = (S.cost_win - Z1)/1e4;          % 超出理想下界的部分（万元）
em_wk   = S.em_kwh_win/1e4;               % 紧急购电量（万 kWh）

T = table(Hs, string(lab(:)), S.cost_win, gap_wan, em_wk, S.Eend_mean, S.curt_win, ...
    'VariableNames', {'H','label','cost_win','gap_wan','em_wankwh','Eend_mean','curt_win'});
out_dir = fullfile(PROJ_ROOT, 'figures', '问题二', '05 视野灵敏度_费用与紧急购电');
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
writetable(T, fullfile(out_dir, 'data.csv'));

fprintf('=== 视野灵敏度（理想下界 = %.2f 元，取自全年联合的报送窗口合计）===\n', Z1);
fprintf('%6s %16s %14s %16s %14s\n', '视界', '窗口总费用(元)', '超出下界(万元)', '紧急购电(万kWh)', '日末SOC均值');
for k = 1:numel(lab)
    fprintf('%6s %16.2f %14.2f %16.1f %14.1f\n', lab{k}, S.cost_win(k), gap_wan(k), em_wk(k), S.Eend_mean(k));
end
fprintf('\n7 天及以上各档的相对差 %.4f%%（说明视界超过一周后无额外收益）\n', ...
        100*(max(S.cost_win(2:end)) - min(S.cost_win(2:end)))/mean(S.cost_win(2:end)));
fprintf('已写入 %s\n', fullfile(out_dir, 'data.csv'));
