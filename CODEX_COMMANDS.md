# Codex 命令映射

本文件把原 `.claude/commands/` 中的工作流转换为 Codex 使用时的自然语言触发方式。用户仍可输入类似 `/prep`、`/code`、`/test`、`/report`、`/pinit`、`/pwrite`、`/pcheck` 的命令，Codex 按下列含义执行。

## `/prep`

用途：初始化题目目录，解析数学模型，建立数学到代码的映射。

执行要点：

- 未指定题目时先询问题目名。
- 创建 `<题目名>/data`、`src`、`scripts`、`tests`、`outputs`、`figures`。
- 检查 `data/` 下是否有官方数据。
- 输出并保存 `outputs/math_to_code_mapping.md`。
- 如需要结构化版本，保存 `outputs/math_to_code_mapping.json`。
- 记录预处理日志到 `outputs/preprocess_log.txt`。
- 更新 `.active_problem.txt` 为 `<题目名>|Phase0`。
- 完成后停止，等待用户确认。

## `/code`

用途：根据已确认的数学映射生成 MATLAB 代码。

执行要点：

- 可显式指定题目；否则读取 `.active_problem.txt`。
- 写入前先列出目标文件。
- 如果同名 `.m` 文件已存在，先备份为 `*.m.bak_<时间戳>`。
- 主程序放在 `src/main_*.m`，子函数放在 `src/func_*.m`。
- 数据路径统一用 `PROJ_ROOT` 和 `fullfile(PROJ_ROOT, 'data', ...)`。
- 注释标注公式编号或数学符号，不写冗余实现细节。
- 生成主程序后等待用户确认接口，再继续子函数。

## `/test`

用途：验证代码实现与数学模型一致。

执行要点：

- 测试脚本放在 `tests/test_*.m`。
- 测试原始数据；数据过大时用前 200 行或 10% 快速测试集。
- 覆盖维度检查、特殊值、稳定性、收敛性、参考解或交叉验证。
- 保存 `outputs/test_results.mat` 和 `outputs/test_log.txt`。
- 可尝试 `matlab -batch "run('<题目名>/tests/test_*.m')"`。
- 如果 MATLAB 不可用，生成可由用户执行的脚本并说明命令。
- 失败时写入 `outputs/failure_notes.md`，并给出失败项、预期值、实际值、复现命令和排查建议。

## `/report`

用途：正式运行并生成实现验证报告。

执行要点：

- 用完整数据运行 `src/main_*.m`。
- 保存 `outputs/final_results.mat` 和图表到 `figures/`。
- 生成 `IMPLEMENTATION_REPORT.md`。
- 报告包含执行摘要、数学到代码映射、运行记录、测试验证、代码质量与风险。
- 同步生成 `PAPER_HANDOFF.md`，为论文写作提供 AI-ready 材料。

## `/pinit`

用途：初始化论文 LaTeX 工程。

执行要点：

- 目标目录为 `<题目名>/paper/`。
- 创建 `main.tex`、`sections/`、`figures/`、`tables/`、`README.md`。
- 检查 `PAPER_HANDOFF.md`、`outputs/`、`figures/` 是否存在。
- 个人信息使用占位符。
- 不预填未经确认的正文内容。
- 更新 `.paper_progress.txt`。
- 展示目录树和章节顺序后停止，等待用户确认。

## `/pwrite`

用途：逐章撰写论文。

执行要点：

- 未指定章节时读取 `.paper_progress.txt` 的下一章节。
- 只使用 `PAPER_HANDOFF.md`、`outputs/`、`figures/`。
- 生成对应 `paper/sections/*.tex`。
- 写完每章后做去 AI 腔、反抄袭和数字一致性检查。
- 更新 `.paper_progress.txt`。
- 每章完成后停止，等待用户确认。

## `/pcheck`

用途：论文交付前静态检查。

执行要点：

- 检查篇幅、图表引用、数字一致性、AI 腔、反抄袭、占位符、LaTeX 语法、标题编号、摘要页和打包性。
- 输出 PASS/FAIL 清单。
- 失败项给出具体位置与修复建议。
- 未经用户同意不自动修复大范围内容。
