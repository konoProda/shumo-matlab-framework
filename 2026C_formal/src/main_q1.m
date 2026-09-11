% main_q1.m —— 问题一：典型日的计划购电策略
% 每天电价与小区负载相同、光伏为一天的预测功率；供能不低于负载，储能 0:00 与 24:00 储电量相同
% 依附件1 与附录1，建立确定性 MILP（公式 (1)~(8)），用 intlinprog 求解

clear; close all; clc;

%% 路径
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');

%% 参数（附录1 与附件1）
prm = struct( ...
    'T',       144, ...      % (P-1) 10 分钟时段数
    'dt',      1/6, ...      % (P-2) 时段长度 h
    'eta_ch',  0.90, ...     % (P-3) 充电效率
    'eta_dis', 0.90, ...     % (P-4) 放电效率
    'E_init',  6000, ...     % (P-5) 初始储电量 kWh
    'E_min',   1200, ...     % (P-6) 储电量下限
    'E_max',   10800, ...    % (P-7) 储电量上限
    'P_max',   5000);        % (P-8) 最大充放电功率 kW

%% 读取附件1（时间列存储类型混合，故不读该列，按序号建时间轴）
raw = readcell(fullfile(PROJ_ROOT, 'data', '附件', '附件1.xlsx'), 'Sheet', 'Sheet1');
price_v = cell2mat(raw(2:1+prm.T, 2));      % (I-3) 电价 元/kWh
load_p  = cell2mat(raw(2:1+prm.T, 3));      % (I-1) 小区负载 kW
pv_p    = cell2mat(raw(2:1+prm.T, 4));      % (I-2) 光伏预测 kW

%% 装配并求解
[f, intcon, A, b, Aeq, beq, lb, ub] = func_build_q1(price_v, load_p, pv_p, prm);
opts = optimoptions('intlinprog', 'Display', 'final');
tic;
[x, Z, exitflag, output] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opts);
t_solve = toc;

fprintf('=== 问题一求解 ===\n');
fprintf('  退出标记 exitflag = %d   （1 = 正常收敛）\n', exitflag);
fprintf('  求解耗时 = %.2f s\n', t_solve);
fprintf('  相对间隙 = %.3e\n', output.absolutegap);
fprintf('  全天购电费 = %.4f 元\n', Z);

%% 结果换算
T = prm.T;
sol = struct();
sol.G = x(1:T);                 % (V-1) 购电功率 kW
sol.C = x(T+1 : 2*T);           % (V-2) 充电功率
sol.D = x(2*T+1 : 3*T);         % (V-3) 放电功率
sol.E = x(3*T+1 : 4*T);         % (V-4) 时段末储电量 kWh
sol.V = x(4*T+1 : 5*T);         % (V-5) 弃光功率
sol.u = x(5*T+1 : 6*T);         % (V-6) 充放电状态
sol.price_v = price_v;

%% 校验（建模文档 §16）
rep = func_check_q1(x, price_v, load_p, pv_p, prm);
fprintf('\n=== 校验 ===\n');
fprintf('  平衡残差   %.3e\n', rep.bal_resid);
fprintf('  状态残差   %.3e\n', rep.state_resid);
fprintf('  最差越界   %.3e\n', max(struct2array(rep.viol)));
fprintf('  全天购电量 %.2f kWh    充电 %.2f kWh    放电 %.2f kWh    弃光 %.2f kWh\n', ...
        rep.buy_total, rep.chg_total, rep.dis_total, rep.curt_total);
if rep.pass
    fprintf('  校验结论：通过\n');
else
    fprintf('  校验结论：**未通过**，请检查\n');
end

% 数值零清理：求解器可能返回 -0.00 量级的负零，避免其进入交付件
x(abs(x) < 1e-9) = 0;
sol.G = x(1:T);        sol.C = x(T+1 : 2*T);   sol.D = x(2*T+1 : 3*T);
sol.E = x(3*T+1 : 4*T); sol.V = x(4*T+1 : 5*T); sol.u = x(5*T+1 : 6*T);

%% 落盘：完整 144 槽明细
mins = ((0:T-1) * 10).';
lab = arrayfun(@(m) sprintf('%02d:%02d-%02d:%02d', floor(m/60), mod(m,60), ...
              floor((m+10)/60), mod(m+10,60)), mins, 'UniformOutput', false);
out_tbl = table((1:T).', lab, sol.G*prm.dt, sol.C*prm.dt, sol.D*prm.dt, sol.E, sol.V*prm.dt, ...
    'VariableNames', {'slot','period','buy_kwh','chg_kwh','dis_kwh','E_kwh','curt_kwh'});
writetable(out_tbl, fullfile(PROJ_ROOT, 'outputs', 'q1_solution.csv'));

save(fullfile(PROJ_ROOT, 'outputs', 'q1_solution.mat'), 'sol', 'prm', 'Z', 'rep', 'output', 'exitflag');

%% 绘图数据落盘（figures/data/，plot 脚本只读不算）
fig_data_dir = fullfile(PROJ_ROOT, 'figures', 'data');
if ~exist(fig_data_dir, 'dir'); mkdir(fig_data_dir); end

writetable(table((1:T).', lab, price_v, sol.G*prm.dt, ...
    'VariableNames', {'slot','period','price','buy_kwh'}), ...
    fullfile(fig_data_dir, 'q1_price_buy.csv'));

E_start = [prm.E_init; sol.E(1:end-1)];     % 各槽起始储电量，首槽即 0:00 的初值
writetable(table((1:T).', lab, sol.C*prm.dt, sol.D*prm.dt, E_start, sol.E, ...
    'VariableNames', {'slot','period','chg_kwh','dis_kwh','E_start_kwh','E_kwh'}), ...
    fullfile(fig_data_dir, 'q1_soc.csv'));

%% 写结果文件 result1.xlsx
tab = func_write_q1(sol, prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result1.xlsx'), ...
    fullfile(PROJ_ROOT, 'outputs', 'result1.xlsx'));
fprintf('\n结果已写入 outputs/result1.xlsx 与 outputs/q1_solution.csv\n');

%% 论文表 1 / 表 2 数值
fprintf('\n=== 论文表1 指定时段购电量 ===\n');
for k = 1:numel(tab.t1_slot)
    fprintf('  %-12s  槽%3d  %10.4f kWh\n', tab.t1_label{k}, tab.t1_slot(k), tab.t1_buy(k));
end
fprintf('  全天购电量 %.4f kWh    全天购电费 %.4f 元\n', tab.t1_total, tab.t1_cost);

fprintf('\n=== 论文表2 储能充放电量 ===\n');
for b = 1:6
    fprintf('  %-12s  充电 %10.4f   放电 %10.4f kWh\n', tab.t2_label{b}, tab.t2_chg(b), tab.t2_dis(b));
end
fprintf('  0:00 储电量 %.2f kWh    24:00 储电量 %.2f kWh\n', tab.t2_E0, tab.t2_ET);
