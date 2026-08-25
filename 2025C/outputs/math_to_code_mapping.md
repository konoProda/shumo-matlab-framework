# 2025C 数学→代码映射表（/prep 最终版 v3，待编程手确认后进入 /code）

> 来源：建模手《模型构建与代码交接(2).md》v3（A1~B10、N1~N10 全部裁决已落地）
> 本文档公式编号由编程手统一编制，节号引用建模文档 v3 节号。
> 状态：**已确认（2026-08-24 编程手确认）**，作为 /code 输入。

## 0. 数据 I/O 规格

| 项 | 规格 |
|---|---|
| 输入 | `data/附件.xlsx`，工作表「男胎检测数据」1082×31、「女胎检测数据」605×31 |
| 列序 | A样本序号 B孕妇代码 C年龄 D身高 E体重 F末次月经 G IVF H检测日期 I抽血次数 J孕周文本 K BMI L原始读段数 M比对比例 N重复读段比例 O唯一比对读段数 P GC含量 Q Z13 R Z18 S Z21 T ZX U ZY V Y浓度 W X浓度 X GC13 Y GC18 Z GC21 AA过滤比例 AB非整倍体 AC怀孕次数 AD生产次数 AE胎儿健康 |
| 文本字段 | 孕周 `11w+6`→`11.8571`（兼容大小写 w/W）；AB 列含 T13/T18/T21 子串；妊娠方式三类：自然受孕/IUI/IVF |
| 输出 | `outputs/tables/*.csv`（各问结果表）、`figures/*.png`（300dpi）、`outputs/final_results.mat` |

## 1. 公共预处理（v3 §3）

| 公式编号 | 数学符号 | 含义 | 数据类型/维度 | 代码变量名 |
|---|---|---|---|---|
| P1 | \(t_{ij}=w+d/7\) | 连续孕周数（兼容大小写 w/W；异常置 NaN 剔除） | double, 1082×1（男）/605×1（女） | `gest_week`（记录层） |
| P2 | \(I_{ij}=\mathbf{1}(Y_{ij}\ge0.04)\) | 男胎达标标签 | int8 0/1, 1082×1 | `is_reach` |
| P3 | \(A_i=\mathbf{1}(AB_i\neq空)\) | 女胎异常标签；子标签按 T13/T18/T21 子串 | int8 0/1, 605×1 | `abn_label`, `abn_t13/abn_t18/abn_t21` |
| P4 | \(\overline{BMI}_i=\frac{1}{m_i}\sum_j BMI_{ij}\) | 孕妇历次有效 BMI 平均值（分组与达标比例按孕妇层） | double, 267×1（男） | `bmi_mean`（孕妇层）；`subj_id`（孕妇代码） |
| P5 | — | 首次观测达标时间（按孕周升序；后一次达标取后一次；均未达标记未观测） | double, 267×1 | `first_reach_time` |
| P6 | — | 女胎 BMI 缺失 1 条置 NaN；BMI 分层（四分位）时剔除该条 | — | `bmi_female` |

## 2. 问题一：相关特性与关系模型（v3 §4）

| 公式编号 | 数学符号 | 含义 | 数据类型/维度 | 代码变量名 |
|---|---|---|---|---|
| Q1-1 | \(r_k\)（Pearson） | Y 浓度与 t/BMI/Age/Weight/GC/Filter 的相关系数 | double, 6×1 | `corr_vec`, `corr_pval` |
| Q1-2 | \(\beta_0..\beta_5\) | 主回归 Y=β0+β1t+β2BMI+β3Age+β4GC+β5Filter+ε | double, 6×1 | `beta`；`beta_se, t_stat, p_val, r2, r2_adj, f_stat, resid` |
| Q1-3 | \(\beta_0..\beta_6\) | 交互回归（t,BMI,t·BMI,Age,GC,Filter） | double, 7×1 | `beta_int` |
| Q1-4 | \(\beta_0..\beta_5\) | 二次回归（t,BMI,t²,BMI²,t·BMI） | double, 6×1 | `beta_quad` |
| Q1-5 | \(\delta_0..\delta_5\) | 对照回归（t,Height,Weight,Age,Q），仅比较解释力 | double, 6×1 | `beta_hw` |
| Q1-6 | \(\sigma=std(\varepsilon)\) | 最终主模型残差标准差（N8 选择规则：默认交互模型；若交互项不显著且调整 R² 未提升则用基础模型） | 标量 | `sigma_resid`（供 Q2-8、Q3-4 使用） |

