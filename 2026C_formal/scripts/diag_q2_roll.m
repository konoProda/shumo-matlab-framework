% diag_q2_roll.m —— 年视野结果的紧急购电成因诊断（组内产物，不交付）
%
% 改造前（逐日计划）的结论是"93.2% 的紧急购电源于储能耗尽"。年视野改造后日末储电量
% 从 1609 抬到 7659 kWh，但紧急购电只降 5.7%——本脚本查清这一反差：
% 关键区别在于【日末储电量】不等于【缺口时刻的储电量】。
%
% 对每个 H>0 槽判定放电受哪条约束钳制，并给出缺口时刻的槽初储电量分布。

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
[~, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = size(load_m, 1);
ri = (find(day_list == datetime(2025,2,1)):D).';

S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_roll_corr.mat'));
r = S.res;

G  = r.buy_kw(ri,:);   NL = load_m(ri,:) - pv_m(ri,:);
H  = r.em_m(ri,:)/prm.dt;   Dk = r.dis_m(ri,:)/prm.dt;
Ee = r.Eend_m(ri,:);   Eprev = [r.E0_m(ri), Ee(:,1:end-1)];
deficit = NL - G;                          % = -R，缺口功率
mask = H > 1e-6;

soc_lim = prm.eta_dis * (Eprev - prm.E_min)/prm.dt;
atPmax  = abs(Dk - prm.P_max) < 1e-3;
atSoc   = abs(Dk - soc_lim) < 1e-3;
cls = zeros(size(H));
cls(mask & atSoc)             = 2;         % 电量受限（放电被储电量下限钳制）
cls(mask & atPmax & ~atSoc)   = 1;         % 功率受限
cls(mask & ~atPmax & ~atSoc)  = 3;

fprintf('=== 年视野·带纠偏：紧急购电成因（报送窗口 %d 天）===\n', numel(ri));
fprintf('  H>0 槽数 %d ；紧急购电量 %.1f kWh\n', nnz(mask), sum(H(mask))*prm.dt);
fprintf('  恒等式 deficit = D + H 最大残差 %.3e kW\n', max(abs(deficit(mask) - Dk(mask) - H(mask))));

nm = {'功率受限（缺口超 P_max）', '电量受限（放电触储电量下限）', '其它'};
fprintf('\n  约束归属：\n');
for i = 1:3
    m = cls == i;
    if nnz(m) == 0; continue; end
    fprintf('    %-28s 槽数 %5d（%5.1f%%）  电量 %10.1f kWh（%5.1f%%）\n', ...
            nm{i}, nnz(m), 100*nnz(m)/nnz(mask), sum(H(m))*prm.dt, 100*sum(H(m))/sum(H(mask)));
end

fprintf('\n  缺口规模（kW）：P50 %.0f  P90 %.0f  P99 %.0f  max %.0f（P_max=%.0f）\n', ...
        prctile(deficit(mask),50), prctile(deficit(mask),90), ...
        prctile(deficit(mask),99), max(deficit(mask)), prm.P_max);
fprintf('  缺口 < P_max 的槽数占比 %.1f%%\n', 100*mean(deficit(mask) < prm.P_max));

fprintf('\n  ★ 缺口时刻的槽初储电量（kWh）：\n');
fprintf('     H>0 槽均值 %8.1f   中位数 %8.1f   触底(%0.0f)占比 %5.1f%%\n', ...
        mean(Eprev(mask)), median(Eprev(mask)), prm.E_min, ...
        100*mean(Eprev(mask) <= prm.E_min + 1e-3));
fprintf('     全窗口槽初储电量均值 %8.1f（对比日末均值 %.1f）\n', ...
        mean(Eprev(:)), mean(Ee(:,end)));
fprintf('     日末储电量均值 %.1f ；日内最低值均值 %.1f\n', ...
        mean(Ee(:,end)), mean(min(Ee,[],2)));

fprintf('\n  ★ 缺口集中在哪些时段（按小时，kWh）：\n');
hr = floor(((0:prm.T-1)*10)/60) + 1;
sh = zeros(24,1);
for t = 1:prm.T; sh(hr(t)) = sh(hr(t)) + sum(H(:,t)); end
[~, ord] = sort(sh, 'descend');
fprintf('     前 6 个小时：\n');
for k = 1:6
    fprintf('       %2d:00  %12.1f kWh\n', ord(k)-1, sh(ord(k)));
end
