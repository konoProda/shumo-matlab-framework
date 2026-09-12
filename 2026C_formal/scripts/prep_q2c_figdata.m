% prep_q2c_figdata.m —— 问题二现行版（Q2c）图件数据准备（精简版，6 张图）
%
%   把 6 张图的绘图数据一次性落盘到各自图件文件夹的 data.csv。
%   与绘图脚本分离：本脚本负责算，plot 脚本只负责画（plot 脚本内禁计算）。
%   CSV 列名一律用 ASCII，中文标签放在 plot 脚本的参数区，避免编码问题。
%
%   用法：matlab -batch "run('scripts/prep_q2c_figdata.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
OUT = fullfile(PROJ_ROOT, 'outputs');
FIG = fullfile(PROJ_ROOT, 'figures', '问题二');
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T;  dt = prm.dt;

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1d, PV1d] = func_read_q1(PROJ_ROOT);
D = numel(day_list);
win = day_list >= datetime(2025,2,1);
d0 = find(day_list == datetime(2025,2,1), 1);
Ld = @(s) load(fullfile(OUT, sprintf('final_results_q2c_%s.mat', s))).res;
L2 = Ld('L2');  L1 = Ld('L1');  L2b = Ld('L2b');
L2r1 = Ld('L2r1');  L2r3 = Ld('L2r3');  L2k8 = Ld('L2k8');
S1b = load(fullfile(OUT, 'final_results_q2c_L1b.mat'));

mkfld = @(n) mkdir_ret(fullfile(FIG, n));
wr = @(p, Tt) writetable(Tt, fullfile(p, 'data.csv'), 'Encoding', 'UTF-8');

%% 01 全年逐日购电结构（计划购电 / 已购未用 W / 弃光 V / 紧急购电）
p = mkfld('01 全年逐日购电结构');
wr(p, table(day_list, sum(L2.buy_kw,2)*dt, sum(L2.waste_m,2), sum(L2.curt_m,2), sum(L2.em_m,2), ...
    'VariableNames', {'date','buy_kwh','waste_kwh','curt_kwh','em_kwh'}));

%% 02 日末储电量轨迹
p = mkfld('02 日末储电量轨迹');
wr(p, table(day_list, L2.Eend_m(:,end), min(L2.Eend_m,[],2), max(L2.Eend_m,[],2), ...
    'VariableNames', {'date','E_end','E_day_min','E_day_max'}));

