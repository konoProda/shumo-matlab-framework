#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""insert_mandated_tables.py —— 把题目强制要求的表 1/表 2/表 3 接入各章

题目原文（data/C题.md）对论文有硬性表格要求：
  · 问题 1 第 17 行：以表 1 的格式给出指定时段购电量与全天购电量和购电费，
                     以表 2 的格式给出储能充放电量与 0:00 / 24:00 储电量；
  · 问题 2 第 40 行：按表 1 和表 2 的格式给出表 3 中指定日期的结果，
                     按表 3 的格式给出紧急购电的结果；
  · 问题 3 第 53 行：按表 1、表 2 和表 3 的格式给出表 3 中指定日期的结果。

表体由 gen_tables.py 生成在 tables/ 下，本脚本只负责把它们 \input 到正文合适
位置，并补一句引导语（表不在正文被引用属于格式硬伤）。

幂等：用 %MANDATED:BEGIN/END 注释包裹，重复运行只替换标记之间的内容。

用法：python3 insert_mandated_tables.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
B = '%MANDATED:BEGIN'        # 用 LaTeX 注释作标记：HTML 注释会被原样排版出来
E = '%MANDATED:END'

# (章节文件, 插入锚点行, 锚点之后插入?, 引导句, 表片段列表)
JOBS = [
    ('sections/q1.tex', r'\subsection{结论分析}', False,
     r'按题目表 1 与表 2 要求的格式，将上述结果整理如表~\ref{tab:m1-q1} 与表~\ref{tab:m2-q1}。',
     ['tab1_q1', 'tab2_q1']),
    ('sections/q2.tex', r'\label{tab:7}', True,
     r'按题目表 1、表 2 与表 3 要求的格式，上述四个指定日期的结果整理如表~\ref{tab:m1-q2} 至表~\ref{tab:m3-q2}。',
     ['tab1_q2', 'tab2_q2', 'tab3_q2']),
    ('sections/q3.tex', r'\label{tab:9}', True,
     r'按题目表 1、表 2 与表 3 要求的格式，上述四个指定日期的结果整理如表~\ref{tab:m1-q3} 至表~\ref{tab:m3-q3}。',
     ['tab1_q3', 'tab2_q3', 'tab3_q3']),
]


def block(lead, tabs):
    out = [B, lead, '']
    for t in tabs:
        out.append(r'\input{tables/%s}' % t)
        out.append('')
    out.append(E)
    return '\n'.join(out)


def main():
    for fn, anchor, after, lead, tabs in JOBS:
        path = os.path.join(HERE, fn)
        text = open(path, encoding='utf-8').read()
        new = block(lead, tabs)

        # 幂等：已有标记则整段替换
        if B in text and E in text:
            i, j = text.index(B), text.index(E) + len(E)
            text = text[:i] + new + text[j:]
            open(path, 'w', encoding='utf-8').write(text)
            print('  %-18s 已存在标记，整段替换' % fn)
            continue

        # 找锚点：锚点行的**下一行之后**插（after=True 时跳过该行所处的环境）
        lines = text.split('\n')
        pos = None
        for k, ln in enumerate(lines):
            if ln.strip() == anchor:
                pos = k
                break
        if pos is None:
            print('  !! 未找到锚点 %r in %s' % (anchor, fn))
            return 1

        if after:
            # 跳过分隔行与 \end{table}，插到浮动体之后
            j = pos + 1
            while j < len(lines) and not lines[j].startswith(r'\end{table}'):
                j += 1
            if j >= len(lines):
                print('  !! 未找到表结束 \end{table} in %s' % fn)
                return 1
            ins = j + 1
        else:
            ins = pos

        lines[ins:ins] = ['', new, '']
        open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        print('  %-18s 已插入 %d 张强制表（第 %d 行起）' % (fn, len(tabs), ins + 1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
