# 2025C 运行说明（NIPT 的时点选择与胎儿异常判定）

## 环境要求

- MATLAB R2026a（本队运行环境；代码未使用任何商业求解器/附加工具箱，Statistics Toolbox 为标准配置）
- Linux；3GB 内存即可（数据 < 1MB，峰值内存 < 1GB）
- 单 MATLAB 会话运行（本队规范）

## 目录结构

```
deliver/
├── code/        全部源代码（main_2025C.m + 10 个子函数）
├── 结果表/       21 张结果表（CSV，UTF-8）
├── figures/     16 张图（PNG，300dpi）
└── README_运行说明.md
```

## 复现步骤

1. 将 `code/` 中全部 .m 文件放入同一目录 `src/`；
2. 将 `附件.xlsx` 放入同级的 `data/` 目录；
3. 在题目根目录（src/ 的上一级）执行：

```bash
matlab -batch "run('src/main_2025C.m')"
```

全流程约 5 分钟（含 MATLAB 启动）。产物：`outputs/final_results.mat`、`outputs/tables/*.csv`、`figures/*.png|eps`。

> 路径说明：主程序用 `PROJ_ROOT = fullfile(fileparts(mfilename('fullpath')), '..')`
> 定位题目根目录，从任意目录启动均可正确读取 `data/附件.xlsx`。

## 结果对照

- 男胎 1082 条/267 人、女胎 605 条/147 人；Y 浓度阈值 0.04。
- 问题二：BMI 分组 [20.70,28.89) / [28.89,29.52) / [29.52,30.05) / [30.05,46.88)，
  最佳时点 10 / 10 / 10 / 12.29 周。
- 问题三：推荐时点 12.86 / 12.86 / 12.86 / 25 周（η=0.85）。
- 问题四：Youden 主阈值 θ=0.2111（召回 0.358）；偏召回阈值 θ=0.1293（召回 0.910）。
