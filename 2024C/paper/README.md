# 2024C 论文 LaTeX 使用说明

## 编译方式

推荐使用 XeLaTeX。进入 `paper/` 目录后执行：

```bash
latexmk -xelatex main.tex
```

如果没有 `latexmk`，可手动运行两遍：

```bash
xelatex main.tex
xelatex main.tex
```

## 目录说明

- `main.tex`：论文主文件。
- `sections/`：各章节 LaTeX 源码。
- `figures/`：论文所需图件，已从 `../figures/` 复制。
- `tables/`：预留表格片段目录。
- `latexmkrc`：指定 XeLaTeX 编译。

## 提交前检查

- 将标题下方的【学校名称】和队员姓名占位符替换为正式信息。
- 核对摘要是否压缩在一页内；如超页，优先压缩摘要最后一段。
- 所有结果数字来自 `../PAPER_HANDOFF.md`、`../outputs/compare_q.csv` 和 `../outputs/sensitivity.csv`。
- 若图片无法显示，确认 `paper/figures/` 中存在同名 `.png` 文件。
