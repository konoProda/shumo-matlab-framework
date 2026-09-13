# src/ 目录说明

2026C 四问的求解代码。**自 2026-09-13 起按问分目录**。

> ⚠️ 本目录有子目录，`addpath('src')` **不再够用**，必须用 `addpath(genpath('src'))`。
> 全仓的调用点已于 2026-09-13 一次性改写完毕（含 `figures/**/plot_*.m` 与 `scripts/**`）。

## 目录结构

```
src/
├── 问题一/    确定性 MILP（单日）
├── 问题二/    7 日滚动 SAA 两阶段随机 MILP（Q2c 现行口径）
├── 问题三/    日内多时点预报更新 + 多阶段滚动（Q3b 现行口径）
├── 问题四/    实时波动电价下的重算（Q4-2 / Q4-3）
├── 共用/      跨问复用的预测层、读取层、绘图工具
└── _旧版_勿引用/   被取代的历史实现，**不要引用、不要运行**
```

## 各问文件

| 目录 | 入口 | 子函数 |
|---|---|---|
| `问题一/` | `main_q1.m` | `func_build_q1`、`func_check_q1`、`func_read_q1`、`func_write_q1` |
| `问题二/` | `main_q2c.m` | `func_build_q2c`、`func_exec_q2c`、`func_roll_q2c`、`func_scen_q2c` |
| `问题三/` | `main_q3b.m` | `func_build_q3b`、`func_exec_q3b`、`func_interp_q3b`、`func_read_q3b`、`func_resid_q3b`、`func_roll_q3b`、`func_scen_q3b` |
| `问题四/` | `main_q4.m` | `func_forecast_q4`、`func_price_q4`、`func_roll_q4`、`func_scen_q4` |

## 共用文件（`共用/`）

| 文件 | 作用 | 使用者 |
|---|---|---|
| `func_read_q2.m` | 读取附件1/2，返回电价、负荷、光伏、日期 | 二/三/四 |
| `func_forecast_q2.m` | 同周期回溯基础预测 | 二/三/四 |
| `func_bias_q2.m` | B3 偏差校正器（负荷/光伏按小时加性校正） | 二/三/四 |
| `func_resid_q2.m` | 历史误差日残差池构造 | 二/三/四 |
| `func_write_q2.m` | 按附件5 模板写结果表 | 二/三/四 |
| `func_fig_pal.m` | 配色（同变量同色） | 全部绘图脚本 |
| `func_fig_style.m` | 图幅样式（字号、坐标轴、图名位置） | 全部绘图脚本 |

## 命名与跨目录依赖

- 入口一律 `main_qX.m`（X = 1 / 2c / 3b / 4），子函数一律 `func_<短词>_qX.m`。
- **`问题四/` 依赖 `问题三/`**：Q4 复用 `func_build_q3b`、`func_exec_q3b`、`func_interp_q3b`、`func_read_q3b`、`func_resid_q3b`（问题四 = 问题三 + 价格维度）。`genpath` 已覆盖，无需额外处理。
- **`问题三/`、`问题四/` 依赖 `共用/`**。

## `_旧版_勿引用/` 里有什么

| 文件 | 被谁取代 |
|---|---|
| `main_q2`、`main_q2b`、`main_q2_forecast`、`main_q2_roll_corr`、`main_q2_roll_plan`、`main_q2_year` | `main_q2c`（Q2c 现行口径） |
| `main_q3`、`main_q3_nocorr`、`main_q3_sens` | `main_q3b`（Q3b 现行口径） |
| `func_build_q2`、`func_check_q2`、`func_exec_q2`、`func_roll_q2` | 对应的 `*_q2c` 版本 |
| `func_read_q3`、`func_interp_q3`、`func_roll_q3`、`func_scen_q3`、`func_write_q3` | 对应的 `*_q3b` 版本 |
| `run_all_figures.m` | `scripts/` 下的批量出图流程 |

这些文件名与现行文件**不重叠**，因此 `genpath` 把它们一并挂上路径也不会冲突；但**任何时候都不要运行它们**。

## 交付关系

`deliver/问题X对应的代码与说明/` 中的 `.m` 由 `scripts/pack_deliver.sh` 从本目录**复制并平铺**而成；
交付副本会摘掉指向 `src/` 的路径行（平铺目录里兄弟函数自动可解析）。
