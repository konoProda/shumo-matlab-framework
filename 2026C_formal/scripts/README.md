# scripts/ 目录说明

后处理与交付面生成的脚本（**组内产物，不交付**）。
2026-09-13 整理：历次一次性分析脚本已归档至 `_旧版_勿引用/`，顶层只留**现行流水线**。

> ⚠️ 所有脚本都要读 `src/`，而 `src/` 已按问分目录 ⇒ 路径必须用 `addpath(genpath('src'))`。

## 顶层（现行流水线）

| 文件 | 作用 |
|---|---|
| **`run_postprocess.m`** | **后处理总调度**：图件数据 → 说明文本 → 结果表 → 报告章节 → 批量出图，一次 MATLAB 会话内顺序完成。**出图带过期判据**：只重出"data.csv 比 PNG 新"的图 |
| `run_finish.m` | **收尾轮精简后处理**：跳过图件数据落盘，只刷新①说明文本 ②结果表 ③报告章节，另补出过期图。用于"模型结果没变、只是补了评价性对照组"的场景 |
| `prep_q2c_figdata.m` | 问题二图件数据落盘（→ `figures/问题二/*/data.csv`） |
| `prep_q3b_figdata.m` | 问题三图件数据落盘 |
| `prep_q4_figdata.m` | 问题四图件数据落盘 |
| `make_deliver_text.m` | 生成四份交付说明正文（→ `scripts/deliver_text/qX.txt`） |
| `write_q3b_q4_deliver.m` | 写 `result3.xlsx` / `result4-2.xlsx` / `result4-3.xlsx` |
| `write_q3b_q4_report.m` | 写 `IMPLEMENTATION_REPORT.md` / `PAPER_HANDOFF.md` 的第三、四问章节（**幂等**，标记块替换） |
| `prep_check_q3b.m`、`prep_check_q4.m` | 数据校验器（读取层自检，正式运行前跑） |
| `probe_q3b_build.m`、`probe_q3b_smoke.m`、`probe_q3b_stage.m`、`probe_q4_smoke.m` | 本轮探针（小规模验证装配器/阶段/滚动引擎） |
| `pack_deliver.sh` | **交付打包**：`src/` → 各问文件夹 + docx + 结果表 + 顶层 jpg |
| **`pack_figures.py`** | 图件打包：**只带含 `改.png`（人工修证稿）的图件**进 `deliver/图件/`；只带 .m/.csv/.png，不出 pdf |
| `make_top_figs.py` | 顶层提要图：每问一张 jpg，**优先取人工修证稿** |
| `make_docx.py` | 纯文本说明 → `.docx`（自然段落，无命令与目录树） |
| `flatten_deliver_code.py` | 整理交付副本：摘除指向 `src/` 的路径行，补"同目录自动解析"提示 |
| **`final_audit.py`** | **交付前产物完整性自检**（Python，不占 MATLAB 会话）：图件入选口径完整性（10 张、须含人工修证稿 `改.png`） / 交付目录 / 结果 .mat / 文档 / **数字一致性逐项对账** / 路径引用。退出码 0 = 通过 |

## 子目录

| 目录 | 内容 |
|---|---|
| `sched/` | 调度脚本，见下 |
| `deliver_text/` | `q1.txt` ～ `q4.txt`，交付说明正文（由 `make_deliver_text.m` 生成，`pack_deliver.sh` 转 docx） |
| `_旧版_勿引用/` | 历次一次性脚本（数据统计、灵敏度、早期探针等）。**留档备查，不要运行** |

### `sched/` 下的调度脚本

| 脚本 | 顺序 | 何时用 |
|---|---|---|
| `run_all.sh` | Q3b S0/S3 → Q4 主口径 → Q3b S2/S1 → Q4 P0/Ideal → 稳定性 | 首轮全量 |
| `run_tail.sh` | Q4 P0/Ideal → Q4 K=8 → **Q3 S3k8 最后** | 收尾（已被 run_final 取代） |
| **`run_final.sh`** | **S1 重解 → Q4 P0/Ideal → Q3 S3k8 → Q4 K=8** | **本项目最终口径：两项稳定性均排最后** |
| `run_p0.sh` | 只跑 `main_q4`（P0/Ideal），跑完即止 | 想尽快拿到评价性对照、不让稳定性抢会话 |
| `stop_after_ideal.sh` | 看门：P0/Ideal 产物落地即停 MATLAB | 配合 `run_p0.sh`，把会话让给后处理 |

> ⚠️ **调度脚本里杀进程一律用 PID**（`pgrep -x MATLAB`），**不要用 `pkill -f <文本>`**——
> bash 会把 `-c` 的整段正文（含 heredoc）放进自己的 argv，模式串会自匹配、把 shell 自己杀掉。
> 本项目已因此误杀三次，详见 `RETROSPECTIVE.md` R22b。

## 一键流程

```bash
# ① 求解（断点续跑，跳过已完成项）
bash scripts/sched/run_all.sh

# ② 后处理：数据落盘 → 说明文本 → 结果表 → 报告 → 出图
matlab -batch "run('scripts/run_postprocess.m')"

# ③ 打包交付
bash scripts/pack_deliver.sh

# ④ 交付前自检（图件/交付/结果/文档/数字一致性/路径，纯 Python）
python3 scripts/final_audit.py
```
