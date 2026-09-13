# 2026C_formal 项目导航

2026 年全国大学生数学建模竞赛 C 题「微网与外部电网电力调控策略」的工程目录。

> **只想看结果** → [`PAPER_HANDOFF.md`](PAPER_HANDOFF.md)（每个数字标出处）
> **要写论文** → [`FIGURES_GUIDE.md`](FIGURES_GUIDE.md)（图 ↔ 建模 ↔ 代码 ↔ 论文位置）
> **要交付** → `deliver/`（唯一对外目录）
> **要复现** → 见下方「一键复现」

---

## 目录总览

```
2026C_formal/
├── deliver/            交付面（唯一对外）——四问「代码与说明」+ 顶层关键结果图
├── src/                求解代码，按问分目录（问题一/二/三/四/共用 + _旧版_勿引用）
├── scripts/            后处理与打包脚本（_旧版_勿引用 存历次一次性脚本）
├── figures/            图件，一图一自包含文件夹（脚本 + data.csv + PNG + PDF）
├── outputs/            结果、日志、过程文档、备份（组内）
├── data/               原始附件与预处理数据
├── tests/              测试脚本（组内）
├── dev_tools/          Python 辅助脚本（组内）
├── 建模手交接/          与建模组的往来文件（发出 / 接收）
├── paper/              论文写作资源
│
├── PAPER_HANDOFF.md        论文交接文档：建模 → 编程 → 论文，数字标出处
├── IMPLEMENTATION_REPORT.md 实现验证报告：映射表、运行记录、测试结论、风险
├── FIGURES_GUIDE.md        图件使用指南：取图与引用规范
├── RETROSPECTIVE.md        复盘总结：**下次工作流优化的唯一依据**
└── run_tail.sh             收尾调度（正在运行；结束后移入 scripts/sched/）
```

## 各目录要点

| 目录 | 要点 | 交付？ |
|---|---|---|
| `deliver/` | ① 每问一个「问题X对应的代码与说明」文件夹（入口 `.m` + 子函数副本 + `问题X_代码说明.docx` + 题目要求的结果表 `result*.xlsx`）；② `图件/` **完整图件附件**（14 张全在，每张带 绘图脚本 + `data.csv` + PNG + PDF）；③ 顶层每问一张**提要图** `.jpg` | ✅ 唯一对外 |
| `src/` | **有子目录，须用 `addpath(genpath('src'))`**；详见 [`src/README.md`](src/README.md) | ✅ 复制入 deliver |
| `figures/` | 一图一文件夹；**plot 脚本只读 `data.csv`，不做计算**；`_勿引用` 子目录为历史版本 | ✅ 经筛选 |
| `outputs/` | 顶层为**运行直接读写**的结果/断点/日志，其余按类分目录（`决策与映射/`、`测试记录/`、`分析记录/`、`统计中间件/`、`历史日志/`、`_旧版_勿引用/`、`_备份/`）；详见 [`outputs/README.md`](outputs/README.md) | ❌ |
| `scripts/` | 后处理流水线与打包；详见 [`scripts/README.md`](scripts/README.md) | ❌ |
| `建模手交接/` | `交付建模手/`（确认单、回执）、`接收自建模手/`（来文，一律 `问题X_` 前缀） | ❌ |

**不看的东西**：任何路径中含 `_勿引用`、`_已删除`、`_旧版`、`_旧口径`、`_备份` 的目录或文件，
都是历史留档，保留仅为可回溯，**论文与交付一律不引用**。

## 现行口径速查

| 问题 | 现行口径 | 入口 | 结果文件 |
|---|---|---|---|
| 一 | 确定性 MILP（单日，显式分流） | `src/问题一/main_q1.m` | `outputs/final_results_q1.mat` |
| 二 | **Q2c**：7 日滚动 SAA 两阶段 MILP | `src/问题二/main_q2c.m` | `outputs/final_results_q2c_L2.mat` |
| 三 | **Q3b**：日内多时点预报更新 + 多阶段滚动 | `src/问题三/main_q3b.m` | `outputs/final_results_q3b_S{0,1,2,3}.mat` |
| 四 | **Q4-2 / Q4-3**：实时波动电价下重算 | `src/问题四/main_q4.m` | `outputs/final_results_q4_Q4-{2,3}.mat` |

**关键数字**：问题三 S3 = 14 485 230.30 元（四时点全用）；
问题四 Q4-3 = 15 225 713.07 元（比 Q4-2 省 1 094 801.76 元）。
全部数字与出处的完整清单见 `PAPER_HANDOFF.md`。

## 一键复现

```bash
# ① 求解（跳过已完成分组，自动断点续跑）
bash scripts/sched/run_all.sh

# ② 后处理：图件数据 → 说明文本 → 结果表 → 报告章节 → 批量出图
matlab -batch "run('scripts/run_postprocess.m')"

# ③ 打包交付：代码 + docx + 结果表 + 顶层 jpg
bash scripts/pack_deliver.sh

# ④ 交付前自检：图件 14 张 / 交付目录 / 结果文件 / 文档 / 数字一致性 / 路径引用
python3 scripts/final_audit.py
```

**尚缺（编程手不生成，收尾时请全队补入 `deliver/`）**：
`论文源程序/`、`论文.pdf`、`AI工具使用说明.pdf`。
