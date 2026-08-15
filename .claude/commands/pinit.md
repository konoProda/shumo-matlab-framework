---
description: 初始化论文 LaTeX 骨架：目录结构、main.tex、章节文件、图表复制、编译说明
---
# /pinit - 论文工作流初始化

## 触发条件
用户输入 `/pinit` 或提出"开始写论文/搭论文框架"等请求时触发。

## 执行流程
1. **确定题目**：支持显式指定 `/pinit <题目名>`；未指定时读取 `shumo/.active_problem.txt` 中的当前题目。
2. **自动加载三个写作规范**（防遗漏，强制先读取再动笔）：
   - `shumo/.claude/skills/paper-spec/SKILL.md`（项目级写作规范：LaTeX/篇幅/确认/反抄袭/代码节选/留空）
   - `shumo/.claude/skills/paper-writer/SKILL.md`（结构与表达规范）
   - `~/.claude/skills/humanizer/SKILL.md`（去 AI 腔清单）
3. **创建骨架**：在 `<题目名>/paper/` 下生成：
   ```
   paper/
   ├── main.tex            # ctexart + amsmath + graphicx + booktabs; \input 各章节
   ├── sections/
   │   ├── abstract.tex    restatement.tex  assumption.tex  symbol.tex
   │   ├── q1.tex  q2.tex  q3.tex  q4.tex  verification.tex  evaluation.tex
   │   └── appendix.tex
   ├── figures/            # 从 <题目名>/figures/ 复制论文所需图(PNG+EPS)
   ├── tables/             # 论文表格 .tex 片段
   └── README.md           # 编译命令(xelatex 两遍)与打包说明
   ```
4. **核对素材**：确认 `<题目名>/PAPER_HANDOFF.md`、`outputs/`、`figures/` 存在；缺失则提示编程手。
5. **初始化进度文件**：写入 `shumo/.paper_progress.txt`（格式：`<题目名>|<已完成章节(逗号分隔)>|<下一章节>`）。
6. **停止并确认**：展示目录树 + main.tex 导言区与章节顺序，请编程手确认后进入 `/pwrite`。

## 硬性要求
- 个人信息（作者/学校/队号）一律占位符【待填】；
- 本机无 LaTeX 环境，不执行编译，只保证语法与路径正确并在 README 给出编译命令；
- 不得在骨架中预填任何正文内容（防止未经确认的内容混入）。
