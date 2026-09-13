#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""inline_short_formulas.py —— 把**短公式**的行间式改回行内

页面预算紧张（25 页目标）。规范原意是"仅公式换行"，但全文 142 个行间式中
有 80 个是单行内的短式（如 0≤C_t≤5000、u_t∈{0,1}），每个独占一行居中要吃掉
约 2 行版面；回填进句子后语义不变、版面省下一半。

判定为"短式"的条件：
  · 渲染宽度 ≤ 56 列（行内公式可在二元运算符处自动换行，稍宽也不会溢出）（\\left \\right 等不占宽）；
  · 公式体 ≤ 3 行；
  · 该 \\[…\\] 块前后各是一个完整段落（不为空、不以句末标点结尾、后段不是标题）。

涉及编号公式（equation 环境）的一律**不动**——它们有编号，回填会打乱编号体系。

用法：python3 inline_short_formulas.py --dry | (无参数即写盘)
"""
import glob
import os
import re
import sys

PAPER = os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), 'paper')
SECT = os.path.join(PAPER, 'sections')

BLOCK = re.compile(r'(?<!\\)\\\[(.*?)(?<!\\)\\\]', re.S)
EQ = re.compile(r'\\begin\{equation\}(.*?)\\end\{equation\}', re.S)
STRIP = re.compile(r'\\(left|right|,|;|!|quad|qquad|displaystyle|mathrm|textbf|text|begin|end)\b')


def cols(b):
    b = STRIP.sub('', b)
    b = re.sub(r'\\[a-zA-Z]+', 'x', b)
    return len(b.replace(' ', '').replace('\n', ''))


def is_short(b):
    return r'\boxed' not in b and cols(b) <= 56 and len(b.strip().split('\n')) <= 3


def inline_math(b):
    b = b.strip()
    punct = ''
    if b.endswith('.'):
        b, punct = b[:-1].rstrip(), '。'
    elif b.endswith(','):
        b, punct = b[:-1].rstrip(), '，'
    b = re.sub(r'\{\\rm\s+([^{}]*)\}', r'\\mathrm{\1}', b)
    return r'\(%s\)' % b + punct


def one(text):
    """替换第一处符合条件的短式；返回 (新文本, 命中信息) 或 (原文本, None)。"""
    for m in BLOCK.finditer(text):
        b = m.group(1)
        if not is_short(b):
            continue
        pe = text.rfind('\n\n', 0, m.start())
        if pe <= 0:
            continue
        ps = text.rfind('\n\n', 0, pe - 1) + 2
        qs = text.find('\n\n', m.end())
        if qs == -1:
            continue
        nx = text.find('\n\n', qs + 2)
        qe = nx if nx != -1 else len(text)
        pre, post = text[ps:pe], text[qs + 2:qe]
        if not pre.strip() or not post.strip():
            continue
        if re.search(r'[。！？：]$', pre.strip()):
            continue
        if re.match(r'^\\(sub)*section|^\\begin|^\\end|^\\input', post.strip()):
            continue
        if '\n' in pre.strip() or '\n' in post.strip():
            continue
        merged = '%s %s %s' % (pre.rstrip(), inline_math(b), post.strip())
        return text[:ps] + merged + text[qe:], (pre.strip()[-20:], b.strip()[:40])
    # 再试编号公式（equation 环境）里的短式：正文没有任何 \ref{eq:…}，去掉编号不影响引用
    for m in EQ.finditer(text):
        b = m.group(1)
        if not is_short(b) or r'\begin{' in b:
            continue
        pe = text.rfind('\n\n', 0, m.start())
        if pe <= 0:
            continue
        ps = text.rfind('\n\n', 0, pe - 1) + 2
        qs = text.find('\n\n', m.end())
        if qs == -1:
            continue
        nx = text.find('\n\n', qs + 2)
        qe = nx if nx != -1 else len(text)
        pre, post = text[ps:pe], text[qs + 2:qe]
        if not pre.strip() or not post.strip():
            continue
        if re.search(r'[。！？：]$', pre.strip()):
            continue
        if re.match(r'^\\(sub)*section|^\\begin|^\\end|^\\input', post.strip()):
            continue
        if '\n' in pre.strip() or '\n' in post.strip():
            continue
        merged = '%s %s %s' % (pre.rstrip(), inline_math(b), post.strip())
        return text[:ps] + merged + text[qe:], ('[编号式] ' + pre.strip()[-16:], b.strip()[:36])
    return text, None


def main():
    dry = '--dry' in sys.argv
    grand = 0
    for f in sorted(glob.glob(os.path.join(SECT, '*.tex'))):
        text = open(f, encoding='utf-8').read()
        hits = []
        while True:
            new, h = one(text)
            if not h:
                break
            hits.append(h)
            if not dry:
                text = new
            else:
                break
        if not hits:
            continue
        if not dry:
            open(f, 'w', encoding='utf-8').write(text)
        print('  %-16s %2d 处' % (os.path.basename(f), len(hits)))
        for a, b in hits[:4]:
            print('       …%s + [%s]' % (a, b))
        grand += len(hits)
    print('\n合计 %d 处%s' % (grand, '（试跑）' if dry else '（已写盘）'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
