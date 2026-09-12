% test_q1.m — 问题一 一致性测试（组内产物，不交付）
% 覆盖：维度 / 特殊值 / 参考解 R1(解析) / 参考解 R2(LP下界) / 稳定性 / 收敛性 / 约束 /
%       反算交叉校验 / 与总能量平衡参考模型的最优值比对

clear; clc;
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(PROJ_ROOT, 'src'));
addpath(fullfile(PROJ_ROOT, 'tests'));

log_path = fullfile(PROJ_ROOT, 'outputs', 'test_log_q1.txt');
if exist(log_path, 'file'); delete(log_path); end
diary(log_path);

opt_off = optimoptions('intlinprog', 'Display', 'off');
P = struct('T',144,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90, ...
           'E_init',6000,'E_min',1200,'E_max',10800,'P_max',5000);

R = {};

fprintf('===== 问题一 一致性测试 =====\n');
fprintf('时间：%s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

%% T1 维度检查
[price_v, load_p, pv_p] = func_read_q1(PROJ_ROOT);   % 时间轴口径见该函数
[f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q1(price_v, load_p, pv_p, P);

d_ok = isequal(size(price_v), [144 1]) && numel(f) == 1152 && numel(intcon) == 144 ...
    && numel(lb) == 1152 && size(Aeq,1) == 577 && size(Aeq,2) == 1152 ...
    && size(A,1) == 288 && size(A,2) == 1152;
R(end+1,:) = {'T1 维度检查', d_ok, sprintf('变量%d；intcon%d；Aeq %dx%d；A %dx%d', ...
    numel(f), numel(intcon), size(Aeq,1), size(Aeq,2), size(A,1), size(A,2))};

nz_eq = full(sum(sum(Aeq~=0,2) >= 1)); nz_A = full(sum(sum(A~=0,2) == 2));
R(end+1,:) = {'T1b 约束行无空行', nz_eq == 577 && nz_A == 288, ...
    sprintf('Aeq非零行 %d/577；A非零行 %d/288', nz_eq, nz_A)};

% 辅助量恒等式
aux_ok = max(abs(aux.PVL + aux.Lbar - load_p)) < 1e-9 && max(abs(aux.PVL + aux.PVbar - pv_p)) < 1e-9;
R(end+1,:) = {'T1c 分流辅助量恒等式', aux_ok, ...
    sprintf('max|PVL+Lbar-L|=%.2e  max|PVL+PVbar-PV|=%.2e', ...
    max(abs(aux.PVL+aux.Lbar-load_p)), max(abs(aux.PVL+aux.PVbar-pv_p)))};

%% T2 特殊值检验
z = zeros(144,1); pc = 0.5*ones(144,1); Lc = 600*ones(144,1);
[az, bz, cz, dz, ez, fz, gz, hz] = deal([]);
[~, ~, ~, ~, ~, ~, ~, ~, aux0] = func_build_q1(pc, z, z, P);
[fz, iz, Az, bz2, Aeqz, beqz, lbz, ubz] = func_build_q1(pc, z, z, P);
[xz, Zz] = intlinprog(fz, iz, Az, bz2, Aeqz, beqz, lbz, ubz, opt_off);
R(end+1,:) = {'T2-S1 全零负载/光伏', abs(Zz) < 1e-6, sprintf('Z=%.3e（预期0）', Zz)};

[fz, iz, Az, bz2, Aeqz, beqz, lbz, ubz] = func_build_q1(pc, Lc, Lc, P);
[xz, Zz] = intlinprog(fz, iz, Az, bz2, Aeqz, beqz, lbz, ubz, opt_off);
R(end+1,:) = {'T2-S2 光伏=负载', abs(Zz) < 1e-6, sprintf('Z=%.3e（预期0）', Zz)};

[fz, iz, Az, bz2, Aeqz, beqz, lbz, ubz] = func_build_q1(pc, Lc, z, P);
[xz, Zz] = intlinprog(fz, iz, Az, bz2, Aeqz, beqz, lbz, ubz, opt_off);
Z_exp = 0.5 * 600 * (1/6) * 144;                 % = 7200
Cz = xz(3*144+1 : 4*144); Dz = xz(4*144+1 : 5*144);
R(end+1,:) = {'T2-S3 恒定电价负载（手算7200）', abs(Zz-Z_exp)/Z_exp < 1e-6, ...
    sprintf('Z=%.6f（预期%.6f，相对误差%.2e）；电池充%.2e 放%.2e', Zz, Z_exp, abs(Zz-Z_exp)/Z_exp, sum(Cz), sum(Dz))};

%% T3 参考解 R1（解析解）
P1 = struct('T',2,'dt',1/6,'eta_ch',0.90,'eta_dis',0.90,'E_init',6000,'E_min',1200,'E_max',10800,'P_max',5000);
[f1, i1, A1, b1, Aeq1, beq1, lb1, ub1] = func_build_q1([0.4;0.5], [600;600], [0;0], P1);
[x1, Z1] = intlinprog(f1, i1, A1, b1, Aeq1, beq1, lb1, ub1, opt_off);
Z1_exp = 0.4 * (600 + 600/0.81) / 6;
e1 = abs(Z1 - Z1_exp) / Z1_exp;
gch1 = x1(3); C1v = x1(7); D2v = x1(10);     % T=2 时：G^ch_1 / C_1 / D_2
ok1 = e1 < 1e-6 && abs(C1v - 600/0.81) < 1e-4 && abs(D2v - 600) < 1e-4;
R(end+1,:) = {'T3 参考解R1（解析89.3827）', ok1, ...
    sprintf('Z=%.6f（预期%.6f，相对误差%.2e）；C1=%.4f D2=%.4f', Z1, Z1_exp, e1, C1v, D2v)};

%% T4 参考解 R2（LP 松弛下界）
[xm, Zm, ef, out] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opt_off);
[lp_x, Zlp, lp_ef] = linprog(f, A, b, Aeq, beq, lb, ub, optimoptions('linprog','Display','off'));
R(end+1,:) = {'T4 参考解R2（LP下界<=MILP）', (lp_ef == 1) && (Zlp <= Zm + 1e-6), ...
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

%% T7 约束检查（显式分流模型）
rep = func_check_q1(xm, price_v, load_p, pv_p, P, aux);
GL = xm(1:144); GC = xm(145:288); PVC = xm(289:432);
C = xm(433:576); D = xm(577:720); E = xm(721:864); V = xm(865:1008); u = xm(1009:1152);
chk = [ rep.flow_load; rep.flow_chg; rep.flow_pv; rep.state_resid; rep.total_bal;
        max(0, -min(GL)); max(0, -min(GC));
        max([0; max(PVC - aux.PVbar); -min(PVC)]);
        max([0; max(C)-5000; -min(C)]); max([0; max(D)-5000; -min(D)]);
        max([0; max(D - aux.Lbar)]);
        max([0; P.E_min-min(E); max(E)-P.E_max]);
        max([0; max(V - aux.PVbar); -min(V)]);
        max(abs(u - round(u))); max(min(C,D)); abs(E(end) - P.E_init) ];
names = {'负荷平衡','充电来源','光伏剩余','状态残差','总平衡(导出)', ...
         'G^L>=0','G^ch>=0','PV^ch上下界','C上下界','D上下界','D<=Lbar', ...
         'E上下界','V上下界','u为0/1','无同时充放','E_T=E_0'};
for k = 1:numel(names)
    R(end+1,:) = {sprintf('T7-%-2d %s', k, names{k}), chk(k) < 1e-6, sprintf('%.3e', chk(k))};
end

%% T8 反算交叉校验（模型内流量 vs 由 (G,C,D,V) 反算）
GLr = aux.Lbar - D;                       % 条① 反算
PVCr = aux.PVbar - V;                     % 条③ 反算
GCr = C - PVCr;                           % 条② 反算
e_max = max([abs(GLr-GL); abs(PVCr-PVC); abs(GCr-GC)]);
R(end+1,:) = {'T8 反算交叉校验', e_max < 1e-6, ...
    sprintf('max|模型值-反算值| = %.3e kW', e_max)};

%% T9 与总能量平衡参考模型的最优值比对
[fr, ir, Ar, br, Aeqr, beqr, lbr, ubr] = func_build_q1_ref(price_v, load_p, pv_p, P);
[~, Zr] = intlinprog(fr, ir, Ar, br, Aeqr, beqr, lbr, ubr, opt_off);
dZ = abs(Zr - Zm);
R(end+1,:) = {'T9 与总平衡参考模型比对', dZ < 1e-4 && numel(fr) == 864, ...
    sprintf('Z_显式分流=%.6f  Z_总平衡=%.6f  差=%.3e 元（参考模型变量%d）', Zm, Zr, dZ, numel(fr))};

%% 汇总
fprintf('\n%-34s %-6s %s\n', '测试项', '结论', '说明');
fprintf('%s\n', repmat('-', 1, 112));
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
fprintf('全天购电费 Z = %.4f 元   购电量 = %.4f kWh\n', Zm, rep.buy_total);
fprintf('能源流向：光伏供负载 %.4f  光伏充电 %.4f  弃光 %.4f  外网供负载 %.4f  外网充电 %.4f kWh\n', ...
        rep.pv_load, rep.pv_chg, rep.curt_total, rep.grid_load, rep.grid_chg);

save(fullfile(PROJ_ROOT, 'outputs', 'test_results_q1.mat'), 'R', 'allpass', 'Zm', 'Zlp', 'Zr', 'ef', 'out', 'rep');
diary off;