## 3. 问题二：BMI 分组与最佳时点（v3 §5，K=4）

| 公式编号 | 数学符号 | 含义 | 数据类型/维度 | 代码变量名 |
|---|---|---|---|---|
| Q2-1 | \(\alpha_0..\alpha_3\) | 简化回归 Ŷ=α0+α1t+α2BMI+α3t·BMI（全部 1082 条记录估计） | double, 4×1 | `alpha` |
| Q2-2 | \(p_g(t)=\frac{1}{N_g}\sum_{i\in G_g}\mathbf{1}(\hat Y_i(t,\overline{BMI}_i)\ge0.04)\) | 组预测达标比例（孕妇层计数） | double, K×\|T\| | `p_reach` |
| Q2-3 | \(b_0..b_K\)（K=4） | BMI 有序切点：b0=BMI_min、b4=BMI_max，枚举 3 切点；N1 判定顺序：先 K=4 且 n_min=20 → 不可行放宽 n_min=10 → 仍不可行报告不可行并输出 K=3 备选（不自动降组） | double, 5×1 | `bmi_edges`；`n_min=20` |
| Q2-4 | \(C(t)\) | 时间风险：t<13→1，13≤t<28→5，t≥28→20 | double, \|T\|×1 | `cost_time`；`c_risk=[1 5 20]` |
| Q2-5 | \(\lambda=10\) | 不达标惩罚系数（灵敏度测多个 λ） | 标量 | `lambda_risk` |
| Q2-6 | \(R_g(t)=C(t)+\lambda[1-p_g(t)]\) | 组总风险 | double, K×\|T\| | `risk` |
| Q2-7 | \(t_g^*=\arg\min_{t\in T} R_g(t)\) | 每组最佳时点；T={10,10+1/7,…,25}（按天，106 点） | double, K×1 | `t_opt`；`t_grid`（106×1） |
| Q2-8 | \(\hat Y_i^{(m)}(t)=\hat Y_i(t)+e_i^{(m)}\)，\(e_i^{(m)}\sim N(0,\sigma^2)\)，M=500 | 检测误差扰动（N7：固定 α 与切点，只扰动预测判据重算 t*；σ 用 Q1-6） | double, K×M | `noise`；`mc_iters=500`；输出 `t_opt_mc`（K×M）均值/标准差/范围 |

## 4. 问题三：多因素修正分组与时点（v3 §6）

| 公式编号 | 数学符号 | 含义 | 数据类型/维度 | 代码变量名 |
|---|---|---|---|---|
| Q3-1 | \(\gamma_0..\gamma_9\) | 多因素回归 Ŷ=γ0+γ1t+γ2BMI+γ3Age+γ4Grav+γ5Par+γ6IUI+γ7IVF+γ8Q+γ9t·BMI（1082 条记录层估计；自然受孕为基准组） | double, 10×1 | `gamma`；哑变量 `d_iui, d_ivf` |
| Q3-2 | \(Z_{ik}\)、\(q_k\) | 质量指标标准化与正向化：q_L=Z_L, q_M=Z_M, q_N=−Z_N, q_O=Z_O, q_AA=−Z_AA, q_GC=−\|GC−GC̄\|/s_GC | double, n×6 | `qual_q`（6 列：L,M,N,O,AA,GC） |
| Q3-3 | \(Q_i=\frac16\sum q_k\) | 等权质量综合指标（主结果；PCA 权重作对比）；孕妇层取历次平均 \(\overline Q_i\) | double, n×1 / 267×1 | `qual_score`；`qual_w=ones(6,1)/6`；`qual_mean`（孕妇层） |
| Q3-4 | \(\pi_i(t)=\Phi((\hat Y_i(t,\overline{BMI}_i,\overline Q_i)-0.04)/\sigma)\) | 含检测误差的个体达标概率（σ=Q1-6；Age/Grav/Par/妊娠方式取孕妇固定值） | double, 267×\|T\| | `pi_reach` |
| Q3-5 | \(p_g(t)=\frac{1}{N_g}\sum_{i\in G_g}\pi_i(t)\) | 组达标比例（孕妇层平均） | double, K×\|T\| | `p_reach3` |
| Q3-6 | \(\min\sum_g R_g(t_g)\) | 总风险最小（目标函数） | 标量 | `risk_total` |
| Q3-7 | \(p_g(t_g)\ge\eta\)（η=0.85，灵敏度测 0.80/0.85/0.90/0.95） | 达标比例下限（约束1）；N4 不可行处理：取 argmax p_g(t) 为推荐时点并标注"未达 η"，不自动改分组 | 标量 | `eta_target`；`eta_ok`（K×1 布尔） |
| Q3-8 | \(N_g\ge n_{min}\)、\(b_{g-1}<b_g\) | 组最小样本、边界递增（约束2,3） | 向量 | `bmi_edges3` |

