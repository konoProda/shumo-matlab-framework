% main_q1.m —— 问题一：典型日的计划购电策略（显式分流模型）
% 每天电价与小区负载相同、光伏为一天的预测功率；供能不低于负载，储能 0:00 与 24:00 储电量相同
% 依附件1 与附录1，建立显式分流 MILP（公式 (1)~(8)），用 intlinprog 求解

clear; close all; clc;

%% 路径
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..', '..');  % 入口在 src/问题X/ 下，需上溯两层到题目根目录（2026-09-13 分目录整理）

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

%% 读取附件1（时间轴口径见 func_read_q1）
[price_v, load_p, pv_p] = func_read_q1(PROJ_ROOT);

%% 装配并求解
[f, intcon, A, b, Aeq, beq, lb, ub, aux] = func_build_q1(price_v, load_p, pv_p, prm);
opts = optimoptions('intlinprog', 'Display', 'final');
tic;
[x, Z, exitflag, output] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, opts);
t_solve = toc;

fprintf('=== 问题一求解（显式分流模型）===\n');
fprintf('  变量规模 = %d（%d 连续 + %d 二值）\n', numel(f), numel(f)-numel(intcon), numel(intcon));
fprintf('  退出标记 exitflag = %d   （1 = 正常收敛）\n', exitflag);
fprintf('  求解耗时 = %.2f s\n', t_solve);
fprintf('  相对间隙 = %.3e\n', output.absolutegap);
fprintf('  全天购电费 = %.4f 元\n', Z);

%% 结果换算
T = prm.T;
sol = struct();
sol.GL  = x(1:T);               % 外网供负载 kW
sol.GC  = x(T+1 : 2*T);         % 外网供储能充电 kW
sol.PVC = x(2*T+1 : 3*T);       % 光伏供储能充电 kW
sol.C   = x(3*T+1 : 4*T);       % 储能充电 kW
sol.D   = x(4*T+1 : 5*T);       % 储能放电 kW
sol.E   = x(5*T+1 : 6*T);       % 时段末储电量 kWh
sol.V   = x(6*T+1 : 7*T);       % 弃光 kW
sol.u   = x(7*T+1 : 8*T);       % 充放电状态
sol.price_v = price_v;
sol.aux = aux;

%% 校验
rep = func_check_q1(x, price_v, load_p, pv_p, prm, aux);
fprintf('\n=== 校验 ===\n');
fprintf('  负荷平衡残差 %.3e   充电来源残差 %.3e   光伏剩余残差 %.3e\n', ...
        rep.flow_load, rep.flow_chg, rep.flow_pv);
fprintf('  状态残差     %.3e   总平衡(导出)  %.3e   最差越界 %.3e\n', ...
        rep.state_resid, rep.total_bal, max(struct2array(rep.viol)));
if rep.pass
    fprintf('  校验结论：通过\n');
else
    fprintf('  校验结论：**未通过**，请检查\n');
end

% 数值零清理：求解器可能返回 -0.00 量级的负零，避免其进入交付件
x(abs(x) < 1e-9) = 0;
sol.GL  = x(1:T);        sol.GC  = x(T+1 : 2*T);   sol.PVC = x(2*T+1 : 3*T);
sol.C   = x(3*T+1 : 4*T); sol.D  = x(4*T+1 : 5*T); sol.E   = x(5*T+1 : 6*T);
sol.V   = x(6*T+1 : 7*T); sol.u  = x(7*T+1 : 8*T);

%% 落盘：完整 144 槽明细
mins = ((0:T-1) * 10).';
lab = arrayfun(@(m) sprintf('%02d:%02d-%02d:%02d', floor(m/60), mod(m,60), ...
              floor((m+10)/60), mod(m+10,60)), mins, 'UniformOutput', false);
out_tbl = table((1:T).', lab, price_v, (sol.GL+sol.GC)*prm.dt, sol.GL*prm.dt, sol.GC*prm.dt, ...
    aux.PVL*prm.dt, sol.PVC*prm.dt, sol.C*prm.dt, sol.D*prm.dt, sol.V*prm.dt, sol.E, ...
    'VariableNames', {'slot','period','price','buy_kwh','g_load_kwh','g_chg_kwh', ...
                      'pv_load_kwh','pv_chg_kwh','chg_kwh','dis_kwh','curt_kwh','E_kwh'});
% 逐槽结果算"统计中间件"（与其它问的逐日统计同类；见 outputs/README.md 的分类口径）
SUB = fullfile(PROJ_ROOT, 'outputs', '统计中间件');
if exist(SUB, 'dir') ~= 7; mkdir(SUB); end
writetable(out_tbl, fullfile(SUB, 'q1_solution.csv'));

save(fullfile(SUB, 'q1_solution.mat'), 'sol', 'prm', 'aux', 'Z', 'rep', 'output', 'exitflag');

%% 绘图数据落盘（写入各图件文件夹，与绘图脚本同目录；plot 脚本只读不算）
fig1 = fullfile(PROJ_ROOT, 'figures', '问题一', '01 典型日计划购电策略');
fig2 = fullfile(PROJ_ROOT, 'figures', '问题一', '02 储能充放电与储电量');

writetable(table((1:T).', lab, price_v, (sol.GL+sol.GC)*prm.dt, ...
    'VariableNames', {'slot','period','price','buy_kwh'}), ...
    fullfile(fig1, 'data.csv'));

E_start = [prm.E_init; sol.E(1:end-1)];     % 各槽起始储电量，首槽即 0:00 的初值
writetable(table((1:T).', lab, sol.C*prm.dt, sol.D*prm.dt, E_start, sol.E, ...
    'VariableNames', {'slot','period','chg_kwh','dis_kwh','E_start_kwh','E_kwh'}), ...
    fullfile(fig2, 'data.csv'));

%% 写结果文件 result1.xlsx
tab = func_write_q1(sol, prm, ...
    fullfile(PROJ_ROOT, 'data', '附件', '附件5', 'result1.xlsx'), ...
    fullfile(PROJ_ROOT, 'outputs', 'result1.xlsx'));
fprintf('\n结果已写入 outputs/result1.xlsx 与 outputs/统计中间件/q1_solution.csv\n');


% ……（本段为控制台结果打印，不含求解逻辑，附录从略；完整代码见支撑材料）
