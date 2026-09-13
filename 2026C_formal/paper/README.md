# 论文 LaTeX 源码

## 编译

```bash
latexmk -xelatex main.tex        # 或直接 latexmk main.tex
latexmk -C                       # 清理中间文件
```

必须用 **XeLaTeX**：`ctexart` 在 PDFLaTeX 下会在中文字体处直接报错。
若 `latexmk` 不可用，`xelatex main.tex` 连续跑两遍即可（第二遍解交叉引用）。

## 目录

```
main.tex       导言区 + \input 各章节
sections/      逐章正文
tables/        表格片段（由 \input 引入）
figures/       论文用图
code/          附录代码
```

## 修改时注意

- 公式编号为全文连续编号，未按节编号；章节号已在导言区显式重定义。
- 图件使用 ASCII 文件名，`\includegraphics` 才能在各版本 TeX Live 下正确找到文件。
