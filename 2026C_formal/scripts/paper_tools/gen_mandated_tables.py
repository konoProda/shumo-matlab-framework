#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_mandated_tables.py —— 生成题目强制表 1 / 表 2 / 表 3（横版 + 全框线）

编程手要求（2026-09-13）：
  · **严格按照题目要求的版式**，不再自行转置；
  · **横版展示**（landscape 页），**画好表格边框**（全框线，不用 booktabs 三线）；
  · 数据量小的结果值**加粗以示重点**，但**不换行**（仅公式换行）。

题目版式（逐字对照 data/C题.md）：

  表 1  三组「时间段｜购电量」，末行「全天购电量」「全天购电费」
        | 时间段 | 购电量 | 时间段 | 购电量 | 时间段 | 购电量 |
        | 10:00-10:10 | | 12:00-12:10 | | 14:00-14:10 |
        | 16:00-16:10 | | 18:00-18:10 | | 20:00-20:10 |
        | 全天购电量 | | | | 全天购电费 | |

  表 2  两组「时间段｜充电量｜放电量」，末行「0:00 储电量」「24:00 储电量」
        | 时间段 | 充电量 | 放电量 | 时间段 | 充电量 | 放电量 |
        | 0:00-4:00 | | | 4:00-8:00 | | |
        ... (8:00-12:00/12:00-16:00、16:00-20:00/20:00-24:00)
        | 0:00 储电量 | | | 24:00 储电量 | | |

  表 3  四个日期并排，每栏「时间段｜购电量」
        | 2025.3.20 | | 2025.6.21 | | 2025.9.23 | | 2025.12.21 | |
        | 时间段 | 购电量 | 时间段 | 购电量 | ... |
        | 数据行... |

问题一为单日，直接给一张表 1 与一张表 2；
问题二、三的“指定日期”有四个，故每个日期各给一张表 1 与表 2（共四张），
叠放在横版页内；表 3 按题目原样四栏并排。

