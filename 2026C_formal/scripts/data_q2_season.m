% data_q2_season.m —— 生成图 07、图 08 的绘图数据（组内产物，不交付）
%   图 07 光伏与负载的月度规律：附件2 的实际光伏与实际负载，按月求和
%   图 08 紧急购电的逐时分布：两个年视野口径的紧急购电量，按小时求和
% 输出：figures/问题二/07 .../data.csv、figures/问题二/08 .../data.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[~, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D  = size(load_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';

%% 图 07：光伏与负载的月度合计（报送窗口）
mon = month(day_list(ri));
mm  = (2:12).';
pv_mm = zeros(numel(mm),1);  ld_mm = zeros(numel(mm),1);
for k = 1:numel(mm)
    pv_mm(k) = sum(pv_m(ri(mon==mm(k)),:), 'all') * prm.dt / 1e4;   % 万 kWh
    ld_mm(k) = sum(load_m(ri(mon==mm(k)),:), 'all') * prm.dt / 1e4;
end
T7 = table(mm, pv_mm, ld_mm, 100*pv_mm./ld_mm, ...
    'VariableNames', {'month','pv_wankwh','load_wankwh','pv_share_pct'});
d7 = fullfile(PROJ_ROOT, 'figures', '问题二', '07 光伏与负载的月度规律');
if ~exist(d7,'dir'); mkdir(d7); end
writetable(T7, fullfile(d7, 'data.csv'));

fprintf('=== 图 07 光伏与负载的月度合计（报送窗口）===\n');
fprintf('%6s %14s %14s %10s\n','月份','光伏(万kWh)','负载(万kWh)','光伏占比');
for k = 1:numel(mm)
    fprintf('%4d 月 %14.1f %14.1f %9.1f%%\n', mm(k), pv_mm(k), ld_mm(k), 100*pv_mm(k)/ld_mm(k));
end
[pkv, ipk] = max(pv_mm);  [pkl, ilk] = min(pv_mm);
fprintf('  最高月 %d 月 %.1f ；最低月 %d 月 %.1f ；倍数 %.2f\n', mm(ipk), pkv, mm(ilk), pkl, pkv/pkl);
fprintf('  占比区间 %.1f%% ~ %.1f%%\n', min(100*pv_mm./ld_mm), max(100*pv_mm./ld_mm));

%% 图 08：紧急购电的逐时分布（两个年视野口径）
C = load(fullfile(PROJ_ROOT,'outputs','final_results_q2_roll_corr.mat'));
A = load(fullfile(PROJ_ROOT,'outputs','final_results_q2_roll_plan.mat'));
hr = floor(((0:prm.T-1)*10)/60) + 1;
em_c = zeros(24,1);  em_p = zeros(24,1);
for t = 1:prm.T
    em_c(hr(t)) = em_c(hr(t)) + sum(C.res.em_m(ri,t)) / 1e4;   % 万 kWh
    em_p(hr(t)) = em_p(hr(t)) + sum(A.res.em_m(ri,t)) / 1e4;
end
T8 = table((0:23).', em_p, em_c, 100*em_c/sum(em_c), 100*em_p/sum(em_p), ...
    'VariableNames', {'hour','em_nocorr_wankwh','em_corr_wankwh','corr_pct','nocorr_pct'});
d8 = fullfile(PROJ_ROOT, 'figures', '问题二', '08 紧急购电的逐时分布');
if ~exist(d8,'dir'); mkdir(d8); end
writetable(T8, fullfile(d8, 'data.csv'));

fprintf('\n=== 图 08 紧急购电的逐时分布（报送窗口，万 kWh）===\n');
fprintf('%6s %14s %14s\n','小时','② 无纠偏','③ 有纠偏');
for h = 1:24
    fprintf('%02d:00 %14.2f %14.2f\n', h-1, em_p(h), em_c(h));
end
fprintf('  ③ 的集中度：晚峰 19-21 时 %.1f%% ；早峰 8-10 时 %.1f%% ；两段合计 %.1f%%\n', ...
        sum(em_c(20:22))/sum(em_c)*100, sum(em_c(9:11))/sum(em_c)*100, ...
        (sum(em_c(20:22))+sum(em_c(9:11)))/sum(em_c)*100);
fprintf('  ② 的最大小时 %02d:00（%.2f 万）；③ 的最大小时 %02d:00（%.2f 万）\n', ...
        find(em_p==max(em_p))-1, max(em_p), find(em_c==max(em_c))-1, max(em_c));
fprintf('\n已写入 07 与 08 两个目录的 data.csv\n');
