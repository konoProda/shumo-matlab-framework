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
