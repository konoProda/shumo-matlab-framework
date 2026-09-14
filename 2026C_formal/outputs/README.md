# outputs/ 目录说明

结果、日志、裁决文档（**组内产物，不交付**）。
2026-09-13 整理：按类别分目录，顶层只保留**正在运行的脚本按名字读写的文件**。

> ⚠️ **顶层文件不要移动**。`src/问题X/main_*.m` 与 `scripts/sched/run_*.sh` 用
> `fullfile(PROJ_ROOT,'outputs', <名字>)` 按名读写，移动会让它们重新在顶层生成一份，
> 造成"同一结果两处存在"。要调整位置，必须**先改编写脚本的路径再移动**。

## 顶层（现行运行直接读写）

| 文件 | 谁写 | 谁读 |
|---|---|---|
| `final_results_q1.mat` | `src/问题一/main_q1.m` | `scripts/make_deliver_text.m` |
| `final_results_q2c_L2.mat` | `src/问题二/main_q2c.m` | `scripts/prep_q2c_figdata.m`、`make_deliver_text.m` |
| `final_results_q2c_L2k8.mat` | 问题二 K=8 稳定性对照 | 文档引用 |
| `final_results_q3b_S0/S1/S2/S3.mat` | `src/问题三/main_q3b.m` | `prep_q3b_figdata.m`、`make_deliver_text.m`、`write_q3b_q4_deliver.m`、`write_q3b_q4_report.m` |
| `final_results_q4_Q4-2/Q4-3/Q4-2P0/Q4-3P0/Q4-2Ideal.mat` | `src/问题四/main_q4.m` | `prep_q4_figdata.m`、`make_deliver_text.m`、`write_q3b_q4_*.m` |
| `ckpt_q3b_*.mat`、`ckpt_q4_*.mat` | 两个 main 的断点续跑 | 同上（续跑时读） |
| `log_q3b_run.txt`、`log_q4_run.txt` | `scripts/sched/run_tail.sh` | — |
| `log_postprocess.txt` | `scripts/run_postprocess.m` | — |
| `result1.xlsx`、`result2_q2c.xlsx`、`result3.xlsx`、`result4-2.xlsx`、`result4-3.xlsx` | 各问写出模块 | `scripts/pack_deliver.sh` |
| `result2.xlsx`、`result2_ideal_daily.xlsx` | 问题二早期口径 | 文档引用（非现行） |
| `自动工作总览_第三四问.md` | 人工 + `write_q3b_q4_report.m`（幂等块替换） | 论文手 |

## 子目录

| 目录 | 内容 | 现行？ |
|---|---|---|
| `裁决与映射/` | `decisions_*`（建模裁决清单）、`solve_strategy_*`（求解策略）、`math_to_code_mapping_*`（符号↔代码映射）、`figure_list_*`（图件清单） | ✅ 现行 |
| `测试记录/` | `test_log_*`、`test_results_*`、`preprocess_log_*` | ✅ 现行 |
| `分析记录/` | `自动工作总览` 的配套件、`先行订对_第三四问.md`、`待确认问题清单.md`、`q2c_*.md`、`q2b_handback_tables.md` | ✅ 现行 |
| `统计中间件/` | 各轮的逐日统计 `q*.csv`、视野灵敏度 `q2_hz_*.mat`、`q1_solution.*` | 部分历史 |
| `历史日志/` | 问题二/三各轮的运行日志、`清理记录_20260914.txt`（收官清理清单） | ❌ 历史 |

被现行口径取代的 `final_results_*` 与过程备份已在 2026-09-14 收官清理中移除，
见 `历史日志/清理记录_20260914.txt`（`git show fbe8845:<路径>` 可取回）。

## 常见查阅路径

| 想查什么 | 去哪 |
|---|---|
| 某个数字的原始出处 | 顶层 `final_results_*.mat`（用 `h5py` 或 MATLAB 读 `s` 字段） |
| 为什么这么建模 / 有哪些裁决 | `裁决与映射/decisions_q4.md` 等 |
| 某问的测试过了没有 | `测试记录/test_log_q*.txt` |
| 整轮工作做了什么 | `自动工作总览_第三四问.md`（本目录顶层） |
| 上一轮是怎么错的 | 项目根目录 `RETROSPECTIVE.md` |
