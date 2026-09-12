% sens_q2_eta.m —— 问题二 充放电效率灵敏度（组内产物，不交付）
% 效率口径为题面未明示项（decisions_q1.md R3）：两侧各 0.90 即往返 0.81。
% 输出：outputs/q2_eta.csv

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

base = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000, ...
              'E_min',1200,'E_max',10800,'P_max',5000,'kappa_em',5);
T = base.T;
optM = optimoptions('intlinprog', 'Display', 'off');

[price_v, load_m, pv_m, day_list] = func_read_q2(PROJ_ROOT);
D = size(load_m, 1);
ri = find(day_list == datetime(2025,2,1)) : D;

eta_list = [0.85; 0.90; 0.95; sqrt(0.90)];        % 末项 = 若 90% 指往返，则单侧 0.9487
Zc = zeros(numel(eta_list), 1);
for k = 1:numel(eta_list)
    prm = base;  prm.eta_ch = eta_list(k);  prm.eta_dis = eta_list(k);
    E_now = prm.E_init;  Z = 0;
    for d = 1:D
        [f, ic, A, b, Aeq, beq, lb, ub, aux] = ...
            func_build_q2(price_v, load_m(d,:).', pv_m(d,:).', E_now, prm, true);
        [x, Zd] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, optM);
        E_now = x(aux.idx.E + T - 1);
        if d >= ri(1); Z = Z + Zd; end
    end
    Zc(k) = Z;
    fprintf('  eta = %.4f（往返 %.4f）  窗口购电费 %.4f 元\n', ...
            eta_list(k), eta_list(k)^2, Z);
end

rel = 100*(Zc - Zc(2))/Zc(2);
tab = table(eta_list, eta_list.^2, Zc, rel, ...
    'VariableNames', {'eta_side','eta_round','cost_yuan','rel_pct'});
writetable(tab, fullfile(PROJ_ROOT, 'outputs', 'q2_eta.csv'));
fprintf('已写入 outputs/q2_eta.csv\n');
