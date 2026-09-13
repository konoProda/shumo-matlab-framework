function main_q3b()
%MAIN_Q3B  问题三第二版：四组预报时点组合的全年滚动模拟
%
%   策略（裁决 C11：四种组合各自完整独立跑全年，不得共用储能轨迹）：
%     S0 = {0:00}            只用 0:00 的光伏预报
%     S1 = {0:00, 6:00}
%     S2 = {0:00, 6:00, 12:00}
%     S3 = {0:00, 6:00, 12:00, 18:00}   ← 题目原始设定，正式交付口径
%   另跑 S3 的 K=8 稳定性对照。
%
%   运行顺序按"先小后大"：S0（最便宜、可端到端验证管线）→ S3 → S2 → S1 → S3(K=8)。
%   每组产物分文件保存，互不覆盖；已存在则跳过（Q3B_FORCE=1 或 Q3B_FORCE=组名 可强制重跑）。
%
%   用法：setsid nohup matlab -batch "main_q3b" >/dev/null 2>&1 < /dev/null &

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..', '..');  % 入口在 src/问题X/ 下，需上溯两层到题目根目录（2026-09-13 分目录整理）
addpath(PROJ_ROOT, genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
LOGF = fullfile(OUT, 'log_q3b_run.txt');
fid = fopen(LOGF, 'a');
lg = @(varargin) both(fid, varargin{:});

prm = struct('T',144, 'dt',1/6, 'eta_ch',0.90, 'eta_dis',0.90, 'E_init',6000, ...
             'E_min',1200, 'E_max',10800, 'P_max',5000, 'kappa_em',5);

[price_v, load_m, pv_m, day_list, fc3] = func_read_q3b(PROJ_ROOT);
[L1, PV1] = read_typ(PROJ_ROOT, prm);
d_start = find(day_list == datetime(2025,2,1), 1);
D = numel(day_list);

lg('\n%s\n', repmat('=', 1, 72));
lg('main_q3b 启动 %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
lg('数据：%d 天 × %d 槽；报告窗口自第 %d 天（2025-02-01）起\n', D, prm.T, d_start);

base = struct('K',4, 'R',7, 'd_start',d_start, 'd_max',D, 'gamma',1, ...
              'Kfc',4, 'libW',28, 'W',28, 'min_days',5, 'seed',2026, ...
              'use_bin',true, 'ckpt_every',10, 'replay_check',true);

jobs = { ...
    'S0',    [0],          4; ...
    'S3',    [0 6 12 18],  4; ...
    'S2',    [0 6 12],     4; ...
    'S1',    [0 6],        4; ...
    'S3k8',  [0 6 12 18],  8};

frc = strtrim(getenv('Q3B_FORCE'));
t0 = tic;
for j = 1:size(jobs, 1)
    nm = jobs{j,1};   st = jobs{j,2};   K = jobs{j,3};
    f_final = fullfile(OUT, sprintf('final_results_q3b_%s.mat', nm));
    f_ckpt  = fullfile(OUT, sprintf('ckpt_q3b_%s.mat', nm));

    forced = ~isempty(frc) && (any(strcmpi(frc, {'1','all'})) || ...
             any(strcmpi(strsplit(frc, ','), nm)));
    if exist(f_final, 'file') > 0 && ~forced
        lg('--- %s 已有结果，跳过（需重跑置 Q3B_FORCE=1 或 Q3B_FORCE=%s）---\n', nm, nm);
        continue;
    end

    cfg = base;
    cfg.stages = st;   cfg.K = K;   cfg.ckpt = f_ckpt;
    if K > 4; cfg.ckpt_every = 5; end        % K=8 单次更慢，断点更密
    lg('\n--- %s（阶段 %s, K=%d）开始 %.1f min ---\n', nm, mat2str(st), K, toc(t0)/60);

    res = func_roll_q3b(price_v, load_m, pv_m, day_list, fc3, L1, PV1, prm, cfg, 30);
    res.name = nm;   res.stages = st;   res.K = K;

    wi = res.rep_idx;                          % 报送窗口 2025-02-01 起
    s = struct();
    s.name = nm;  s.stages = st;  s.K = K;
    s.cost_year   = sum(res.cost);
    s.cost_win    = sum(res.cost(wi));
    s.cost_normal_win = sum(res.cost_normal(wi));
    s.cost_em_win = sum(res.cost_em(wi));
    s.em_win      = sum(res.em_m(wi,:), 'all');
    s.em_days     = nnz(sum(res.em_m(wi,:), 2) > 1e-6);
    s.curt_win    = sum(res.curt_m(wi,:), 'all');
    s.waste_win   = sum(res.waste_m(wi,:), 'all');
    s.adj_up      = sum(res.dP_m(wi,:), 'all');
    s.adj_dn      = sum(res.dM_m(wi,:), 'all');
    s.Eend_mean   = mean(res.Etr_m(wi, end));
    s.max_viol    = max(res.viol(:));
    s.max_gap     = max(res.gap(:));
    s.max_replay  = max(res.replay);
    s.time_min    = res.time / 60;
    s.prm = prm;  s.day_list = day_list;

    save(f_final, 's', 'res', '-v7.3');
    if exist(f_ckpt, 'file') > 0; delete(f_ckpt); end
    lg(['--- %s 完成 %.1f min：窗口费用 %14.2f 元（正常 %14.2f / 紧急 %12.2f）  ' ...
        '紧急电量 %10.1f kWh  弃光 %9.1f  已购未用 %9.1f  调增 %9.1f 调减 %9.1f\n'], ...
        nm, res.time/60, s.cost_win, s.cost_normal_win, s.cost_em_win, s.em_win, ...
        s.curt_win, s.waste_win, s.adj_up, s.adj_dn);
    lg('    最大违反 %.2e  最大间隙 %.2e  重放偏差 %.2e  日末储能均值 %.1f kWh\n', ...
        s.max_viol, s.max_gap, s.max_replay, s.Eend_mean);
end

lg('\n全部完成，总耗时 %.1f min\n', toc(t0)/60);
lg('结果已写入 outputs/final_results_q3b_*.mat\n');
fclose(fid);
end

% ---------------------------------------------------------------- 局部函数
function both(fid, varargin)
fprintf(fid, varargin{:});
fprintf(varargin{:});
end

function [L1, PV1] = read_typ(PROJ_ROOT, prm)
% 读附件1 典型日曲线（供预测器冷启动回退），按与 func_read_q2 同一归位口径
T = prm.T;  roll = [T, 1:T-1];
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
L1  = cell2mat(raw(2:1+T, 3));  L1  = L1(roll);
PV1 = cell2mat(raw(2:1+T, 4));  PV1 = PV1(roll);
end