## 5. 问题四：女胎异常判定（v3 §7）

| 公式编号 | 数学符号 | 含义 | 数据类型/维度 | 代码变量名 |
|---|---|---|---|---|
| Q4-1 | \(A_i,A_{13},A_{18},A_{21}\) | 标签（复用 P3） | int8, 605×1 | `abn_label`, `abn_t13/18/21` |
| Q4-2 | \(X_i\)（16 特征） | Z13/18/21、ZX、GC、GC13/18/21、读段类、BMI、Age、t；BMI/Age/t 只作分层，不进评分 | double, 605×16 | `feat_mat` |
| Q4-3 | \(D_Z=\|Z\|\)、\(D_{GC}=\|GC-\bar{GC}\|\)、\(\widetilde D=(D-D_{min})/(D_{max}-D_{min})\) | 偏离指标 + min-max 标准化 | double | `z_abs`, `gc_dev`, `norm_dev` |
| Q4-4 | \(D_{read}=\frac15[(1-\widetilde L)+(1-\widetilde M)+\widetilde N+(1-\widetilde O)+\widetilde{AA}]\) | 读段质量风险指标（0~1，越大风险越高） | double, 605×1 | `d_read` |
| Q4-5 | \(S_i=w_1\widetilde{\|Z_{13}\|}+w_2\widetilde{\|Z_{18}\|}+w_3\widetilde{\|Z_{21}\|}+w_4\widetilde{\|Z_X\|}+w_5\widetilde D_{GC}+w_6 D_{read}\) | 综合异常评分（等权 w=1/6 主结果；PCA 对比） | double, 605×1 | `abn_score`；`score_w` |
| Q4-6 | \(\theta^*=\arg\max_\theta J(\theta)\)，\(J=Se+Sp-1\) | Youden 指数选阈（N5 主准则）；同时输出 F1 曲线与偏召回阈值作对照 | 标量 | `theta_opt`；`youden`, `f1_curve` |
| Q4-7 | \(S_{13}=\widetilde{\|Z_{13}\|}+\rho\widetilde{\|GC_{13}-\bar{GC}_{13}\|}\)（18/21 同理），ρ=1（灵敏度 0.5/1/2） | 异常类型评分；N6 复合判据：仅对已判异常样本，\(S_{second}\ge0.8S_{max}\) 报复合（三项均满足报三复合） | double, 605×3 | `type_score`；`rho_gc=1` |
| Q4-8 | TP/FP/FN/TN | 混淆矩阵及 Accuracy/Recall/Precision/F1/Specificity | 2×2 | `cm`, `acc, rec, prec, f1, spec` |
| Q4-9 | — | BMI 四分位分层（有效 BMI 604 条，缺失剔除），分四层报告误判率/漏判率 | — | `bmi_layer`（4 层） |

## 6. 决议闭环记录

- A1~B10：见建模文档 v2 §1.1，全部落地。
- N1~N10：见建模文档 v3 §1.2，全部落地。
- 遗留小项（编程手 2026-08-24 已按建议确认）：
  1. §5.6 输出清单中"分组边界是否稳定"改由 λ 灵敏度分析报告；MC 只输出 t* 均值/标准差/范围；
  2. §5.6 与 §6.4 的 σ 口径统一按 N8（最终主模型残差标准差）。
