% test_q1.m — 问题一 一致性测试（组内产物，不交付）
% 覆盖：维度检查 / 特殊值检验 / 参考解对比（R1 解析解 + R2 LP 松弛下界）/ 稳定性 / 收敛性 / 约束检查

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));

log_path = fullfile(PROJ_ROOT, 'outputs', 'test_log_q1.txt');
if exist(log_path, 'file'); delete(log_path); end
diary(log_path);

opt_off = optimoptions('intlinprog', 'Display', 'off');
P = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90, ...
           'E_init',6000,'E_min',1200,'E_max',10800,'P_max',5000);

R = {};   % 每项：{名称, 是否通过, 说明}

fprintf('===== 问题一 一致性测试 =====\n');
fprintf('时间：%s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

%% T1 维度检查
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
price_v = cell2mat(raw(2:1+P.T, 2));
load_p  = cell2mat(raw(2:1+P.T, 3));
pv_p    = cell2mat(raw(2:1+P.T, 4));
[f, intcon, A, b, Aeq, beq, lb, ub] = func_build_q1(price_v, load_p, pv_p, P);

d_ok = isequal(size(price_v), [144 1]) && isequal(size(load_p), [144 1]) && isequal(size(pv_p), [144 1]) ...
    && numel(f) == 864 && numel(intcon) == 144 && numel(lb) == 864 && numel(ub) == 864 ...
    && size(Aeq,1) == 289 && size(Aeq,2) == 864 && size(A,1) == 288 && size(A,2) == 864;
R(end+1,:) = {'T1 维度检查', d_ok, sprintf('输入144x1；变量%d；intcon%d；Aeq %dx%d；A %dx%d', ...
    numel(f), numel(intcon), size(Aeq,1), size(Aeq,2), size(A,1), size(A,2))};

nz_ok = full(all(sum(Aeq ~= 0, 2) >= 1)) && full(all(sum(A ~= 0, 2) == 2));
n_eq = full(sum(sum(Aeq~=0,2) >= 1));
n_A  = full(sum(sum(A~=0,2) == 2));
R(end+1,:) = {'T1b 约束行无空行', nz_ok, sprintf('Aeq非零行 %d/%d；A非零行 %d/%d', ...
    n_eq, size(Aeq,1), n_A, size(A,1))};

%% T2 特殊值检验
% S1 全零负载与光伏 → 无购电
P2 = P; P2.T = 144;
z = zeros(144,1); pc = 0.5*ones(144,1);
[fz, iz, Az, bz, Aeqz, beqz, lbz, ubz] = func_build_q1(pc, z, z, P2);
[xz, Zz] = intlinprog(fz, iz, Az, bz, Aeqz, beqz, lbz, ubz, opt_off);
R(end+1,:) = {'T2-S1 全零负载/光伏', abs(Zz) < 1e-6, sprintf('Z=%.3e（预期0）', Zz)};

% S2 光伏恒等于负载 → 无购电
Lc = 600*ones(144,1);
[fz, iz, Az, bz, Aeqz, beqz, lbz, ubz] = func_build_q1(pc, Lc, Lc, P2);
[xz, Zz] = intlinprog(fz, iz, Az, bz, Aeqz, beqz, lbz, ubz, opt_off);
R(end+1,:) = {'T2-S2 光伏=负载', abs(Zz) < 1e-6, sprintf('Z=%.3e（预期0）', Zz)};

% S3 恒定电价+恒定负载+无光伏 → 无套利空间，购电费可手算
[fz, iz, Az, bz, Aeqz, beqz, lbz, ubz] = func_build_q1(pc, Lc, z, P2);
[xz, Zz] = intlinprog(fz, iz, Az, bz, Aeqz, beqz, lbz, ubz, opt_off);
Z_exp = 0.5 * 600 * (1/6) * 144;                 % = 7200
Cz = xz(145:288); Dz = xz(289:432);
R(end+1,:) = {'T2-S3 恒定电价负载（手算7200）', abs(Zz-Z_exp)/Z_exp < 1e-6, ...
    sprintf('Z=%.6f（预期%.6f，相对误差%.2e）；电池充%.2e 放%.2e', Zz, Z_exp, abs(Zz-Z_exp)/Z_exp, sum(Cz), sum(Dz))};

%% T3 参考解 R1（解析解，建模手确认单 §4）
P1 = struct('T',2,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000,'E_min',1200,'E_max',10800,'P_max',5000);
[f1, i1, A1, b1, Aeq1, beq1, lb1, ub1] = func_build_q1([0.4;0.5], [600;600], [0;0], P1);
[x1, Z1] = intlinprog(f1, i1, A1, b1, Aeq1, beq1, lb1, ub1, opt_off);
Z1_exp = 0.4 * (600 + 600/0.81) / 6;
e1 = abs(Z1 - Z1_exp) / Z1_exp;
ok1 = e1 < 1e-6 && abs(x1(3) - 600/0.81) < 1e-4 && abs(x1(6) - 600) < 1e-4;
R(end+1,:) = {'T3 参考解R1（解析89.3827）', ok1, ...
    sprintf('Z=%.6f（预期%.6f，相对误差%.2e）；C1=%.4f D2=%.4f', Z1, Z1_exp, e1, x1(3), x1(6))};

%% T4 参考解 R2（LP 松弛下界，建模手确认单 §5）
[xm, Zm, ef, out] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opt_off);
[lp_x, Zlp, lp_ef] = linprog(f, A, b, Aeq, beq, lb, ub, optimoptions('linprog','Display','off'));
ok4 = (lp_ef == 1) && (Zlp <= Zm + 1e-6);
R(end+1,:) = {'T4 参考解R2（LP下界<=MILP）', ok4, ...
    sprintf('Z_LP=%.6f  Z_MILP=%.6f  差=%.3e', Zlp, Zm, Zm-Zlp)};

