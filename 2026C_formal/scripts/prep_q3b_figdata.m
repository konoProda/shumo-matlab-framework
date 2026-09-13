% prep_q3b_figdata.m —— 问题三（第二版/Q3b）图件数据准备
%
%   把 6 张图的绘图数据一次性落盘到各自图件文件夹的 data.csv。
%   与绘图脚本分离：本脚本负责算，plot 脚本只负责画（plot 脚本内禁计算）。
%   CSV 列名一律用 ASCII，中文标签放在 plot 脚本的参数区，避免编码问题。
%
%   用法：matlab -batch "run('scripts/prep_q3b_figdata.m')"

PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(PROJ_ROOT, 'src')));
OUT = fullfile(PROJ_ROOT, 'outputs');
FIG = fullfile(PROJ_ROOT, 'figures', '问题三');
prm = struct('T',144,'dt',1/6);
T = prm.T;  dt = prm.dt;

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = numel(day_list);
L = @(s) load(fullfile(OUT, sprintf('final_results_q3b_%s.mat', s)), 'res');
have = @(s) exist(fullfile(OUT, sprintf('final_results_q3b_%s.mat', s)), 'file') == 2;

names = {'S0','S1','S2','S3'};
R = struct();
for i = 1:numel(names)
    if have(names{i}); R.(names{i}) = L(names{i}).res; else; R.(names{i}) = []; end
end
if isempty(R.S3); error('未找到 S3 结果，先跑 main_q3b'); end
res = R.S3;
wi = res.rep_idx;                                   % 报送窗口
win = false(D,1);  win(wi) = true;

wr = @(p, Tt) writetable(Tt, fullfile(p, 'data.csv'), 'Encoding', 'UTF-8');
mkfld = @(n) mkdir_ret(fullfile(FIG, n));

%% 01 全年逐日购电结构（最终生效计划 / 调增 / 调减 / 紧急）
p = mkfld('01 逐日购电与调整结构');
Bk = res.buy_kw * dt;                                % kWh
dPk = res.dP_m;   dMk = res.dM_m;                    % 已是 kWh（执行层口径）
wr(p, table(day_list, sum(Bk,2), sum(dPk,2), sum(dMk,2), sum(res.em_m,2), ...
    'VariableNames', {'date','buy_kwh','up_kwh','dn_kwh','em_kwh'}));

%% 02 日末储电量轨迹
p = mkfld('02 日末储电量轨迹');
wr(p, table(day_list, res.Etr_m(:,end), min(res.Etr_m,[],2), max(res.Etr_m,[],2), ...
    'VariableNames', {'date','E_end','E_day_min','E_day_max'}));

%% 03 四个指定日期的四阶段计划与紧急购电（长表）
p = mkfld('03 指定日期四阶段轨迹');
key = [datetime(2025,3,20); datetime(2025,6,21); datetime(2025,9,23); datetime(2025,12,21)];
tt=[]; kd=[]; kt=[]; kP=[]; kA=[]; kEm=[]; kL=[]; kPV=[];
for k = 1:numel(key)
    di = find(day_list == key(k), 1);
    tt=[tt; repmat(string(key(k),'yyyy-MM-dd'),T,1)];  kd=[kd; repmat(di,T,1)];   %#ok<AGROW>
    kt=[kt; (1:T).'];                                                              %#ok<AGROW>
    kP=[kP; res.P_kw(di,:).'*dt];   kA=[kA; res.buy_kw(di,:).'*dt];               %#ok<AGROW>
    kEm=[kEm; res.em_m(di,:).'];    kL=[kL; load_m(di,:).'];  kPV=[kPV; pv_m(di,:).']; %#ok<AGROW>
end
wr(p, table(tt,kd,kt,kP,kA,kEm,kL,kPV, ...
    'VariableNames', {'date_str','day_idx','slot','plan_kwh','final_kwh','em_kwh','load_kw','pv_kw'}));

fprintf('Q3b 图件数据已落盘（3 张图：01 逐日购电结构 / 02 日末储电量 / 03 指定日期四阶段）到 figures/问题三/<各图文件夹>/data.csv\n');
fprintf('PREP_Q3B_FIGDATA_DONE\n');

function p = mkdir_ret(p)
if exist(p, 'dir') ~= 7; mkdir(p); end
end
