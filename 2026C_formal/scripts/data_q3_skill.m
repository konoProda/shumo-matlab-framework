% data_q3_skill.m —— 图 01 数据：题面预报的精度画像（按预报步长）+ 两条参照线
% 口径：只统计"目标时刻落在白天 6:00-19:00"的样本，避免夜间零值稀释，
%       使题面预报与自建预测、与固有天气噪声三者可比。
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
K = 4;
[price_v, load_m, pv_m, day_list, fc3] = func_read_q3(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D = size(load_m, 1);
tmap = [0 6 12 18];
HOUR0 = 6;  HOUR1 = 18;                       % 白天时段（含端点）

% ---- 题面预报：逐预报步长的 MAE / RMSE ----
k_list = (1:24).';
mae = zeros(24,1);  rmse = zeros(24,1);  nk = zeros(24,1);
for k = 1:24
    e = [];
    for d = 1:D
        for j = 1:4
            hh = tmap(j) + (k-1);
            if hh > 23; continue; end
            if hh < HOUR0 || hh > HOUR1; continue; end
            e(end+1,1) = fc3(d,j,k) - sum(pv_m(d, 6*hh+1 : 6*hh+6))/6;   %#ok<AGROW>
        end
    end
    mae(k) = mean(abs(e));  rmse(k) = sqrt(mean(e.^2));  nk(k) = numel(e);
end

% ---- 参照 1：自建同星期回溯均值（问题二预测器）在白天时段的表现 ----
% 样本与题面预报一致（全年 365 天）；前 4 周由该预测器的扩展均值冷启动完成
es = [];
for d = 1:D
    [~, PVh] = func_forecast_q2(load_m, pv_m, L1, PV1, K, d);
    for h = HOUR0:HOUR1
        act = sum(pv_m(d, 6*h+1 : 6*h+6))/6;
        es(end+1,1) = mean(PVh(1, 6*h+1 : 6*h+6)) - act;   %#ok<AGROW>  % 逐日预测的当小时均值
    end
end
mae_self = mean(abs(es));

% ---- 参照 2：相邻同星期日的固有差异（天气噪声下界） ----
ed = [];
for d = 8:D
    for h = HOUR0:HOUR1
        ed(end+1,1) = sum(pv_m(d, 6*h+1:6*h+6))/6 - sum(pv_m(d-7, 6*h+1:6*h+6))/6;   %#ok<AGROW>
    end
end
mae_week = mean(abs(ed));

% ---- 落盘 ----
outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '01 光伏预报的精度画像');
if ~exist(outdir, 'dir'); mkdir(outdir); end
T = table(k_list, mae, rmse, nk, repmat(mae_self,24,1), repmat(mae_week,24,1), ...
    'VariableNames', {'lead_h','mae_kw','rmse_kw','n','mae_self_kw','mae_week_kw'});
writetable(T, fullfile(outdir, 'data.csv'));
fprintf('题面预报 白天 MAE(k=1..24) 区间 %.1f ~ %.1f kW\n', min(mae), max(mae));
fprintf('自建同星期回溯 MAE %.1f kW；相邻同星期差异 %.1f kW\n', mae_self, mae_week);
fprintf('已写 %s\n', fullfile(outdir, 'data.csv'));