用法：python3 gen_mandated_tables.py
"""
import os
import sys

import openpyxl

# 本脚本在 scripts/paper_tools/ 下，产物一律写回 ../../paper/
HERE = os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), 'paper')
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'outputs')
TAB = os.path.join(HERE, 'tables')

SLOTS = ['10:00-10:10', '12:00-12:10', '14:00-14:10',
         '16:00-16:10', '18:00-18:10', '20:00-20:10']
BLOCKS = ['0:00-4:00', '4:00-8:00', '8:00-12:00',
          '12:00-16:00', '16:00-20:00', '20:00-24:00']
DATES = ['2025-03-20', '2025-06-21', '2025-09-23', '2025-12-21']
DTAG = ['2025.3.20', '2025.6.21', '2025.9.23', '2025.12.21']

B = r'\textbf{%s}'          # 结果值加粗，且不换行


def num(v, nd=2):
    return '' if v is None else ('%.*f' % (nd, float(v)))


def bold(v, nd=2):
    return B % num(v, nd)


def read_sheet(path, sheet):
    ws = openpyxl.load_workbook(os.path.join(OUT, path), read_only=True)[sheet]
    rows = [r for r in ws.iter_rows(values_only=True)]
    ws.parent.close()
    return rows


def read_all(path):
    """读一份结果表的全部所需字段。

    结果表有两种存法：
      · result1.xlsx —— 「时间段｜购电量」两列，逐 144 槽明细（问题一是单日）；
      · result2/3.xlsx —— 宽表，每行一天、146 列（144 槽 + 全天购电量 + 全天购电费）。
    这里统一成同一套字段，便于后面按题目版式出表。
    """
    pl = read_sheet(path, '计划购电量')
    h = [str(c) for c in pl[0]]
    if '全天购电量' in h:
        ip, ie = h.index('全天购电量'), h.index('全天购电费')
        plan = {str(r[0])[:10]: {'slot': dict(zip(h[1:ie], r[1:ie])),
                                 'total': r[ip], 'cost': r[ie]}
                for r in pl[1:] if r[0]}
    else:
        # 两列明细：槽标签 → 购电量；全天合计与费用由调用方补
        slots = {str(r[0]).strip(): r[1] for r in pl[1:] if r[0]}
        plan = {'slot': slots, 'total': None, 'cost': None}

    adj = {}
    try:
        for r in read_sheet(path, '调整购电量')[1:]:
            if r[0]:
                adj[str(r[0])[:10]] = {'slot': dict(zip(h[1:ie], r[1:ie])),
                                       'total': r[ip], 'cost': r[ie]}
    except Exception:
        pass

    # 充放电量：result1 为「6 行四小时区间 + 时刻/储电量 两行」；
    # result2/3 为「日期列 + 区间列」的成组布局，两者都按 (区间 → 充/放) 收。
    # 列位置按表头取：result1 无「日期」列（5 列），result2/3 有（6 列），
    # 写死下标会在其中一种上越界。
    ch = read_sheet(path, '充放电量')
    hd = [str(c).strip() if c is not None else '' for c in ch[0]]
    i_blk = hd.index('时间段') if '时间段' in hd else 1
    i_chg = hd.index('充电量'); i_dis = hd.index('放电量')
    i_soc = hd.index('储电量'); i_t = hd.index('时刻')
    i_date = hd.index('日期') if '日期' in hd else None
    soc, blk = {}, {}
    cur = None
    for r in ch[1:]:
        # 有「日期」列时分日建键；result1 无该列，全天统一记为 '_'
        if i_date is not None and r[i_date]:
            cur = str(r[i_date])[:10]
            soc[cur], blk[cur] = {}, {}
        key = cur or '_'
        soc.setdefault(key, {}); blk.setdefault(key, {})
        lb = str(r[i_blk]).strip() if r[i_blk] is not None else ''
        if lb in BLOCKS:
            blk[key][lb] = (r[i_chg], r[i_dis])
        if r[i_t] is not None:
            soc[key][str(r[i_t]).strip()] = r[i_soc]

    # 问题一没有紧急购电页，缺表即视为空（不报错）
    em, cur, pend = {}, None, None
    try:
        em_rows = read_sheet(path, '紧急购电量')[1:]
    except KeyError:
        em_rows = []
    for r in em_rows:
        if r[0]:
            cur = str(r[0])[:10]
            em[cur], pend = [], None
        if r[1]:
            pend = str(r[1])
        if r[2] is not None and cur and pend:
            em[cur].append((pend, r[2]))
            if r[1] is None:
                pend = None
    return {'plan': plan, 'adj': adj, 'soc': soc, 'blk': blk, 'em': em}


# ------------------------------------------------------------------ 表 1
def table1(rec, date=None, cap='', label=''):
    """题目表 1 版式：三组「时间段｜购电量」+ 全天行。"""
    src = rec['adj'].get(date) if date else None
    plan = rec['plan'][date] if date else rec['plan']
    use = src or plan
    L = [r'\begin{tabular}{|c|r|c|r|c|r|}', r'\hline',
         r'时间段 & 购电量/kWh & 时间段 & 购电量/kWh & 时间段 & 购电量/kWh \\', r'\hline']
    # 题目是三组列 × 两行：第一行 10/12/14 点，第二行 16/18/20 点
    for row in (SLOTS[:3], SLOTS[3:]):
        cells = []
        for t in row:
            cells += [t, bold(use['slot'].get(t))]
        L.append(' & '.join(cells) + r' \\')
        L.append(r'\hline')
    L.append('全天购电量 & %s & & & 全天购电费 & %s \\\\' % (bold(use['total']), bold(use['cost'])))
    L += [r'\hline', r'\end{tabular}']
    if cap:
        L.append(r'\par\vspace{2pt}{\zihao{6}%s}' % cap)
    return '\n'.join(L) + '\n'


# ------------------------------------------------------------------ 表 2
def table2(rec, date=None, cap=''):
    """题目表 2 版式：两组「时间段｜充电量｜放电量」+ 0:00/24:00 储电量行。"""
    key = date or '_'
    blk = rec['blk'][key]
    soc = rec['soc'][key]
    L = [r'\begin{tabular}{|c|r|r|c|r|r|}', r'\hline',
         r'时间段 & 充电量/kWh & 放电量/kWh & 时间段 & 充电量/kWh & 放电量/kWh \\', r'\hline']
    for i in range(0, 6, 2):
        a, b = BLOCKS[i], BLOCKS[i + 1]
        ca, da = (blk.get(a) or (None, None))[0], (blk.get(a) or (None, None))[1]
        cb, db = (blk.get(b) or (None, None))[0], (blk.get(b) or (None, None))[1]
        L.append('%s & %s & %s & %s & %s & %s \\\\' % (a, bold(ca), bold(da), b, bold(cb), bold(db)))
        L.append(r'\hline')
    e0 = soc.get('00:00') or soc.get('0:00')
    e24 = soc.get('24:00')
    L.append('0:00 储电量 & %s & & 24:00 储电量 & %s & \\\\' % (bold(e0), bold(e24)))
    L += [r'\hline', r'\end{tabular}']
    if cap:
        L.append(r'\par\vspace{2pt}{\zihao{6}%s}' % cap)
    return '\n'.join(L) + '\n'


# ------------------------------------------------------------------ 表 3
def table3(rec, cap=''):
    """题目表 3 版式：四个日期并排，每栏「时间段｜购电量」。"""
    segs = [rec['em'].get(d) or [] for d in DATES]
    n = max([len(s) for s in segs] + [1])
    L = [r'\begin{tabular}{|c|r|c|r|c|r|c|r|}', r'\hline',
         ' & '.join(r'\multicolumn{2}{c|}{%s}' % t for t in DTAG) + r' \\', r'\hline',
         ' & '.join(['时间段', '购电量/kWh'] * 4) + r' \\', r'\hline']
    for k in range(n):
        cells = []
        for s in segs:
            if k < len(s):
                cells += [str(s[k][0]), bold(s[k][1])]
            else:
                cells += ['', '']
        L.append(' & '.join(cells) + r' \\')
        L.append(r'\hline')
    L.append(r'\end{tabular}')
    if cap:
        L.append(r'\par\vspace{2pt}{\zihao{6}%s}' % cap)
    return '\n'.join(L) + '\n'


def landscape(title, blocks):
    """一页横版：\\begin{landscape} 内按两栏排，左右各放一组表。"""
    L = [r'\begin{landscape}', r'\vspace*{-1.4\baselineskip}',
         r'\begin{center}{\heiti\zihao{4}%s}\end{center}' % title,
         r'\vspace{0.1\baselineskip}', r'{\zihao{6}']
    L += blocks
    L += [r'}', r'\end{landscape}']
    return '\n'.join(L) + '\n'


def two_col(left, right):
    """左右两栏并排（横版页宽 24.5cm，每栏约 11.6cm）。"""
    return '\n'.join([
        r'\noindent',
        r'\begin{minipage}[t]{0.485\linewidth}', left, r'\end{minipage}'
        r'\hfill',
        r'\begin{minipage}[t]{0.485\linewidth}', right, r'\end{minipage}',
    ])


def main():
    r1 = read_all('result1.xlsx')
    import scipy.io as sio
    Z1 = float(sio.loadmat(os.path.join(OUT, 'final_results_q1.mat'))['Z'].ravel()[0])
    r1['soc'] = {'_': r1['soc'].get('_', {})}
    r1['blk'] = {'_': r1['blk'].get('_', {})}
    r1['plan']['total'] = sum(v for k, v in r1['plan']['slot'].items() if ':' in k)
    r1['plan']['cost'] = Z1

    pages = {}

    # —— 问题一：表 1 + 表 2 同页 ——
    pages['t_q1'] = landscape(
        '问题一：指定时间段购电量与储能充放电量（题目表 1、表 2 格式）',
        [two_col(
            table1(r1, cap='（a）微网在指定时间段的购电量及全天的购电量和购电费'),
            table2(r1, cap='（b）储能设备在指定时间段的充放电量及 0:00 和 24:00 的储电量'))])

    # —— 问题二、问题三：每个指定日期各一张表 1 与表 2，表 3 另页 ——
    for path, tag, name in [('result2_q2c.xlsx', 'q2', '问题二'),
                            ('result3.xlsx', 'q3', '问题三')]:
        rec = read_all(path)
        b1 = []
        for i, d in enumerate(DATES):
            if i:
                b1.append(r'\vspace{0.5\baselineskip}')
            b1.append(table1(rec, d, cap='表 1（%s）　%s' % (DTAG[i], name)))
        b2 = []
        for i, d in enumerate(DATES):
            if i:
                b2.append(r'\vspace{0.5\baselineskip}')
            b2.append(table2(rec, d, cap='表 2（%s）　%s' % (DTAG[i], name)))
        pages['t_%s' % tag] = landscape(
            '%s：四个指定日期的结果（题目表 1、表 2、表 3 格式）' % name,
            [two_col('\n'.join(b1), '\n'.join(b2)),
             r'\vspace{0.5\baselineskip}',
             r'\begin{center}', table3(rec, cap='微网在指定日期的紧急购电量（%s）' % name),
             r'\end{center}'])

    os.makedirs(TAB, exist_ok=True)
    for k, v in pages.items():
        open(os.path.join(TAB, k + '.tex'), 'w', encoding='utf-8').write(v)
    # 清掉上一版（转置版）生成的文件，避免 \input 到旧表
    for old in ['tab1_q1', 'tab2_q1', 'tab1_q2', 'tab2_q2', 'tab3_q2',
                'tab1_q3', 'tab2_q3', 'tab3_q3', 't_q2_1', 't_q2_2', 't_q3_1', 't_q3_2',
                't_q2_12', 't_q2_3', 't_q3_12', 't_q3_3']:
        p = os.path.join(TAB, old + '.tex')
        if os.path.exists(p):
            os.remove(p)
    print('已生成横版强制表 %d 页：%s' % (len(pages), ', '.join(sorted(pages))))
    return 0


if __name__ == '__main__':
    sys.exit(main())
