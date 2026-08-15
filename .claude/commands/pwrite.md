---
description: 按规范撰写论文章节（自动加载三个skill并执行去AI修订），逐章确认
---
# /pwrite - 论文章节撰写

## 触发条件
`/pinit` 骨架确认后逐章调用；或显式 `/pwrite <章节名>`（如 `/pwrite q2`）。

## 执行流程（每章固定）
1. **确定目标章节**：未指定时读取 `shumo/.paper_progress.txt` 的"下一章节"；显式指定则写指定章节。
2. **强制自动加载四个规范**（先 Read 再动笔，防止遗忘）：
   - `shumo/.claude/skills/paper-spec/SKILL.md`
   - `shumo/.claude/skills/paper-writer/SKILL.md`
   - `shumo/.claude/skills/paper-format/SKILL.md`
   - `~/.claude/skills/humanizer/SKILL.md`
3. **素材限定**：只使用 `<题目名>/PAPER_HANDOFF.md`、`outputs/` 结果表、`figures/` 图表；
   **禁止虚构数字/结论**；数字与 HANDOFF 不一致时以 outputs/ 为准并向我确认。
4. **撰写初稿**：按 paper-writer 规范生成 LaTeX 代码，写入对应 `sections/*.tex`。
5. **自动 humanizer 修订**：按 25 类清单做去 AI 腔修订（学术适配：保留加粗表头/编号列表/公式编号；
   不套用"幽默/第一人称"规则；重点清除 AI 高频词、破折号、三连排比、空洞升华句）。
6. **反抄袭自查**：参考同题论文的结构与图表类型可以借鉴，但标题句式/过渡语/解释措辞/叙述顺序
   必须独立；确保展现本队建模独特性；范文只允许出现在参考文献。
7. **更新进度文件**：写入 `shumo/.paper_progress.txt`。
8. **停止并确认**：展示本章预览（含行数/字数与页数预算对比），请编程手确认后才继续下一章；
   写作中出现疑问必须先提问并附建议，不得自行决定。

## 各章要点速查
- abstract：五问式（对象/问题/方法/结果/可信性），≤1 页，无背景铺垫；
- restatement：转化建模语言，不复述题面；
- q1~q4：建模闭环（目标界定→变量关系→假设→模型→约束→参数→求解→输出），公式后必解释；
- verification：检验对象/指标/结论明确，引用 26 项测试结论与敏感性表；
- evaluation：优点/缺点/推广，禁空话（"较为合理""有一定意义"必须给理由）；
- appendix：代码节选（每段 ≤15~20 行），完整代码清单指向 src/。

## 篇幅预算（总 25~30 页）
摘要 ≤1 页；重述+分析 ≤2 页；假设+符号 ≤2 页；每问 4~6 页；检验 ≤2 页；评价 ≤1 页；附录不计。
