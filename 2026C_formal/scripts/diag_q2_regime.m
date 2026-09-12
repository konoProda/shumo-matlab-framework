% diag_q2_regime.m —— 诊断：纠偏口径下每个紧急购电槽位由哪条约束触发（组内产物，不交付）
% 对每个 H>0 的槽位，取
%     deficit = NetLoad_act - G^plan = -R        （缺口功率 kW）
%     D       = 实际放电功率 kW
%     H       = 残余缺口 kW
% 恒等式 deficit = D + H 应精确成立。再判定放电受哪条约束钳制：
%     D ≈ P_max                                   → 功率受限
%     D ≈ eta_d*(E_{t-1}-E_min)/dt                → 电量受限（储能耗尽）
%     D ≈ deficit（即 H≈0，不应出现在此集合）      → 其它

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
S = load(fullfile(PROJ_ROOT, 'outputs', 'final_results_q2_forecast.mat'));
R = S.R;  prm = S.prm;  D_ = S.D;  en = S.en;
dt = prm.dt;
[~, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
ri = (find(day_list == datetime(2025,2,1)):D_).';

Rc = R.correct;
G   = Rc.buy_kw(ri,:);
NL  = load_m(ri,:) - pv_m(ri,:);
H   = Rc.em_m(ri,:) / dt;          % kW
Dk  = Rc.dis_m(ri,:) / dt;         % kW
Ee  = Rc.Eend_m(ri,:);             % 槽末储电量 kWh
E0d = Rc.E0_m(ri);                 % 各日起点储电量 kWh
Eprev = [E0d, Ee(:,1:end-1)];      % 槽初储电量 kWh

deficit = NL - G;
mask = H > 1e-6;

% ① 恒等式校验
resid = deficit - Dk - H;
fprintf('① 恒等式 deficit = D + H 最大残差：%.3e kW（H>0 槽）\n', max(abs(resid(mask))));

% ② 约束归属
soc_lim  = prm.eta_dis * (Eprev - prm.E_min) / dt;   % 电量约束允许的最大放电功率 kW
atPmax   = abs(Dk - prm.P_max) < 1e-3;
atSoc    = abs(Dk - soc_lim)   < 1e-3;
% 并列时（两者都卡）优先记电量受限（储能耗尽更本质）
cls = zeros(size(H));
cls(mask & atSoc)                    = 2;   % 电量受限
cls(mask & atPmax & ~atSoc)          = 1;   % 功率受限
cls(mask & ~atPmax & ~atSoc)         = 3;   % 其它（数值边界）

fprintf('\n② H>0 槽位的约束归属\n');
nm = {'功率受限(P_max)', '电量受限(储能耗尽)', '其它/数值边界'};
for i = 1:3
    m = cls == i;
    if nnz(m) == 0, continue; end
    fprintf('   %-20s 槽数 %6d（%5.1f%%）  电量 %10.1f kWh（%5.1f%%）\n', ...
            nm{i}, nnz(m), 100*nnz(m)/nnz(mask), sum(H(m))*dt, 100*sum(H(m))/sum(H(mask)));
end

% ③ 电量受限槽位的储电量轨迹特征
m2 = cls == 2;
if nnz(m2) > 0
    fprintf('\n③ 电量受限槽位：槽初储电量均值 %.1f kWh（下限 %.0f，上限 %.0f）\n', ...
            mean(Eprev(m2)), prm.E_min, prm.E_max);
    fprintf('   这些槽的缺口 deficit 均值 %.1f kW，其中可由 P_max 覆盖的部分占比 %.1f%%\n', ...
            mean(deficit(m2)), 100*min(mean(deficit(m2)), prm.P_max)/mean(deficit(m2)));
end

% ④ 缺口规模分布
fprintf('\n④ H>0 槽位的缺口规模（kW）\n');
fprintf('   deficit 分位：P50 %.0f  P90 %.0f  P99 %.0f  max %.0f   （P_max=%.0f）\n', ...
        prctile(deficit(mask),50), prctile(deficit(mask),90), prctile(deficit(mask),99), ...
        max(deficit(mask)), prm.P_max);
fprintf('   缺口 < P_max 的槽数占比 %.1f%%  → 这部分若能满功率放电本可完全覆盖\n', ...
        100*mean(deficit(mask) < prm.P_max));

% ⑤ 误差 vs 缺口水平的方差分解（解释条件相关系数为何被稀释）
enW = en(ri,:);
fprintf('\n⑤ 方差分解（H>0 槽位）\n');
fprintf('   std(deficit)=%.1f  std(H)=%.1f  std(en)=%.1f  std(G^plan)=%.1f  std(NetLoad)=%.1f\n', ...
        std(deficit(mask)), std(H(mask)), std(enW(mask)), std(G(mask)), std(NL(mask)));
fprintf('   corr(en, deficit) = %.4f    corr(en, G^plan) = %.4f\n', ...
        corr(enW(mask), deficit(mask)), corr(enW(mask), G(mask)));
fprintf('   corr(en, H)：全样本 %.4f ；仅在 H>0 %.4f （按门槛截断后范围受限，相关被稀释）\n', ...
        corr(enW(:), H(:)), corr(enW(mask), H(mask)));

% ⑥ 逐日聚合相关（稳态可用口径）
Hd = sum(Rc.em_m(ri,:),2);  ead = mean(abs(en(ri,:)),2);
fprintf('\n⑥ 逐日聚合：corr(日均|误差|, 日紧急购电量) = %.4f（H>0 的天 n=%d）\n', ...
        corr(ead(Hd>1e-6), Hd(Hd>1e-6)), nnz(Hd>1e-6));
fprintf('   逐日聚合：corr(日均 误差,  日紧急购电量) = %.4f\n', ...
        corr(mean(en(ri,:),2), Hd));