%% 03 指定日期（长格式：日期 + 槽序号 + 各序列）
p = mkfld('03 指定日期_计划购电与紧急购电');
key = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];
tt = [];  kd = [];  kt = [];  kbuy = [];  kem = [];  kload = [];  kpv = [];
for k = 1:numel(key)
    di = find(day_list == key(k), 1);
    tt  = [tt;  repmat(string(key(k),'yyyy-MM-dd'), T, 1)];  %#ok<AGROW>
    kd  = [kd;  repmat(di, T, 1)];                            %#ok<AGROW>
    kt  = [kt;  (1:T).'];                                     %#ok<AGROW>
    kbuy = [kbuy; L2.buy_kw(di,:).' * dt];                    %#ok<AGROW>
    kem  = [kem;  L2.em_m(di,:).'];                           %#ok<AGROW>
    kload = [kload; load_m(di,:).'];                          %#ok<AGROW>
    kpv  = [kpv;  pv_m(di,:).'];                              %#ok<AGROW>
end
wr(p, table(tt, kd, kt, kbuy, kem, kload, kpv, ...
    'VariableNames', {'date_str','day_idx','slot','buy_kwh','em_kwh','load_kw','pv_kw'}));

%% 04 紧急购电_逐时分布
p = mkfld('04 紧急购电_逐时分布');
hr = (1:24).';
ek = zeros(24,1);  cnt = zeros(24,1);
for h = 1:24
    sl = (h-1)*6 + (1:6);
    ek(h)  = sum(L2.em_m(win, sl), 'all');
    cnt(h) = nnz(L2.em_m(win, sl) > 1e-6);
end
wr(p, table(hr, ek, cnt, 'VariableNames', {'hour','em_kwh','n_slot'}));

%% 05 对照与灵敏度（四面板，长表：panel / group / series / value）
%   panel = ladder（信息集阶梯）/ horizon（视野）/ kscen（情景数）/ ablate（偏差校正消融）
%   series = cost（元）/ aux（各面板的辅助量，含义见绘图脚本参数区）
p = mkfld('05 对照与灵敏度_四面板');
pn = {}; gp = {}; sr = {}; vl = [];
rows = { ...
  'ladder', '全年联合', 'cost', S1b.cost_win; ...
  'ladder', '逐日理想', 'cost', sum(L1.cost(win)); ...
  'ladder', '滚动SAA',  'cost', sum(L2.cost(win)); ...
  'ladder', '全年联合', 'aux',  sum(S1b.ec_day(win)); ...
  'ladder', '逐日理想', 'aux',  sum(L1.em_m(win,:),'all'); ...
  'ladder', '滚动SAA',  'aux',  sum(L2.em_m(win,:),'all'); ...
  'horizon','R=1','cost', sum(L2r1.cost(win)); ...
  'horizon','R=3','cost', sum(L2r3.cost(win)); ...
  'horizon','R=7','cost', sum(L2.cost(win)); ...
  'horizon','R=1','aux',  mean(L2r1.Eend_m(win,end)); ...
  'horizon','R=3','aux',  mean(L2r3.Eend_m(win,end)); ...
  'horizon','R=7','aux',  mean(L2.Eend_m(win,end)); ...
  'kscen',  'K=4','cost', sum(L2.cost(win)); ...
  'kscen',  'K=8','cost', sum(L2k8.cost(win)); ...
  'kscen',  'K=4','aux',  sum(L2.em_m(win,:),'all'); ...
  'kscen',  'K=8','aux',  sum(L2k8.em_m(win,:),'all'); ...
  'ablate', 'SAA-B3','cost', sum(L2b.cost(win)); ...
  'ablate', 'SAA+B3','cost', sum(L2.cost(win)); ...
  'ablate', 'SAA-B3','aux',  sum(L2b.em_m(win,:),'all'); ...
  'ablate', 'SAA+B3','aux',  sum(L2.em_m(win,:),'all')};
for r = 1:size(rows,1)
    pn{end+1,1} = rows{r,1};  gp{end+1,1} = rows{r,2};   %#ok<SAGROW>
    sr{end+1,1} = rows{r,3};  vl(end+1,1) = rows{r,4};   %#ok<SAGROW>
end
wr(p, table(pn, gp, sr, vl, 'VariableNames', {'panel','group','series','value'}));

%% 06 预测精度（校正前后）
p = mkfld('06 预测精度_校正前后');
cfg = struct('gamma',1, 'W',28, 'min_days',5, 'Kfc',4, 'libW',28, 'seed',2026, 'd_start',d0);
archRaw = func_resid_q2(load_m, pv_m, L1d, PV1d, cfg.Kfc, cfg.d_start);
hidx = floor((0:T-1)/6) + 1;
eLr = [];  eLc = [];  ePr = [];  ePc = [];  eNr = [];  eNc = [];
for d = find(win(:).')
    [bL, bPV] = func_bias_q2(archRaw, day_list, d, cfg);
    elr = archRaw.eL(d,:);          elc = elr - bL(hidx).';
    epr = archRaw.ePV(d,:);         epc = epr - bPV(hidx).';
    eLr = [eLr, elr];   eLc = [eLc, elc];         %#ok<AGROW>
    ePr = [ePr, epr];   ePc = [ePc, epc];         %#ok<AGROW>
    eNr = [eNr, elr-epr];  eNc = [eNc, elc-epc];  %#ok<AGROW>
end
item = {'负荷'; '负荷'; '光伏'; '光伏'; '净负荷'; '净负荷'};
kind = {'原始'; '校正后'; '原始'; '校正后'; '原始'; '校正后'};
M = [eLr(:), eLc(:), ePr(:), ePc(:), eNr(:), eNc(:)];
mae = zeros(6,1);  rmse = zeros(6,1);
for j = 1:6
    mae(j)  = mean(abs(M(:,j)));
    rmse(j) = sqrt(mean(M(:,j).^2));
end
wr(p, table(item, kind, mae, rmse, 'VariableNames', {'item','kind','mae','rmse'}));

fprintf('精简版图件数据已落盘（6 张图）到 figures/问题二/<各图文件夹>/data.csv\n');
fprintf('PREP_FIGDATA_DONE\n');

function p = mkdir_ret(p)
if exist(p, 'dir') ~= 7; mkdir(p); end
end
