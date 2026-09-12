# 问题二 第四轮（7 日滚动 SAA 两阶段随机 MILP）数学↔代码映射表

> 生成阶段：/prep（Q2c 轮）｜ 日期：2026-09-12
> 依据：《问题二_7日滚动SAA两阶段MILP_给编程手.md》与 `outputs/decisions_q2c.md`
> 符号编号沿用方案文档章节号；「代码位置」一列在 /report 阶段回填并复核。

## 一、集合与下标

| 编号 | 符号 | 含义 | 类型/维度 | 代码变量名 |
|---|---|---|---|---|
| §2 | $d$ | 决策日（滚动窗口首日） | 标量 | `d` |
| §2 | $t$ | 日内时段（10 min） | 1..144 | `t` / 列内位置 `(1:T)` |
| §2 | $\tau$ | 视野内日序号（1 = 当天） | 1..R | `j`（代码用 `j` 表视野内第 j 日） |
| §2 | $\omega$ | 情景 | 1..K | `w` |
| §2 | $i$ | 小时（SOC 分时统计） | 1..24 | `hidx = floor((0:T-1)/6)+1` |

## 二、参数

| 编号 | 符号 | 含义 | 类型/维度 | 代码变量名 |
|---|---|---|---|---|
| §3 | $T$ | 每日时段数 | 144 | `prm.T` |
| §3 | $\Delta t$ | 时段长度 | 1/6 h | `prm.dt` |
| §3 | $R$ | 滚动视野天数 | 7（对照 1、3） | `R` / `cfg.R` |
| §3 | $K$ | 情景数 | 4（稳定性 8） | `K` |
| §3 | $\pi_t$ | 正常购电电价 | 144×1 元/kWh | `price_v` |
| §3 | $\kappa_{em}$ | 紧急购电倍率 | 5 | `prm.kappa_em` |
| §3 | $\eta_c,\eta_d$ | 充/放效率 | 0.90 | `prm.eta_ch` / `prm.eta_dis` |
| §3 | $E_{\min},E_{\max}$ | 储电上下限 | kWh | `prm.E_min` / `prm.E_max` |
| §3 | $P_{\max}$ | 充放电功率上限 | kW | `prm.P_max` |
| §3 | $\bar L,\overline{PV}$ | 情景负荷/光伏 | R×T×K kW | `Lsc` / `PVsc` |
| §4.1 | $\bar L^{+}$ | 光伏不足部分 $\max(\bar L-\overline{PV},0)$ | R×T×K | `aux.Lbar` |
| §4.1 | $\overline{PV}^{+}$ | 光伏余量 $\max(\overline{PV}-\bar L,0)$ | R×T×K | `aux.PVbar` |
| §4.1 | $PV^{L}$ | 光伏直供负荷 $\min(\overline{PV},\bar L)$ | R×T×K | `aux.PVL` |

## 三、决策变量

### 3.1 第一阶段（情景无关）

| 编号 | 符号 | 含义 | 类型/维度 | 代码变量名 |
|---|---|---|---|---|
| §6 | $G^{plan}_{d,t}$ | 当天向外部电网提交的计划购电功率 | T×1 kW | `x(aux.iGP)`；结果存 `out.buy_kw(d,:)` |

### 3.2 第二阶段（逐情景 $\omega$，逐日 $\tau$）

每个 $(w,j)$ 块内变量按 `aux.offB` 的固定偏移排列（`func_build_q2c.m` 第 33~35 行）：

| 编号 | 符号 | 含义 | 类型/维度 | 代码变量名 |
|---|---|---|---|---|
| §7 | $G^{L}$ | 正常购电直供负荷 | T×1 kW | `offB.GL` |
| §7 | $G^{ch}$ | 正常购电用于充电 | T×1 kW | `offB.GC` |
| §7 | $PV^{ch}$ | 光伏用于充电 | T×1 kW | `offB.PVC` |
| §7 | $C$ | 充电功率 | T×1 kW | `offB.C` |
| §7 | $D$ | 放电功率 | T×1 kW | `offB.D` |
| §7 | $E$ | 储电量（时段末） | T×1 kWh | `offB.E` |
| §7 | $V$ | 未消纳光伏（弃光） | T×1 kW | `offB.V` |
| §7 | $H$ | 紧急购电功率 | T×1 kW | `offB.H` |
| §7 | $W$ | **已计划购买但未被利用**的正常购电 | T×1 kW | `offB.W` |
| §7 | $u$ | 充放电互斥二值 | T×1 {0,1} | `offB.U` |
| §12 | $G^{plan,(ω)}_{\tau,t}$ | **未来日**的情景内临时计划购电（非当天提交） | T×1 kW | `offB.GPF`（仅 $j\ge2$） |

> 当天块（j=1）10 个变量、未来块（j≥2）11 个变量；故 `func_build_q2c.m` 中
> 当天块的 $u$ 偏移为 `offB.U - 1`。

### 3.3 单情景退化

$K=1$ 且情景 = 中心预测时（C2 退化路径、T6 完美信息退化），模型退化为确定性 MILP。

## 四、目标函数（§13）

$$\min\; Z_d \;=\; \underbrace{\sum_t \pi_t G^{plan}_{d,t}\Delta t}_{\text{第一阶段，不除以 }K} \;+\; \frac1K\sum_\omega \Big[\underbrace{\sum_t 5\pi_t H_{d,t}\Delta t}_{\text{当日紧急}} + \sum_{\tau>d}\sum_t \big(\pi_t G^{plan,(\omega)}_{\tau,t} + 5\pi_t H_{\tau,t}\big)\Delta t\Big]$$

