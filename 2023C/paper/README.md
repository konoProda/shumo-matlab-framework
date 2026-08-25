# 2023c 论文包使用说明

## 目录结构
```
paper/
├── main.tex            # 主文件（入口）
├── sections/           # 章节文件（main.tex 自动 \input）
├── figures/            # 全部论文图（PNG 300dpi + EPS 双格式，自包含）
├── tables/             # 论文表格 .tex 片段
└── README.md           # 本说明
```

## 编译方法（在装有 TeX Live 的机器上执行）
```bash
cd paper
xelatex main.tex        # 第一遍
xelatex main.tex        # 第二遍（刷新交叉引用）
# 或使用 latexmk 自动化：
latexmk -xelatex main.tex
```

## 打包提交前检查清单
- [ ] main.tex 中个人信息占位符已替换（【学校名称】【队员姓名】【提交日期】）
- [ ] abstract.tex 关键词已填写
- [ ] 编译无报错（Warning 可忽略，Error 必须处理）
- [ ] 页数在 25~30 页（附录另计）

## 常见编译问题
1. `! LaTeX Error: File 'xxx.sty' not found` → 缺少宏包，执行
   `sudo apt install texlive-full`（或 texlive-xetex texlive-lang-chinese）
2. 中文乱码 → 确认用 xelatex 编译（勿用 pdflatex）
3. 图片找不到 → 检查 figures/ 目录是否随包提交

## 在线编辑器（Overleaf / TeXPage 等）协作说明
1. **上传方式**：新建项目后，把本目录（含 main.tex、sections/、figures/、
   tables/、latexmkrc）**整体上传**，保持目录结构不变；只传 main.tex 会报
   "找不到 sections/abstract.tex"。
2. **主文件**：项目设置中将 Main document 设为 `main.tex`。
3. **编译器**：设为 **XeLaTeX**（本目录含 latexmkrc，支持自动检测的平台无需
   手动设置）。误用 pdfLaTeX 会直接报"本论文必须使用 XeLaTeX 编译"。
4. **中文字体**：main.tex 已做字体自适应（Noto CJK → 思源 → Fandol），三种
   字体任一可用即可编译；若平台报"未找到可用中文字体"，请换用装有中文字体
   的平台或联系平台支持安装 fandol 字体包。
5. 多人协作时建议每位队员只编辑自己负责的 sections/*.tex 文件，避免同时
   修改 main.tex 产生合并冲突。
