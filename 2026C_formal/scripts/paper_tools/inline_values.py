#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""inline_values.py —— 把「单个数值/少量数据」的行间公式改回行内

编程手要求（2026-09-13）：**仅计算公式作换行居中处理**，简单或少量的数据
不必单独占一行居中。

初稿里大量出现这种写法：

    全天最大光伏预测功率为

    \\[
    7612.32\\ {\\rm kW},
    \\]

    出现在 12:00—12:10 时段。

数值本该就在句子中间。本脚本把这类"被公式环境切断的句子"接回一行，
数值改为行内数学 \\(…\\)。

判定为"数据"的条件（保守，宁少勿多）：
  · 公式体不含任何关系/运算符号（ = < > \\leq \\geq \\in \\sum \\frac \\min \\max …）
    —— 含这些的是公式，按"计算公式"保留居中；
  · 公式体长度 < 90 字符；
  · 前一行不以句末标点（。！？）结尾，后一行不是标题/环境/空行
    —— 否则接回去会串句。

用法：
    python3 inline_values.py --dry     # 只报告，不写盘
    python3 inline_values.py           # 实际改写
"""
import glob
import os
import re
import sys

# 本脚本在 scripts/paper_tools/ 下，产物一律写回 ../../paper/
HERE = os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), 'paper')
SECT = os.path.join(HERE, 'sections')

REL = re.compile(r'[=<>]|\\leq|\\geq|\\in\b|\\sum|\\frac|\\min|\\max|\\int|\\prod|\\cup|\\cap')
BLOCK = re.compile(r'(?<!\\)\\\[(.*?)(?<!\\)\\\]', re.S)


def is_data(body):
    """是不是"简单或少量的数据"。

    \\boxed{} 的**关键结果**不在此列——那是刻意强调，保留居中展示。
    """
    b = body.strip()
    if r'\boxed' in b:
        return False
    return len(b) < 90 and not REL.search(b)


def inline_math(b):
    """把公式体改成行内数学，并处理结尾标点与废弃的 \\rm。"""
    b = b.strip()
    punct = ''
    if b.endswith('.'):
        b, punct = b[:-1].rstrip(), '。'
    elif b.endswith(','):
        b, punct = b[:-1].rstrip(), '，'
    # {\rm kWh} → \mathrm{kWh}（\rm 已废弃，且行内需要成组）
    b = re.sub(r'\{\\rm\s+([^{}]*)\}', r'\\mathrm{\1}', b)
    b = re.sub(r'\\rm\s+([A-Za-z]+)', r'\\mathrm{\1}', b)
    return r'\(%s\)' % b + punct


def convert(text, dry=True):
    out, pos, hits = [], 0, []
    for m in BLOCK.finditer(text):
        body = m.group(1)
        if not is_data(body):
            continue
        pre_end = text.rfind('\n\n', 0, m.start())
        pre_start = text.rfind('\n\n', 0, pre_end - 1) + 2 if pre_end > 0 else 0
        pre = text[pre_start:pre_end] if pre_end > 0 else ''
        post_start = text.find('\n\n', m.end())
        if post_start == -1:
            continue
        post = text[post_start + 2:text.find('\n\n', post_start + 2)
                    if text.find('\n\n', post_start + 2) != -1 else len(text)]
        # 守卫
        if not pre.strip() or not post.strip():
            continue
        if re.search(r'[。！？：]$', pre.strip()):
            continue
        if re.match(r'^\\(sub)*section|^\\begin|^\\end|^\\input', post.strip()):
            continue
        if '\n' in pre.strip() or '\n' in post.strip():
            continue
        merged = '%s %s %s' % (pre.rstrip(), inline_math(body), post.strip())
        hits.append((pre.strip()[-24:], body.strip().replace('\n', ' '),
                     post.strip()[:24], merged))
    if dry or not hits:
        return text, hits
    # 实际替换：**每次只替换一处，然后重新扫描**。
    # 早先用 last 指针一趟重建，遇到"链式块"（前一块的后文恰是后一块的前文）时，
    # 指针已越过下一块的前文，于是把那句话又拼了一遍——q4 里真的出现了
    # "计划阶段中心预测为计划阶段中心预测为"。块数只有几十，逐次替换足够快。
    if not dry:
        while True:
            one, h = _replace_first(text)
            if not h:
                break
            text = one
            hits.append(h)
        return text, hits
    return text, hits


def _replace_first(text):
    """替换**第一处**可合并的块，返回 (新文本, 命中信息)；无则返回 (原文本, None)。"""
    for m in BLOCK.finditer(text):
        body = m.group(1)
        if not is_data(body):
            continue
        pre_end = text.rfind('\n\n', 0, m.start())
        if pre_end <= 0:
            continue
        pre_start = text.rfind('\n\n', 0, pre_end - 1) + 2
        post_start = text.find('\n\n', m.end())
        if post_start == -1:
            continue
        nxt = text.find('\n\n', post_start + 2)
        post_end = nxt if nxt != -1 else len(text)
        pre = text[pre_start:pre_end]
        post = text[post_start + 2:post_end]
        if not pre.strip() or not post.strip():
            continue
        if re.search(r'[。！？：]$', pre.strip()):
            continue
        if re.match(r'^\\(sub)*section|^\\begin|^\\end|^\\input', post.strip()):
            continue
        if '\n' in pre.strip() or '\n' in post.strip():
            continue
        merged = '%s %s %s' % (pre.rstrip(), inline_math(body), post.strip())
        info = (pre.strip()[-24:], body.strip().replace('\n', ' '), post.strip()[:24])
        return text[:pre_start] + merged + text[post_end:], info
    return text, None


def main():
    dry = '--dry' in sys.argv
    tot = 0
    for f in sorted(glob.glob(os.path.join(SECT, '*.tex'))):
        text = open(f, encoding='utf-8').read()
        new, hits = convert(text, dry=True)
        if not hits:
            continue
        print('%s  %d 处' % (os.path.basename(f), len(hits)))
        for a, b, c, m in hits:
            print('    …%s + [%s] + %s…' % (a, b, c))
        if not dry:
            open(f, 'w', encoding='utf-8').write(convert(text, dry=False)[0])
        tot += len(hits)
    print('\n合计 %d 处%s' % (tot, '（试跑，未写盘）' if dry else '（已写盘）'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