%% T5 稳定性检验（确定性算法，重复 10 次）
Zv = zeros(10,1);
for k = 1:10
    [~, Zv(k)] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opt_off);
end
sd = std(Zv); rsd = sd / abs(mean(Zv));
R(end+1,:) = {'T5 稳定性（10次重复）', sd < 1e-3 && rsd < 0.01, ...
    sprintf('std=%.3e 相对std=%.3e（阈值1e-3 / 1%%）', sd, rsd)};

%% T6 收敛性检验
R(end+1,:) = {'T6 收敛性（MILP间隙）', ef == 1 && out.absolutegap < 1e-4, ...
    sprintf('exitflag=%d  绝对间隙=%.3e', ef, out.absolutegap)};

%% T7 约束检查（建模文档 §16.3 清单）
rep = func_check_q1(xm, price_v, load_p, pv_p, P);
G = xm(1:144); C = xm(145:288); D = xm(289:432); E = xm(433:576); V = xm(577:720); u = xm(721:864);
chk = [ rep.bal_resid;
        rep.state_resid;
        max(0, -min(G));
        max([0; max(C)-5000; -min(C)]);
        max([0; max(D)-5000; -min(D)]);
        max([0; P.E_min-min(E); max(E)-P.E_max]);
        max([0; -min(V); max(V - max(pv_p-load_p,0))]);
        max(abs(u - round(u)));
        max(min(C,D));
        abs(E(end) - P.E_init) ];
names = {'平衡残差','状态残差','G>=0','C上下界','D上下界','E上下界','V上下界','u为0/1','无同时充放','E_T=E_0'};
for k = 1:numel(names)
    R(end+1,:) = {sprintf('T7-%-2d %s', k, names{k}), chk(k) < 1e-6, sprintf('%.3e', chk(k))};
end

%% 汇总
fprintf('\n%-34s %-6s %s\n', '测试项', '结论', '说明');
fprintf('%s\n', repmat('-', 1, 110));
for k = 1:size(R,1)
    if R{k,2}; tag = '通过'; else; tag = '**失败**'; end
    fprintf('%-34s %-8s %s\n', R{k,1}, tag, R{k,3});
end
allpass = all(cell2mat(R(:,2)));
if allpass
    fprintf('\n总体结论：全部通过\n');
else
    fprintf('\n总体结论：存在失败项\n');
end
fprintf('全天购电费 Z = %.4f 元   全天购电量 = %.4f kWh\n', Zm, sum(G)*P.dt);
fprintf('充电 %.2f kWh  放电 %.2f kWh  弃光 %.2f kWh\n', sum(C)*P.dt, sum(D)*P.dt, sum(V)*P.dt);

save(fullfile(PROJ_ROOT, 'outputs', 'test_results_q1.mat'), 'R', 'allpass', 'Zm', 'Zlp', 'ef', 'out', 'rep');
diary off;