| 项 | 代码位置 |
|---|---|
| 第一阶段系数 $\pi_t\Delta t$ | `func_build_q2c.m` 第 71 行 `f(aux.iGP) = price_v(:)*dt` |
| 当日紧急系数 $5\pi_t\Delta t/K$ | 同文件第 73 行 |
| 未来日 $G^{plan,(ω)}$ 与 $H$ 系数 | 同文件第 75~76 行 |
| 实际费用记账（非目标值） | `func_exec_q2c.m` 第 70~72 行（`cost_plan`/`cost_em`/`cost`） |

## 五、约束（§10、§11）

每个 $(w,j)$ 共 5 组等式，行号由 `r0` 顺序分配（`func_build_q2c.m` 第 107~156 行）：

| 编号 | 约束 | 表达式 | 代码位置 |
|---|---|---|---|
| §11.1 | 负荷平衡 | $G^{L}+D+H=\bar L^{+}$ | 第 114~118 行 |
| §11.2 | 充电来源 | $PV^{ch}+G^{ch}-C=0$ | 第 120~123 行 |
| §11.3 | 光伏剩余 | $PV^{ch}+V=\overline{PV}^{+}$ | 第 125~129 行 |
| §11.4 | SOC 递推 | $E_t-E_{t-1}-\eta_c\Delta t\,C_t+\frac{\Delta t}{\eta_d}D_t=0$ | 第 131~143 行 |
| §10 | 计划连接 | $G^{L}+G^{ch}+W-G^{plan}=0$ | 第 145~154 行 |
| §11.6 | 充放电互斥 | $C_t\le P_{\max}u_t,\; D_t\le P_{\max}(1-u_t)$ | 第 160~189 行（`use_bin=true` 时） |

**滚动起点与跨日传递**：$E^{(\omega)}_{d,0}=E^{act}_{d,0}$（第 139~143 行，$j=1$ 取 `E_start`，
$j\ge2$ 取同情景前一日末槽）；实际层跨日 `E_now = o.E(end)`（`func_roll_q2c.m` 第 139 行）。

## 六、执行层（§15 + 建模手 C3）

| 编号 | 规则 | 代码位置 |
|---|---|---|
| E2 | 逐槽优先级：光伏→负荷、计划购电→负荷、缺口先放电再紧急 | `func_exec_q2c.m` 第 24~64 行 |
| E3 | 负荷满足后：光伏余电优先充电 → 剩余计划购电充电 → 余量记 $V$、$W$（分开） | 同上 |
| E3 | 充电不挤占负荷；紧急购电不给储能充电 | 同上 |
| E4 | $E^{act}_{d,t}=E^{act}_{d,t-1}+0.9C^{act}\Delta t-D^{act}\Delta t/0.9$ | 同上，输出 `out.E` |

## 七、预测与情景（§8 + C1/C2/C8）

| 编号 | 规则 | 代码位置 |
|---|---|---|
| D1 | 点预测（同星期回溯 K=4 周，仅用 $\tau<d$ 的真实数据） | `func_forecast_q2.m` |
| C4/D2 | B3 联合偏差校正（开关 γ） | `func_bias_q2.m`；`func_roll_q2c.m` 第 92~95 行 |
| C8=A | 校正量作用于视野内**全部 R 天** | `func_roll_q2c.m` 第 92~94 行（$R\times T$ 隐式扩展） |
| C8=A | 情景误差库 = 原始残差 − 当日校正量（与点预测同源） | `func_roll_q2c.m` 第 61~66 行 |
| C1 | 最近 28 个有效残差日中随机无放回抽 K 天（种子 2026，**逐日独立子流 `seed+d`**，见 G4 修正） | `func_scen_q2c.m` 第 23~41 行 |
| C2 | 有效残差 < max(K,5) 时退化为 K=1 并逐日留标记 | `func_scen_q2c.m` 第 26 行前后；`out.degraded` |
| D4 | 同一情景内 R 天共用同一历史误差模板 | `func_scen_q2c.m` 第 38~44 行 |

## 八、结果文件口径（§19 + F1/F2/F3）

| 项 | 填什么 | 代码变量 |
|---|---|---|
| 计划购电量 | $G^{plan}_{d,t}\Delta t$ | `out.buy_kw × Δt` |
| 充放电量 | 实际执行的 $C^{act}\Delta t$、$D^{act}\Delta t$ | `out.chg_m`、`out.dis_m`（**已是 kWh**） |
| 紧急购电量 | 实际执行的 $H^{act}\Delta t$ | `out.em_m`（**已是 kWh**） |

> **单位约定**：`func_exec_q2c.m` 返回的 `out.C/D/H/V/W` 已乘 $\Delta t$，是电量；
> `out.buy_kw` 是功率。混用会造成 6 倍量级错误。

## 九、代码位置回填（/report 阶段复核）

| 裁决 | 落地文件 | 行号 |
|---|---|---|
| C6 第一阶段非预见性 | `src/func_build_q2c.m` | 第 44 行（`aux.iGP`）、第 152 行（当天块引用同一列） |
| C7 第二阶段含 W | `src/func_build_q2c.m` | 第 33~35、147 行 |
| C8 未来日临时计划 | `src/func_build_q2c.m` | 第 149~153 行 |
| C9 连接约束 | `src/func_build_q2c.m` | 第 145~154 行 |
| C11 目标权重 | `src/func_build_q2c.m` | 第 70~78 行 |
| C12 只执行当天 | `src/func_roll_q2c.m` | 第 142~144 行 |
| E1 计划不可改 | `src/func_exec_q2c.m` | 第 70 行（按完整计划量计费） |
| 断点续跑 | `src/func_roll_q2c.m` | 第 40~67、157~160 行（行号已于 /report 阶段按当前源码复核） |
