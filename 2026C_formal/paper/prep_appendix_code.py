#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prep_appendix_code.py —— 为附录 B 准备代码副本

规范（paper-spec §七）要求附录 B ≤6 页，且"代码逻辑必须与支撑材料中的实际代码
一致（仅删注释，不改逻辑）"。据此本脚本：

  · **只做两件事**：整段搬运 + 删掉末尾纯打印段（删时留一行标注）；
  · **不改任何代码逻辑**，不改行宽、不重排、不删注释——
    超宽行交给排版侧用 fvextra 的 breaklines 软折行（源码保持字字一致，
    便于评审核对附录与支撑材料是否同一份）；
  · 每个函数留一个 \subsection 小标题。

页数预算：正文 6 页 × 约 71 行（\\scriptsize）= 426 行。
四个主程序合计 437 行，故将 main_q1.m 末尾的"论文表 1/表 2 数值打印"与
"能源流向汇总打印"两段（共 30 行）整段略去并标注——这两段只向控制台输出，
不含求解逻辑。

用法：python3 prep_appendix_code.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'src')
DST = os.path.join(HERE, 'code')

# (源文件, 输出名, 小节标题, 截断（保留到第几行；None = 全文）)
FILES = [
    # keep=None = 全文收录。附录代码必须**完整**（编程手 2026-09-13 要求），
    # 不再对末尾的打印段做截断。
    ('问题一/main_q1.m',  'main_q1.m',  r'问题一：典型日计划购电（\texttt{main\_q1.m}）', None),
    ('问题二/main_q2c.m', 'main_q2c.m', r'问题二：7 日滚动两阶段随机规划（\texttt{main\_q2c.m}）', None),
    ('问题三/main_q3b.m', 'main_q3b.m', r'问题三：日内多阶段预报更新与再调整（\texttt{main\_q3b.m}）', None),
    ('问题四/main_q4.m',  'main_q4.m',  r'问题四：电价不确定性与日内价格更新（\texttt{main\_q4.m}）', None),
]

# 清单写法（供 appendix.tex 与 README 共用）
MANIFEST = os.path.join(HERE, 'code_manifest.tex')


def main():
    os.makedirs(DST, exist_ok=True)
    tex = [r'% 本文件由 paper/prep_appendix_code.py 生成，勿手改',
           r'% 附录 B 的清单：小节标题 + 对应代码文件（供 main 与 README 共用）', '']
    total = 0
    for src_rel, out_name, title, keep in FILES:
        src = os.path.join(SRC, src_rel)
        lines = open(src, encoding='utf-8').read().split('\n')
        while lines and lines[-1] == '':
            lines.pop()
        if keep is not None and keep < len(lines):
            lines = lines[:keep] + [
                '',
                '% ……（本段为控制台结果打印，不含求解逻辑，附录从略；'
                '完整代码见支撑材料）',
            ]
        open(os.path.join(DST, out_name), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
        total += len(lines)
        tex += [r'\subsection{%s}' % title,
                r'\VerbatimInput{code/%s}' % out_name, '']
        print('  %-22s ← src/%-20s %3d 行' % (out_name, src_rel, len(lines)))
    open(MANIFEST, 'w', encoding='utf-8').write('\n'.join(tex))
    print('\n附录 B 代码合计 %d 行（约 %.1f 页，\\scriptsize 按 71 行/页估）'
          % (total, total / 71.0))
    print('  注：附录代码要求完整，故不再截断；正文页数另受 30 页约束（附录可另计）。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
