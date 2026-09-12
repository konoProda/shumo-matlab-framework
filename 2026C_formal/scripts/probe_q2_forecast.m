% probe_q2_forecast.m —— 问题二「第二部分：预测驱动的现实改进」可行性探针（组内产物，不交付）
% 链路：同星期滚动均值预测 → 0:00 计划 MILP（预测数据）→ 当天实际结算（5 倍紧急购电）
% 用途：验证信息口径可实现、统计紧急购电量级、检查是否存在"计划充电造成紧急购电"

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

prm = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
             'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = prm.T; D = 365; K = 4; dt = prm.dt;
optM = optimoptions('intlinprog', 'Display', 'off');

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);   % 已按起始标签+严格跨日
[~, L1, PV1] = func_read_q1(PROJ_ROOT);                        % 附件1 典型日（仅 1/1 冷启动用）

%% ① 预测（严格只用 τ < d 的实际数据）
Lhat = zeros(D,T); PVhat = zeros(D,T);
used_max = zeros(D,1);                                        % 每天实际引用的最晚历史日（信息泄漏自检）
for d = 1:D
    if d == 1
        Lhat(d,:) = L1.';  PVhat(d,:) = PV1.';                 % 冷启动：附件1 典型日
        used_max(d) = 0;                                        % 附件1 为全年均值，非某一日
    else
        S = (d-7):-7:max(1, d-7*(K-1));  S = S(S >= 1);
        if isempty(S)                                          % 同星期历史不足：扩展均值
            Lhat(d,:) = mean(load_m(1:d-1,:), 1);
            PVhat(d,:) = mean(pv_m(1:d-1,:), 1);
            used_max(d) = d-1;
        else
            Lhat(d,:) = mean(load_m(S,:), 1);
            PVhat(d,:) = mean(pv_m(S,:), 1);
            used_max(d) = max(S);
        end
    end
end
assert(all(used_max < (1:D).'), '信息泄漏：存在引用当日或未来数据的日期');

%% ② 计划 MILP（预测数据；紧急购电不进入计划，令其上下界为 0）
E_now = prm.E_init;
Gp = zeros(D,T); Cp = zeros(D,T); Dp = zeros(D,T); Ep = zeros(D,T); cost_plan = zeros(D,1);
ef = zeros(D,1);
for d = 1:D
    [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
        func_build_q2(price_v, Lhat(d,:).', PVhat(d,:).', E_now, prm, true);
    ub(aux.idx.HL : aux.idx.HL+T-1) = 0;
    ub(aux.idx.HC : aux.idx.HC+T-1) = 0;
    [x, Z, e] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
    bx = @(off) x(off : off+T-1);
    GL = bx(aux.idx.GL); GC = bx(aux.idx.GC);
    Cp(d,:) = bx(aux.idx.C).';  Dp(d,:) = bx(aux.idx.D).';   % 存 kW，结算需要
    Gp(d,:) = (GL+GC).';  Ep(d,:) = bx(aux.idx.E).';
    cost_plan(d) = Z;  ef(d) = e;
    E_now = Ep(d,T);
end

%% ③ 实际结算
Hact = zeros(D,T); Vact = zeros(D,T); cost_em = zeros(D,1);
for d = 1:D
    La = load_m(d,:).';  PVa = pv_m(d,:).';
    Pnet = Gp(d,:).' + PVa + Dp(d,:).' - Cp(d,:).';            % 供负荷净功率 kW（全程 kW，勿混 kWh）
    Hact(d,:) = (max(La - Pnet, 0)*dt).';                      % 紧急购电量 kWh
    Vact(d,:) = (max(Pnet - La, 0)*dt).';                      % 实际富余 kWh
    cost_em(d) = prm.kappa_em * sum(price_v .* max(La - Pnet, 0)) * dt;
end
Zreal = cost_plan + cost_em;

%% ④ 对照与诊断（按建模文档 §8 的指标）
ri = (find(day_list == datetime(2025,2,1)):D).';
fprintf('=== 第二部分（预测驱动）=== \n');
fprintf('  全年 365 天：计划购电费 %.2f 元  紧急购电费 %.2f 元  合计 %.2f 元\n', ...
        sum(cost_plan), sum(cost_em), sum(Zreal));
fprintf('  报送窗口 334 天合计 %.2f 元\n', sum(Zreal(ri)));
fprintf('  紧急购电量：全年 %.2f kWh（%d 天出现，%d 个槽）\n', ...
        sum(Hact(:)), sum(sum(Hact,2) > 1e-6), sum(Hact(:) > 1e-6));
fprintf('  最大单槽紧急购电量 %.2f kWh\n', max(Hact(:)));
fprintf('  实际富余（计划过量）电量 %.2f kWh\n', sum(Vact(:)));
fprintf('  计划口径「实际富余」%.2f kWh\n', sum(Vact(:)));
fprintf('  日末 SOC：均值 %.1f  最小 %.1f  最大 %.1f\n', mean(Ep(:,T)), min(Ep(:,T)), max(Ep(:,T)));
fprintf('  日末 SOC = 1200 的天数 %d / %d\n', sum(abs(Ep(:,T)-1200) < 1e-6), D);
fprintf('  求解 exitflag 非 1 的天数 %d\n', sum(ef ~= 1));

% 紧急购电是否由「计划充电」造成
mask = Hact > 1e-6;
fprintf('\n=== 紧急购电的成因分解（槽级）===\n');
fprintf('  出现紧急购电的槽 %d 个，其中 同期计划充电 C>0 的 %d 个（%.1f%%）\n', ...
        sum(mask(:)), sum(mask(:) & (Cp(:)>1e-6)), 100*sum(mask(:) & (Cp(:)>1e-6))/sum(mask(:)));

% 预测误差 vs 紧急购电
en = (load_m - pv_m) - (Lhat - PVhat);                          % 净负荷预测误差 kW
fprintf('  净负荷误差 e_net 与紧急购电功率的相关系数 %.4f\n', ...
        corr(en(mask), (Hact(mask)/dt)));

mon = month(day_list(ri));
fprintf('\n=== 报送窗口月度紧急购电量（前 6 位）===\n');
mv = zeros(12,1);
for m = 2:12, mv(m) = sum(Hact(ri(mon==m), :), 'all'); end
[~, o] = sort(mv, 'descend');
for k = 1:6, fprintf('  %2d 月  %10.1f kWh\n', o(k), mv(o(k))); end

fprintf('\n=== 两方案对照（报送窗口）===\n');
fprintf('  第一部分（完美信息，现已实现）%.2f 元\n', 12210827.42);
fprintf('  第二部分（预测驱动）        %.2f 元\n', sum(Zreal(ri)));
fprintf('  信息价值 VoI = %.2f%%（ΔZ = %.2f 元）\n', ...
        100*(sum(Zreal(ri))-12210827.42)/12210827.42, sum(Zreal(ri))-12210827.42);
