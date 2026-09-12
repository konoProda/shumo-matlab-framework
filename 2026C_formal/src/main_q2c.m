% main_q2c.m —— 问题二 第三轮：7 日滚动 SAA 两阶段随机 MILP（六组运行）
%
%   L1  第一层理想信息基准（逐日，当天真实数据已知，不加扰动，不做校正）
%   L2  正式方案：SAA + B3 联合偏差校正（R=7，K=4）
%   L2b 消融：SAA − B3（R=7，K=4，γ=0，仅用于量化 B3 与 SAA 各自贡献）
%   L2r1/L2r3 视野长度对照（R=1 / R=3，K=4，γ=1）
%   L2k8 情景数稳定性（R=7，K=8，γ=1）
%
%   一律单 MATLAB 会话顺序执行（3 GB 环境，禁止并发）。

clear; close all; clc;

%% 路径与参数
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);

%% 数据
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1d, PV1d] = func_read_q1(PROJ_ROOT);
D  = numel(day_list);
ri = (find(day_list == datetime(2025,2,1)):D).';
d_start = ri(1);

%% 运行清单：{名称, R, K, γ, ideal}
runs = { 'L1',    1, 1, 0, true ;      % 第一层理想基准
         'L2',    7, 4, 1, false;      % 正式：SAA + B3
         'L2b',   7, 4, 0, false;      % 消融：SAA − B3
         'L2r1',  1, 4, 1, false;      % 视野对照 R=1
         'L2r3',  3, 4, 1, false;      % 视野对照 R=3
         'L2k8',  7, 8, 1, false };    % 情景数稳定性 K=8

fprintf('=== 问题二 第三轮：7 日滚动 SAA 两阶段随机 MILP ===\n');
fprintf('  一月按已知；预测自 %s 起；残差库滚动 28 个有效预测日；种子 2026\n', ...
        char(day_list(d_start), 'yyyy-MM-dd'));

t_all = tic;
for k = 1:size(runs, 1)
    nm = runs{k,1};  R = runs{k,2};  K = runs{k,3};  gm = runs{k,4};  idl = runs{k,5};
    f_final = fullfile(PROJ_ROOT, 'outputs', sprintf('final_results_q2c_%s.mat', nm));
    f_ckpt  = fullfile(PROJ_ROOT, 'outputs', sprintf('ckpt_q2c_%s.mat', nm));
    % Q2C_FORCE 支持按组重跑：'1'/'all' = 全部；'L1' 或 'L1,L2r3' = 指定组
    frc = strtrim(getenv('Q2C_FORCE'));
    forced = ~isempty(frc) && (any(strcmpi(frc, {'1','all'})) || ...
             any(strcmpi(strsplit(frc, ','), nm)));
    if exist(f_final, 'file') > 0 && ~forced
        fprintf('\n--- %s 已有结果，跳过（需重跑请置 Q2C_FORCE=1 或 Q2C_FORCE=%s）---\n', nm, nm);
        continue;
    end
    cfg = struct('gamma', gm, 'W', 28, 'min_days', 5, 'Kfc', 4, 'libW', 28, ...
                 'seed', 2026, 'd_start', d_start, 'use_bin', true, ...
                 'ideal', idl, 'd_max', D, 'ckpt', f_ckpt);
    fprintf('\n--- %s（R=%d, K=%d, gamma=%d, ideal=%d）开始 %.1f min ---\n', ...
            nm, R, K, gm, idl, toc(t_all)/60);
    res = func_roll_q2c(price_v, load_m, pv_m, day_list, L1d, PV1d, prm, K, R, cfg, 30);
    save(f_final, 'res', 'prm', 'cfg', 'K', 'R');
    if exist(f_ckpt, 'file') > 0; delete(f_ckpt); end
    fprintf(['--- %s 完成 %.1f min：全年费用 %.2f 元，窗口费用 %.2f 元，' ...
             '窗口紧急电量 %.1f kWh，最大间隙 %.2e ---\n'], ...
            nm, res.time/60, sum(res.cost), sum(res.cost(ri)), ...
            sum(res.em_m(ri,:), 'all'), max(res.gap));
end
fprintf('\n六组全部完成，总耗时 %.1f min\n', toc(t_all)/60);

%% 汇总表
fprintf('\n%-6s %5s %4s %5s %16s %16s %14s %10s %9s %8s\n', ...
        '运行', 'R', 'K', 'gamma', '全年费用', '窗口费用', '窗口紧急电量', '紧急天数', '最大间隙', '均耗时');
for k = 1:size(runs, 1)
    S = load(fullfile(PROJ_ROOT, 'outputs', sprintf('final_results_q2c_%s.mat', runs{k,1})));
    r = S.res;
    fprintf('%-6s %5d %4d %5d %16.2f %16.2f %14.1f %10d %9.1e %7.2fs\n', runs{k,1}, ...
            runs{k,2}, runs{k,3}, runs{k,4}, sum(r.cost), sum(r.cost(ri)), ...
            sum(r.em_m(ri,:), 'all'), nnz(sum(r.em_m(ri,:),2) > 1e-6), ...
            max(r.gap), mean(r.t_solve(r.t_solve > 0)));
end
fprintf('\n结果已写入 outputs/final_results_q2c_*.mat\n');
