% main_vegetable.m — 2023c C题 蔬菜类商品自动定价与补货决策 主程序
% 数学依据: 2023c/data/建模.md（公式编号见各函数注释）
% 运行方式: matlab -batch "run('src/main_vegetable.m')"（pwd 可为任意目录）
%
% 流水线: 数据预处理 → 问题1关联分析 → 问题2品类LP → 问题3单品MILP → 保存结果
% 裁定记录: 见 outputs/math_to_code_mapping.md 第 6 节（Q1~Q9）

clear; close all; clc;

%% ================= 0. 路径与全局参数（集中定义，方便调参） =================
PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..');  % 题目根目录 shumo/2023c/
DATA_DIR  = fullfile(PROJ_ROOT, 'data');                       % 官方数据
OUT_DIR   = fullfile(PROJ_ROOT, 'outputs');                    % 结果与日志
FIG_DIR   = fullfile(PROJ_ROOT, 'figures');                    % 图表
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end                 % 兜底: 目录缺失则创建
if ~exist(FIG_DIR, 'dir'), mkdir(FIG_DIR); end

% ---- 题设常量 ----
N_CLASS     = 6;                % 蔬菜品类数（题目给定）
FORECAST_START = datetime(2023, 7, 1);   % 问题2决策期首日: 2023-07-01
HORIZON_Q2  = 7;                % 问题2决策天数: 2023-07-01 ~ 07
L_SHELF     = 27;               % 问题3上架单品数下限（题目给定）
U_SHELF     = 33;               % 问题3上架单品数上限（题目给定）
MIN_DISPLAY = 2.5;              % 问题3最小陈列量 2.5 kg（题目给定）

% ---- Q1~Q9 裁定参数 ----
% Q2: 批发价外推窗口（2023-06-24~30 销量加权均价, 7天同常数）+ 敏感性 ±5%/±10%
W_FORECAST_DAYS = 7;            % 外推取平均的天数
W_SENS_RATIOS   = [0.95 1.05 0.90 1.10];   % 批发价敏感性: ±5%, ±10%
% Q3: 数据驱动空间容量 V = max(67.5, 历史6-7月日总销量95%分位); s_i=1
V_LOWER      = L_SHELF * MIN_DISPLAY;      % = 67.5 kg（公式: 27×2.5）
V_QUANTILE   = 0.95;            % 历史6-7月日总销量95%分位
V_SENS_RATIOS = [0.8 0.9 1.0 1.1 1.2];     % V 敏感性五点
% Q4: 问题2 主模型方案A(固定加成) + 对比方案B(价格离散)
N_PRICE_LEVELS = 10;            % 方案B价格离散档数 K
% Q5: 问题3 两阶段策略 — 先纯利润目标(公式5.4); 若品类需求满足率极端则暂停询问编程手
DEMAND_SAT_ALERT = 0.30;        % 品类需求满足率低于此值视为"极端", 触发暂停
% 方案b: 各品类需求满足率下限 = 50% (扫描结果: 仅损失5.06%利润)
Q3_SAT_LB = 0.50;
% Q6: 需求回归窗口: 近期30天为主, 全3年对比
REGRESS_WINDOW_DAYS = 30;
% Q7: 退货行剔除; 打折行剔除出需求回归(统计描述保留)
% Q8: 单日缺失线性插值, 连续缺失前向填充
% Q9: 销量求和聚合; 批发价/售价按销量加权平均
BIG_M = 100;                    % 大M常数(建模文档5.2, 用于二元-连续关联)

%% ================= 1. 数据预处理（建模文档第2节） =================
% 说明: 附件2为39MB xlsx, MATLAB readtable 直读极慢(实测附件3已>6min),
%       数据通道(Q3修正2): scripts/preprocess.py 流式解析生成CSV → MATLAB读CSV
% 产物: outputs/product_info.csv / daily_sales.csv / wholesale_price.csv / category_daily.csv
% 接口: prod_info = func_preprocess(PROJ_ROOT)
prod_info = func_preprocess(PROJ_ROOT);   % table: 单品编码|名称|分类编码|分类名称|损耗率

%% ================= 2. 问题1 关联度分析（建模文档第3节, 公式3.3） =================
% 公式(3.3): rho_ij = 1 - 6*Σ(R_i(t)-R_j(t))^2 / (T*(T^2-1))
%             t = rho*sqrt((T-2)/(1-rho^2));  p = 2*(1-F_t(|t|))
% 输出: 品类6×6与单品251×251相关系数矩阵+显著性; 热力图/层次聚类图
% 接口: stats_q1 = func_q1_statistics(prod_info, PROJ_ROOT)
stats_q1 = func_q1_statistics(prod_info, PROJ_ROOT);   % struct(见接口说明)

%% ================= 3. 问题2 品类层面LP（建模文档第4节, 公式4.2~4.5） =================
% 目标(4.4): max Z = Σ_t Σ_c (p_{c,t} - ŵ_{c,t}) * x_{c,t},  ŵ=w*(1+ℓ̄)   [公式4.2]
% 约束(4.3): x≤a+b*p; p∈[p^min,p^max]; Σs*x≤V; x≥0
% 方案A(主模型, 公式4.5): p_{c,t}=(1+η_c)*w_{c,t} → 标准LP → linprog
% 方案B(对比):  价格离散K档+二元变量 → MILP → intlinprog
% 敏感性: 批发价±5%/±10%(Q2); 空间V五点0.8~1.2(Q3)
% 接口: result_q2 = func_q2_category_lp(stats_q1, prod_info, PROJ_ROOT)
result_q2 = func_q2_category_lp(stats_q1, prod_info, PROJ_ROOT);   % struct(见接口说明)

%% ================= 4. 问题3 单品层面MILP（建模文档第5节, 公式5.1~5.4） =================
% 目标(5.4): max Z = Σ_i (p_i - w_i*(1+ℓ_i)) * x_i
% 约束(5.3): 27≤Σy_i≤33; x_i≥2.5*y_i; x_i≤a_i+b_i*p_i; p∈[p^min*y, p^max*y];
%            Σs_i*x_i≤V; 离散关联(Σz=y, p=Σp^(k)z, x≤Σ(a+b*p^(k))z, x≤M*y)
% 候选单品: 2023-06-24~30 可售品种; 求解器 intlinprog(HiGHS)
% Q5两阶段: 纯利润求解后检查各品类需求满足率, 低于 DEMAND_SAT_ALERT 则暂停询问编程手
% 接口: result_q3 = func_q3_item_milp(stats_q1, prod_info, PROJ_ROOT, save_figs, sat_lb)
result_q3 = func_q3_item_milp(stats_q1, prod_info, PROJ_ROOT, true, Q3_SAT_LB);

%% ================= 5. 结果保存（save 使用绝对路径, 避免默认路径依赖） =================
save(fullfile(OUT_DIR, 'final_results.mat'), 'prod_info', 'stats_q1', 'result_q2', 'result_q3');
fprintf('[main] 主程序执行完毕, 结果已保存至 %s\n', fullfile(OUT_DIR, 'final_results.mat'));
