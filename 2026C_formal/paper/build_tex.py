#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_tex.py —— 把论文初稿（LaTeX 风格 Markdown）切分并转换为 sections/*.tex

输入：../data/论文正文融合初稿.md
输出：sections/*.tex + tables/*.tex

转换规则见同目录 README.md。核心约定：
  · 标题去掉手写序号，编号交给 LaTeX 自动生成
  · 带 \\tag{n} 的公式块 → equation（全文唯一的编号环境，按序自动得 1..n）
  · 不带 tag 的公式块 → \\[ … \\]（不编号）
  · Markdown 管道表 → booktabs 三线表
  · 正文文本区的裸 % 转义（否则 LaTeX 静默吞掉整行）

用法：python3 build_tex.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'data', '论文正文融合初稿.md')
SEC = os.path.join(HERE, 'sections')
TAB = os.path.join(HERE, 'tables')

# ---- 章节切分点（顶层标题；三处缺失的标题由本脚本补上）----
SECTIONS = [
    ('abstract',     '摘要与关键词',             1,    9,   None),
    ('restatement',  '问题背景与问题重述',        10,   46,  None),
    ('analysis',     '问题分析',                 47,   145, None),
    ('assumption',   '模型假设',                 146,  206, None),
    ('symbol',       '符号说明',                 207,  377, None),
    ('q1',           '问题一模型的建立与求解',     378,  997, None),
    ('q2',           '问题二模型的建立与求解',     998,  1740, 998),
    ('q3',           '问题三模型的建立与求解',     1741, 2333, 1741),
    ('q4',           '问题四模型的建立与求解',     2334, 3132, 2334),
    ('evaluation',   '模型评价与推广',            3133, None, None),
]


def clean(text):
    """去 BOM、统一换行。"""
    return text.lstrip('\ufeff').replace('\r\n', '\n').replace('\r', '\n')


def strip_num(title):
    """剥掉标题里的手写序号：'一、xxx' / '1.1 xxx' / '（3）xxx'。"""
    t = re.sub(r'^[一二三四五六七八九十]+、\s*', '', title)
    t = re.sub(r'^\d+(?:\.\d+)*\s+', '', t)
    t = re.sub(r'^（\d+）\s*', '', t)
    return t.strip()


def esc_text(s):
    """文本区的转义。数学区不调用本函数。"""
    s = s.replace('%', r'\%')          # 唯一的真雷：% 会吞掉整行
    return s


def inline(s):
    """行内转换：加粗、行内代码。"""
    s = re.sub(r'\*\*(.+?)\*\*', r'\\textbf{\1}', s)
    s = re.sub(r'`([^`]+)`', r'\\texttt{\1}', s)
    return s


# ---------------------------------------------------------------- 公式块
MATH_OPEN = (r'\[', '$$')
MATH_CLOSE = (r'\]', '$$')


def read_math_block(lines, i):
    """从第 i 行起读一个行间公式块，返回 (tex 行列表, 下一个索引)。

    支持 \\[ … \\] 与 $$ … $$ 两种定界符（初稿两种混用）。
    """
    opener = lines[i].strip()
    body = []
    i += 1
    tagged = False
    while i < len(lines):
        s = lines[i].strip()
        if s in MATH_CLOSE:
            i += 1
            break
        if s.startswith(r'\tag{'):
            tagged = True                      # 编号交给 equation 环境，删掉 \tag
            i += 1
            continue
        body.append(lines[i])
        i += 1
    body = [ln for ln in body if ln.strip() != ''] or ['']
    if tagged:
        out = [r'\begin{equation}'] + body + [r'\end{equation}']
    else:
        out = [r'\['] + body + [r'\]']
    return out, i


# ---------------------------------------------------------------- 表格
def is_table_start(lines, i):
    """判定表格起始。

    标准 Markdown 表 = 表头行 + `|---|` 分隔行；初稿里另有一处**缺分隔行**的畸形表，
    也要认（否则会当成正文漏排）。两列以上才算表，避免把 `|a-b|` 这类公式误判成表。
    """
    if i + 1 >= len(lines) or not lines[i].lstrip().startswith('|'):
        return False
    if len(split_row(lines[i])) < 2:
        return False
    return lines[i + 1].lstrip().startswith('|')


def read_table(lines, i):
    rows = []
    while i < len(lines) and lines[i].lstrip().startswith('|'):
        rows.append(lines[i].strip())
        i += 1
    head = split_row(rows[0])
    if re.match(r'^\s*\|[-: |]+\|\s*$', rows[1]):
        seps = split_row(rows[1])
        body = [split_row(r) for r in rows[2:]]
        cols = ''.join('r' if s.endswith(':') else ('c' if s.startswith(':') else 'l')
                       for s in seps)
    else:
        # 畸形表：没有分隔行，**每一行都是数据**（首行也是），表头由本脚本按语义补写。
        # 不能把首行当表头——那会吃掉一条真实数据。
        body = [split_row(r) for r in rows]
        cols = 'l' + 'r' * (len(head) - 1)
        head = HEADER_FIX.get(convert.ntab + 1, head)
    out = [r'\begin{tabular}{%s}' % cols, r'\toprule',
           ' & '.join(inline(esc_text(c)) for c in head) + r' \\', r'\midrule']
    for r in body:
        r = (r + [''] * len(head))[:len(head)]
        out.append(' & '.join(inline(esc_text(c)) for c in r) + r' \\')
    out += [r'\bottomrule', r'\end{tabular}']
    return out, i


def split_row(row):
    return [c.strip() for c in row.strip().strip('|').split('|')]


# ---------------------------------------------------------------- 列表
ITEM_RE = re.compile(r'^(\d+)\.\s+(.*)$')
BULLET_RE = re.compile(r'^[-*]\s+(.*)$')
HEAD_RE = re.compile(r'^(#{1,4})\s+(.*)$')


def read_list(lines, i):
    """读一个列表：吸收列表项与其缩进续行（含行间公式），返回 (tex 行, 下一索引)。"""
    ordered = ITEM_RE.match(lines[i]) is not None
    out = [r'\begin{enumerate}' if ordered else r'\begin{itemize}']
    while i < len(lines):
        m = ITEM_RE.match(lines[i]) if ordered else BULLET_RE.match(lines[i])
        if m:
            out.append(r'\item ' + inline(esc_text(m.group(2) if ordered else m.group(1))))
            i += 1
            continue
        # 续行：缩进文本或行间公式，且不是新的列表项/标题
        if lines[i].strip() == '':
            j = i + 1
            while j < len(lines) and lines[j].strip() == '':
                j += 1
            if j >= len(lines):
                break
            nxt = lines[j]
            # 空行后仍是同类列表项 → 同一个列表继续（否则每条都被包成独立 enumerate）
            same_item = (ITEM_RE.match(nxt) if ordered else BULLET_RE.match(nxt))
            if same_item or nxt.startswith(' ') or nxt.startswith('\t'):
                i = j
                continue
            break
        if lines[i].startswith(' ') or lines[i].startswith('\t'):
            s = lines[i].strip()
            if s in MATH_OPEN:
                blk, i = read_math_block(lines, i)
                out += blk
                continue
            out.append(inline(esc_text(s)))
            i += 1
            continue
        break
    out.append(r'\end{enumerate}' if ordered else r'\end{itemize}')
    return out, i


# ---------------------------------------------------------------- 主转换
# 13 张表的 caption（按初稿出现顺序；自解释、含单位，符合规范 §四.3）
TABLE_CAPTIONS = {
    1: '下标与集合符号说明',            2: '已知参数与输入数据（含单位）',
    3: '由输入数据直接构造的辅助量',      4: '四问共用的基础物理决策变量',
    5: '问题二新增的随机规划变量',        6: '问题三新增的多阶段调整变量',
    7: '问题二典型日逐日指标（费用单位：元，电量单位：kWh）',
    8: '问题三四阶段策略典型日指标（费用单位：元，电量单位：kWh）',
    9: '问题三指定日期分阶段电量与费用（电量单位：kWh，费用单位：元）',
    10: '问题三情景数稳定性对照（K=4 与 K=8）',
    11: '问题四两口径费用与紧急购电对照（费用单位：元，电量单位：kWh）',
    12: '电价预测精度指标（误差单位：元/kWh）',
    13: '问题四 Q4-2 与 Q4-3 指标对照',
    14: '问题四两个口径的总体指标（费用单位：元，电量单位：kWh）',
}

# 第 14 张表在初稿里**没有表头也没有分隔行**（只有 4 行数据），
# 按每行的语义补一个表头，使它能排成正常的三线表。
HEADER_FIX = {14: ['指标', '数值', '单位', '说明']}


def convert(lines):
    out = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        s = raw.strip()
        if s == '':
            out.append('')
            i += 1
            continue
        # 行间公式
        if s in MATH_OPEN:
            blk, i = read_math_block(lines, i)
            out += [''] + blk + ['']
            continue
        # 表格
        if is_table_start(lines, i):
            blk, i = read_table(lines, i)
            convert.ntab += 1
            tag = 'tab:%d' % convert.ntab
            cap = TABLE_CAPTIONS.get(convert.ntab, '【待补表题】')
            out += ['', r'\begin{table}[H]', r'\centering', r'\zihao{5}'] + blk + \
                   [r'\caption{%s}' % cap, r'\label{%s}' % tag, r'\end{table}', '']
            continue
        # 标题
        h = HEAD_RE.match(raw)
        if h:
            lvl = len(h.group(1))
            cmd = {1: 'section', 2: 'subsection', 3: 'subsubsection', 4: 'paragraph'}[lvl]
            t = strip_num(h.group(2))
            if lvl == 1:
                out += ['', '\\%s{%s}' % (cmd, t), '']
            else:
                out += ['', '\\%s{%s}' % (cmd, t), '']
            i += 1
            continue
        # 列表
        if ITEM_RE.match(raw) or BULLET_RE.match(raw):
            blk, i = read_list(lines, i)
            out += [''] + blk + ['']
            continue
        # 普通段落
        out.append(inline(esc_text(s)))
        i += 1
    return out


def build_abstract(seg):
    """摘要页：弃 \\maketitle 与 abstract 环境，用紧凑居中块，关键词后另起一页。"""
    body = [ln for ln in seg if ln.strip()]
    title = ''
    text = []
    kw = ''
    for ln in body:
        s = ln.strip()
        if s.startswith('# '):
            title = s[2:].strip()
        elif s.startswith('## ') or s == '## 摘要':
            continue
        elif s.startswith('**关键词') or s.startswith('关键词'):
            kw = re.sub(r'^\*{0,2}关键词\s*[:：]?\*{0,2}\s*', '', s)
        elif s.startswith('【此处插入图'):
            continue                      # 摘要必须独占一页，流程图移到 §2.5
        else:
            # 摘要同样要转义 %：初稿里 "降低26.90%" 这类裸百分号会被 LaTeX
            # 当成注释，静默吞掉该行后半段（这里曾真的吞掉半段摘要）
            text.append(esc_text(s))
    out = [r'\begin{center}{\zihao{2}\heiti %s}\end{center}' % title, '',
           r'\vspace{0.6em}', r'\begin{center}{\zihao{4}\heiti 摘\quad 要}\end{center}',
           r'\vspace{0.4em}', r'{\zihao{-4}', '']
    out += text + ['', r'\noindent\textbf{关键词：}%s' % kw, r'}', '', r'\newpage']
    return out


def tidy(lines):
    """压缩多余空行。"""
    out = []
    for ln in lines:
        if ln == '' and out and out[-1] == '':
            continue
        out.append(ln)
    return out


def main():
    os.makedirs(SEC, exist_ok=True)
    os.makedirs(TAB, exist_ok=True)
    raw = clean(open(SRC, encoding='utf-8').read())
    lines = raw.split('\n')
    convert.ntab = 0          # 表号跨章节连续，不能在 convert() 内重置

    # 补三个缺失的顶层标题（插在图占位之前，否则结果图会留在上一章）。
    # 逆序插入，避免先插的行号影响后插的位置。
    for _, title, _, _, insert_before in reversed(SECTIONS):
        if insert_before:
            lines.insert(insert_before - 1, '# %s' % title)
            lines.insert(insert_before - 1, '')

    # 上面插了 3 个标题（每个占 2 行），原行号整体下移；切分边界必须同步平移，
    # 否则会切在表格中间（初稿那次就是表头落在上一章、数据落在下一章）。
    shifts = sorted(x for _, _, _, _, x in SECTIONS if x)
    def sh(pos):
        return 2 * sum(1 for s in shifts if s < pos)

    n_eq = 0
    for name, title, a, b, insert_before in SECTIONS:
        a2 = a + sh(a)
        b2 = (b + sh(b + 1)) if b else None
        seg = lines[a2 - 1:(b2 if b2 else len(lines))]
        if name == 'abstract':
            body = build_abstract(seg)
            text = '\n'.join(body).strip() + '\n'
        else:
            # 章标题由本脚本统一给出；去掉来源里那一行顶层标题，避免出现两个 \section
            # （初稿本有 一/二/三/四/五/九 的标题，六/七/八 的由上面插入）
            for k, ln in enumerate(seg):
                if ln.startswith('# '):
                    seg = seg[:k] + seg[k + 1:]
                    break
            body = tidy(convert(seg))
            n_eq += sum(1 for ln in body if ln.strip() == r'\begin{equation}')
            text = '\\section{%s}\n' % title + '\n'.join(body).strip() + '\n'
        open(os.path.join(SEC, name + '.tex'), 'w', encoding='utf-8').write(text)
        print('  %-12s %5d 行  ← 初稿 %d-%s' % (name + '.tex', len(body), a, b or 'EOF'))
    print('equation 环境合计 %d（应为 85）' % n_eq)


if __name__ == '__main__':
    sys.exit(main())
