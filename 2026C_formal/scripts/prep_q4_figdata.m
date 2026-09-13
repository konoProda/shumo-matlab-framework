% prep_q4_figdata.m —— 问题四图件数据准备
%
%   把 6 张图的绘图数据一次性落盘到各自图件文件夹的 data.csv。
%   用法：matlab -batch "run('scripts/prep_q4_figdata.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
FIG = fullfile(PROJ_ROOT, 'figures', '问题四');
prm = struct('T',144,'dt',1/6,'kappa_em',5);
T = prm.T;  dt = prm.dt;
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = numel(day_list);
prc = func_price_q4(PROJ_ROOT, prm, struct('Kfc',4,'W',28,'min_days',5,'d_start',32));
wr = @(p, Tt) writetable(Tt, fullfile(p, 'data.csv'), 'Encoding', 'UTF-8');
mkfld = @(n) mkdir_ret(fullfile(FIG, n));
rd = @(s) load(fullfile(OUT, sprintf('final_results_q4_%s.mat', s)));
have = @(s) exist(fullfile(OUT, sprintf('final_results_q4_%s.mat', s)), 'file') == 2;
if ~have('Q4-3'); error('未找到 Q4-3 结果，先跑 main_q4'); end
S43 = rd('Q4-3');  r43 = S43.res;
S42 = rd('Q4-2');  r42 = S42.res;
wi = r43.rep_idx;

%% 01 电价预测画像：实测 vs 预测的逐小时误差
p = mkfld('01 电价预测画像');
hidx = floor((0:T-1)/6) + 1;
mae_h = zeros(24,1);  bias_h = zeros(24,1);  mae_b = zeros(24,1);
for h = 1:24
    cols = (h-1)*6 + (1:6);
    e = prc.ePi0(wi, cols);
    mae_h(h)  = mean(abs(e(:)));
    bias_h(h) = mean(e(:));
    eb = prc.price_act(wi, cols) - prc.pi_base(wi, cols);
    mae_b(h)  = mean(abs(eb(:)));
end
wr(p, table((1:24).', mae_b, mae_h, bias_h, ...
    'VariableNames', {'hour','mae_base','mae_corr','bias_corr'}));

%% 02 峰谷时刻预测误差（储能调度真正关心的量）
p = mkfld('02 峰谷时刻预测误差');
dpk = [];  dvl = [];
for d = wi(:).'
    [~, a] = max(prc.price_act(d,:));  [~, b] = max(prc.pi_hat0(d,:));
    [~, c] = min(prc.price_act(d,:));  [~, e] = min(prc.pi_hat0(d,:));
    dpk(end+1,1) = b - a;   dvl(end+1,1) = e - c;                        %#ok<AGROW>
end
edges = (-12:12).';
cnt_p = histcounts(dpk, [-12.5:1:12.5]).';
cnt_v = histcounts(dvl, [-12.5:1:12.5]).';
wr(p, table(edges, cnt_p, cnt_v, ...
    'VariableNames', {'lag_slot','n_peak','n_valley'}));

%% 03 价格情景与实际（某一周的逐时对照）
p = mkfld('03 一周电价预测对照');
d0 = find(day_list == datetime(2025,7,14), 1);
d1 = d0 + 6;
tt=[]; kt=[]; kact=[]; khat=[];
for d = d0:d1
    tt=[tt; repmat(string(day_list(d),'yyyy-MM-dd'),T,1)];                %#ok<AGROW>
    kt=[kt; (1:T).'];                                                      %#ok<AGROW>
    kact=[kact; prc.price_act(d,:).'];                                     %#ok<AGROW>
    khat=[khat; prc.pi_hat0(d,:).'];                                       %#ok<AGROW>
end
wr(p, table(tt,kt,kact,khat,'VariableNames',{'date_str','slot','price_act','price_hat'}));

fprintf('Q4 图件数据已落盘（3 张图）到 figures/问题四/<各图文件夹>/data.csv\n');
fprintf('PREP_Q4_FIGDATA_DONE\n');

function p = mkdir_ret(p)
if exist(p, 'dir') ~= 7; mkdir(p); end
end
