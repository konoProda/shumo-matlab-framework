function main_q4()
%MAIN_Q4  问题四：实时波动电价下的重算（对应问题二 / 问题三 各一份交付）
%
%   主口径：
%     Q4-2 = 问题二 + 电价预测 + 电价误差 SAA            → outputs/result4-2.xlsx
%     Q4-3 = 问题三 + 电价预测 + 日内价格预测更新 + SAA   → outputs/result4-3.xlsx
%   评价性计算（不交付）：
%     Q4-2P0 / Q4-3P0  价格只取中心预测（§38 消融：价格风险建模是否必要）
%     Q4-2Ideal        价格情景替换为真实价格（§36 完美价格信息基准：价格不确定性代价）
%   稳定性：Q4-2 / Q4-3 的 K=8 对照（排最后）
%
%   用法：setsid nohup matlab -batch "addpath(genpath('src')); main_q4" >/dev/null 2>&1 < /dev/null &

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..', '..');  % 入口在 src/问题X/ 下，需上溯两层到题目根目录（2026-09-13 分目录整理）
addpath(PROJ_ROOT, genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
fid = fopen(fullfile(OUT, 'log_q4_run.txt'), 'a');
lg = @(varargin) both(fid, varargin{:});

prm = struct('T',144, 'dt',1/6, 'eta_ch',0.90, 'eta_dis',0.90, 'E_init',6000, ...
             'E_min',1200, 'E_max',10800, 'P_max',5000, 'kappa_em',5);

[~, load_m, pv_m, day_list, fc3] = func_read_q3b(PROJ_ROOT);
[L1, PV1] = read_typ(PROJ_ROOT, prm);
d_start = find(day_list == datetime(2025,2,1), 1);
D = numel(day_list);

cfg0 = struct('Kfc',4, 'W',28, 'min_days',5, 'd_start',d_start);
lg('\n%s\n', repmat('=', 1, 72));
lg('main_q4 启动 %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
t0p = tic;
prc = func_price_q4(PROJ_ROOT, prm, cfg0);
lg('价格预测模块：基础 MAE %.4f → 加偏差校正 MAE %.4f（改善 %.2f%%）；耗时 %.1fs\n', ...
   prc.MAE_base, prc.MAE, 100*(prc.MAE/prc.MAE_base-1), toc(t0p));
lg('附件4 实际电价：%.4f~%.4f 元/kWh，均值 %.4f，负值 %d 个\n', ...
   min(prc.price_act(:)), max(prc.price_act(:)), mean(prc.price_act(:)), nnz(prc.price_act < 0));

base = struct('K',4, 'R',7, 'd_start',d_start, 'd_max',D, 'gamma',1, ...
              'Kfc',4, 'libW',28, 'W',28, 'min_days',5, 'seed',2026, ...
              'use_bin',true, 'ckpt_every',10, 'replay_check',true);

jobs = { ...
    'Q4-2',      [0],          4, 'main'; ...
    'Q4-3',      [0 6 12 18],  4, 'main'; ...
    'Q4-2P0',    [0],          4, 'P0'; ...
    'Q4-3P0',    [0 6 12 18],  4, 'P0'; ...
    'Q4-2Ideal', [0],          4, 'ideal'; ...
    'Q4-2k8',    [0],          8, 'main'; ...
    'Q4-3k8',    [0 6 12 18],  8, 'main'};

frc = strtrim(getenv('Q4_FORCE'));
t0 = tic;
for j = 1:size(jobs,1)
    nm = jobs{j,1};  st = jobs{j,2};  K = jobs{j,3};  md = jobs{j,4};
    f_final = fullfile(OUT, sprintf('final_results_q4_%s.mat', nm));
    f_ckpt  = fullfile(OUT, sprintf('ckpt_q4_%s.mat', nm));
    forced = ~isempty(frc) && (any(strcmpi(frc, {'1','all'})) || any(strcmpi(strsplit(frc, ','), nm)));
    if exist(f_final, 'file') > 0 && ~forced
        lg('--- %s 已有结果，跳过（需重跑置 Q4_FORCE=1 或 Q4_FORCE=%s）---\n', nm, nm);
        continue;
    end

    cfg = base;  cfg.stages = st;  cfg.K = K;  cfg.mode = md;  cfg.ckpt = f_ckpt;
    if K > 4; cfg.ckpt_every = 5; end
    lg('\n--- %s（阶段 %s, K=%d, 口径 %s）开始 %.1f min ---\n', nm, mat2str(st), K, md, toc(t0)/60);

    res = func_roll_q4(prc.price_act, load_m, pv_m, day_list, fc3, L1, PV1, prc, prm, cfg, 30);
    res.name = nm;

    wi = res.rep_idx;
    s = struct();
    s.name = nm;  s.stages = st;  s.K = K;  s.mode = md;
    s.cost_win = sum(res.cost(wi));
    s.cost_normal_win = sum(res.cost_normal(wi));
    s.cost_em_win = sum(res.cost_em(wi));
    s.em_win = sum(res.em_m(wi,:), 'all');
    s.em_days = nnz(sum(res.em_m(wi,:), 2) > 1e-6);
    s.curt_win = sum(res.curt_m(wi,:), 'all');
    s.waste_win = sum(res.waste_m(wi,:), 'all');
    s.adj_up = sum(res.dP_m(wi,:), 'all');
    s.adj_dn = sum(res.dM_m(wi,:), 'all');
    s.charge_win = sum(res.chg_m(wi,:), 'all');
    s.Eend_mean = mean(res.Etr_m(wi, end));
    s.pi_min_all = min(res.pi_min(:));
    s.max_viol = max(res.viol(:));   s.max_gap = max(res.gap(:));  s.max_replay = max(res.replay(:));
    s.time_min = res.time/60;
    s.prm = prm;  s.day_list = day_list;
    s.price_MAE = prc.MAE;  s.price_MAE_base = prc.MAE_base;

    save(f_final, 's', 'res', 'prc', '-v7.3');
    if exist(f_ckpt, 'file') > 0; delete(f_ckpt); end
    lg(['--- %s 完成 %.1f min：窗口费用 %14.2f 元（正常 %14.2f / 紧急 %12.2f）  ' ...
        '紧急电量 %10.1f kWh  调增 %9.1f 调减 %9.1f  充电 %11.1f\n'], ...
        nm, res.time/60, s.cost_win, s.cost_normal_win, s.cost_em_win, s.em_win, ...
        s.adj_up, s.adj_dn, s.charge_win);
    lg('    价格情景最小值 %+.4f 元/kWh  最大违反 %.2e  最大间隙 %.2e  重放偏差 %.2e\n', ...
        s.pi_min_all, s.max_viol, s.max_gap, s.max_replay);
end

lg('\n全部完成，总耗时 %.1f min\n', toc(t0)/60);
fclose(fid);
end

% ---------------------------------------------------------------- 局部函数
function both(fid, varargin)
fprintf(fid, varargin{:});
end

function [L1, PV1] = read_typ(PROJ_ROOT, prm)
T = prm.T;  roll = [T, 1:T-1];
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
L1  = cell2mat(raw(2:1+T, 3));  L1  = L1(roll);
PV1 = cell2mat(raw(2:1+T, 4));  PV1 = PV1(roll);
end
