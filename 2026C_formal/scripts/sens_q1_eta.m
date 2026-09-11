% sens_q1_eta.m — 问题一 充放电效率灵敏度（组内产物，不交付）
% 目的：题面"充放电效率 90%"未明示单程/往返，用参数扫描量化该口径对结果的影响

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
price_v = cell2mat(raw(2:145, 2));
load_p  = cell2mat(raw(2:145, 3));
pv_p    = cell2mat(raw(2:145, 4));

P = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90, ...
           'E_init',6000,'E_min',1200,'E_max',10800,'P_max',5000);
opt = optimoptions('intlinprog', 'Display', 'off');

eta_list = [0.85, 0.90, 0.95, sqrt(0.90)];
note = {'偏低（PbA 类）', '基准（题面取法）', '偏高（高效 PCS）', '若 90% 指往返效率'};

fprintf('=== 问题一 充放电效率灵敏度 ===\n');
fprintf('%-8s %-20s %14s %12s %12s\n', 'eta', '说明', '购电费(元)', '购电量(kWh)', '充放电量(kWh)');
fprintf('%s\n', repmat('-', 1, 72));
Zs = zeros(numel(eta_list), 1);
for k = 1:numel(eta_list)
    P.eta_ch = eta_list(k);  P.eta_dis = eta_list(k);
    [f, ic, A, b, Aeq, beq, lb, ub] = func_build_q1(price_v, load_p, pv_p, P);
    [x, Z] = intlinprog(f, ic, A, b, Aeq, beq, lb, ub, opt);
    G = x(1:144); C = x(145:288); D = x(289:432);
    Zs(k) = Z;
    fprintf('%-8.4f %-20s %14.2f %12.2f %12.2f\n', eta_list(k), note{k}, ...
            Z, sum(G)*P.dt, (sum(C)+sum(D))*P.dt);
end
fprintf('%s\n', repmat('-', 1, 72));
fprintf('相对基准(0.90)的费用变化：\n');
for k = 1:numel(eta_list)
    fprintf('  eta=%.4f : %+8.2f 元 (%+.2f%%)\n', eta_list(k), Zs(k)-Zs(2), 100*(Zs(k)-Zs(2))/Zs(2));
end
fprintf('\n结论：效率口径的影响达 ±%.2f%%，不可忽略；\n', ...
        100*max(abs(Zs-Zs(2)))/Zs(2));
fprintf('      若"90%%"指往返效率（两侧各 %.4f），购电费为 %.2f 元，较基准低 %.2f 元（%.2f%%）。\n', ...
        sqrt(0.9), Zs(4), Zs(2)-Zs(4), 100*(Zs(2)-Zs(4))/Zs(2));
fprintf('      论文须在模型假设处写明效率取法，并将该口径作敏感性说明。\n');
