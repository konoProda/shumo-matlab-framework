PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT,'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
[~, L1d, PV1d] = func_read_q1(PROJ_ROOT);
D = numel(day_list);  d0 = find(day_list == datetime(2025,2,1), 1);
ck = fullfile(PROJ_ROOT,'outputs','ckpt_probe.mat');
if exist(ck,'file'); delete(ck); end
cfg = struct('gamma',1,'W',28,'min_days',5,'Kfc',4,'libW',28,'seed',2026, ...
             'd_start',d0,'use_bin',false,'ideal',false,'d_max',40,'ckpt',ck);
fprintf('\n[第一次] 跑到第 40 天停下\n');
r1 = func_roll_q2c(price_v,load_m,pv_m,day_list,L1d,PV1d,prm,1,1,cfg,0);
fprintf('[第一次] 第 40 天末 SOC=%.6f，前 40 天费用=%.4f\n', r1.Eend_m(40,end), sum(r1.cost(1:40)));
cfg.d_max = 41;   % 续跑目标多一天，检验断点恢复的正确性
fprintf('\n[第二次] 应自第 41 天续跑（d_max=41）\n');
r2 = func_roll_q2c(price_v,load_m,pv_m,day_list,L1d,PV1d,prm,1,1,cfg,0);
fprintf('[第二次] 第 40 天末 SOC=%.6f（应与上一致），前 40 天费用=%.4f（应一致）\n', ...
        r2.Eend_m(40,end), sum(r2.cost(1:40)));
fprintf('[第二次] 第 41 天费用=%.4f，第 41 天末 SOC=%.6f\n', r2.cost(41), r2.Eend_m(41,end));
% 对照：全量重跑前 41 天
cfg2 = cfg; cfg2.d_max = 41; cfg2.ckpt = '';
r3 = func_roll_q2c(price_v,load_m,pv_m,day_list,L1d,PV1d,prm,1,1,cfg2,0);
fprintf('\n[对照] 全量重跑前 41 天费用=%.4f\n', sum(r3.cost(1:41)));
fprintf('[对照] 续跑结果与全量重跑逐日最大差 = %.3e 元（应为 0）\n', ...
        max(abs(r2.cost(1:41) - r3.cost(1:41))));
fprintf('[对照] SOC 序列最大差 = %.3e\n', max(abs(r2.Eend_m(1:41,:) - r3.Eend_m(1:41,:)), [], 'all'));
delete(ck);
fprintf('PROBE_DONE\n');
