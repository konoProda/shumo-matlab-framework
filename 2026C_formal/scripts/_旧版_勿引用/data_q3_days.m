% data_q3_days.m —— 图 04 数据：四个指定日期的"计划—生效—执行"逐槽轨迹
clear; close all; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q3.mat'), 'res');
res = S.res;  T = 144;
key = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];

outdir = fullfile(PROJ_ROOT, 'figures', '问题三', '04 指定日期的四阶段轨迹');
if ~exist(outdir, 'dir'); mkdir(outdir); end

slot = (1:T).';
for k = 1:4
    d = find(res.day_list == key(k), 1);
    assert(~isempty(d), '指定日期 %s 不在数据内', char(key(k), 'yyyy-MM-dd'));
    Tk = table(slot, res.plan_m(d,:).', res.adj_m(d,:).', res.em_m(d,:).', ...
        res.chg_m(d,:).', res.dis_m(d,:).', res.Eend_m(d,:).', ...
        repmat(double(res.E0_m(d)), T, 1), ...
        'VariableNames', {'slot','plan_kwh','adj_kwh','em_kwh','chg_kwh','dis_kwh','E_kwh','E0_kwh'});
    fn = sprintf('data_%s.csv', char(key(k), 'yyyy-MM-dd'));
    writetable(Tk, fullfile(outdir, fn));
    fprintf('  %s  计划 %8.0f  生效 %8.0f  紧急 %7.0f kWh  0:00储电 %7.0f  24:00储电 %7.0f\n', ...
        char(key(k),'yyyy-MM-dd'), sum(res.plan_m(d,:)), sum(res.adj_m(d,:)), sum(res.em_m(d,:)), ...
        res.E0_m(d), res.Eend_m(d,T));
end
fprintf('已写 %s（4 个 csv）\n', outdir);
