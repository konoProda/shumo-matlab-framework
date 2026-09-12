% cmp_q2_timefix.m —— 时间口径修复的中间基线（把"首日首槽"回退为修复前口径）
%
% 修复后的读取把 2025-01-01 首槽 [0:00,0:10) 改为附件1 典型日值；修复前该槽取"本日末列"，
% 而该列在修复后的口径里正是第 2 日的首槽（同一实测量）。故构造回退变体只需一步：
%     Lg(1,1) = load_m(2,1);  Pg(1,1) = pv_m(2,1);
% 这样"修复前基线 → 本变体 → B0"三个点即可把两处修复的贡献分别计量：
%     修复前基线 → 本变体   = 电价相位修复的影响
%     本变体     → B0       = 首日首槽修复的影响
% 电价相位无法用同样方式回退（它改的是整条曲线，且与 B0 之后的对照无关）。
%
% 本脚本只读数据、只写 outputs/final_results_q2b_M1.mat，不覆盖任何正式结果。

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
K = 4;  H = Inf;

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1, PV1] = func_read_q1(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';
d_start = ri(1);

% 一致性校验：修复后第 2 日首槽 == 附件2 第 1 行末列（标签 0:00+1）
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件2.xlsx'), 'Sheet', '小区负载');
assert(abs(load_m(2,1) - cell2mat(raw(2, 1 + 144))) < 1e-9, ...
       '回退变体的构造前提不成立：第 2 日首槽与附件第 1 行末列不等');

Lg = load_m;  Pg = pv_m;
Lg(1,1) = load_m(2,1);      % 修复前的"本日末列"填补
Pg(1,1) = pv_m(2,1);

fprintf('=== 时间口径中间基线 M1（电价已修复、首日首槽未修复）===\n');
cfg = struct('on', true, 'gamma_L', 0, 'gamma_PV', 0, 'W', 28, 'min_days', 5, 'd_start', d_start);
res = func_roll_q2(price_v, Lg, Pg, day_list, L1, PV1, prm, K, H, 'correct', 60, cfg);
save(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2b_M1.mat'), 'res', 'prm', 'K', 'H', 'cfg');

fprintf('\n  M1 全年费用 %.2f 元   窗口费用 %.2f 元   全年紧急购电 %.1f kWh（%d 天）\n', ...
        sum(res.cost), sum(res.cost(ri)), sum(res.em_m(:)), nnz(sum(res.em_m,2) > 1e-6));
fprintf('  M1 完成，耗时 %.1f min → outputs/final_results_q2b_M1.mat\n', res.time/60);
