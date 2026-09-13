#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_mandated_tables.py —— 题目强制表 1 / 表 2 / 表 3（严格按题目版式，**内联进正文**）

编程手口径（2026-09-13 修订）：
  · 题目的“表 1/表 2/表 3”指的是**表格格式**，不是要求单独占一页横版；
  · 因此按题目版式出表后**融入正文行文**，与小字号紧凑列距内联；
  · **画好表格边框**（全框线 \\hline，不用 booktabs 三线）；
  · 结果值 **\\textbf 加粗**以示重点，且**一律不换行**。

题目版式（逐字对照 data/C题.md）：
  表 1  三组「时间段｜购电量」× 两行 + 末行「全天购电量」「全天购电费」
  表 2  两组「时间段｜充电量｜放电量」× 三行 + 末行「0:00 储电量」「24:00 储电量」
  表 3  四个日期并排，每栏「时间段｜购电量」

问题一为单日：一张表 1 + 一张表 2。
问题二、三的指定日期有四个：每个日期各一张表 1 与一张表 2（叠放），表 3 一张并排四栏。

用法：python3 gen_mandated_tables.py
"""
import os
import sys

import openpyxl

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'outputs')
TAB = os.path.join(ROOT, 'paper', 'tables')

SLOTS = ['10:00-10:10', '12:00-12:10', '14:00-14:10',
         '16:00-16:10', '18:00-18:10', '20:00-20:10']
BLOCKS = ['0:00-4:00', '4:00-8:00', '8:00-12:00',
          '12:00-16:00', '16:00-20:00', '20:00-24:00']
DATES = ['2025-03-20', '2025-06-21', '2025-09-23', '2025-12-21']
DTAG = ['2025.3.20', '2025.6.21', '2025.9.23', '2025.12.21']

WRAP = r'{\zihao{6}\setlength{\tabcolsep}{2pt}'      # 内联：六号字、窄列距


def num(v, nd=2):
    return '' if v is None else ('%.*f' % (nd, float(v)))


def bold(v, nd=2):
    return r'\textbf{%s}' % num(v, nd)


def read_sheet(path, sheet):
    wb = openpyxl.load_workbook(os.path.join(OUT, path), read_only=True)
    rows = [r for r in wb[sheet].iter_rows(values_only=True)]
    wb.close()
    return rows


def _try(path, sheet):
    try:
        return read_sheet(path, sheet)
    except KeyError:
        return None


def read_all(path):
    """读结果表；result1 为两列明细，result2/3 为宽表，统一成同一套字段。"""
    pl = read_sheet(path, '计划购电量')
    h = [str(c) for c in pl[0]]
    if '全天购电量' in h:
        ip, ie = h.index('全天购电量'), h.index('全天购电费')
        plan = {str(r[0])[:10]: {'slot': dict(zip(h[1:ie], r[1:ie])),
                                 'total': r[ip], 'cost': r[ie]}
                for r in pl[1:] if r[0]}
    else:
        plan = {'slot': {str(r[0]).strip(): r[1] for r in pl[1:] if r[0]},
                'total': None, 'cost': None}

    adj = {}
    ar = _try(path, '调整购电量')
    if ar and '全天购电量' in [str(c) for c in ar[0]]:
        hh = [str(c) for c in ar[0]]
        ia, ib = hh.index('全天购电量'), hh.index('全天购电费')
        for r in ar[1:]:
            if r[0]:
                adj[str(r[0])[:10]] = {'slot': dict(zip(hh[1:ib], r[1:ib])),
                                       'total': r[ia], 'cost': r[ib]}

    ch = read_sheet(path, '充放电量')
    hd = [str(c).strip() if c is not None else '' for c in ch[0]]
    i_blk = hd.index('时间段') if '时间段' in hd else 1
    i_chg, i_dis = hd.index('充电量'), hd.index('放电量')
    i_soc, i_t = hd.index('储电量'), hd.index('时刻')
    i_date = hd.index('日期') if '日期' in hd else None
    soc, blk, cur = {}, {}, None
    for r in ch[1:]:
        if i_date is not None and r[i_date]:
            cur = str(r[i_date])[:10]
        key = cur or '_'
        soc.setdefault(key, {}); blk.setdefault(key, {})
        lb = str(r[i_blk]).strip() if r[i_blk] is not None else ''
        if lb in BLOCKS:
            blk[key][lb] = (r[i_chg], r[i_dis])
        if r[i_t] is not None:
            soc[key][str(r[i_t]).strip()] = r[i_soc]

    em, cur, pend = {}, None, None
    for r in (_try(path, '紧急购电量') or [])[1:]:
        if r[0]:
            cur = str(r[0])[:10]; em[cur], pend = [], None
        if r[1]:
            pend = str(r[1])
        if r[2] is not None and cur and pend:
            em[cur].append((pend, r[2]))
            if r[1] is None:
                pend = None
    return {'plan': plan, 'adj': adj, 'soc': soc, 'blk': blk, 'em': em}


def table1(rec, date=None, cap=''):
    """题目表 1 版式。"""
    use = (rec['adj'].get(date) if date else None) or (
        rec['plan'][date] if date else rec['plan'])
    L = [r'\begin{tabular}{|c|r|c|r|c|r|}', r'\hline',
         r'时间段 & 购电量/kWh & 时间段 & 购电量/kWh & 时间段 & 购电量/kWh \\', r'\hline']
    for row in (SLOTS[:3], SLOTS[3:]):
        cells = []
        for t in row:
            cells += [t, bold(use['slot'].get(t))]
        L += [' & '.join(cells) + r' \\', r'\hline']
    L.append('全天购电量 & %s & & & 全天购电费 & %s \\\\' % (bold(use['total']), bold(use['cost'])))
    L += [r'\hline', r'\end{tabular}']
    if cap:
        L.append(r'\par\vspace{1pt}{\zihao{6}%s}' % cap)
    return '\n'.join(L) + '\n'


def table2(rec, date=None, cap=''):
    """题目表 2 版式。"""
    key = date or '_'
    blk, soc = rec['blk'][key], rec['soc'][key]
    L = [r'\begin{tabular}{|c|r|r|c|r|r|}', r'\hline',
         r'时间段 & 充电量/kWh & 放电量/kWh & 时间段 & 充电量/kWh & 放电量/kWh \\', r'\hline']
    for i in range(0, 6, 2):
        a, b = BLOCKS[i], BLOCKS[i + 1]
        ca, da = (blk.get(a) or (None, None))
        cb, db = (blk.get(b) or (None, None))
        L += ['%s & %s & %s & %s & %s & %s \\\\' % (a, bold(ca), bold(da), b, bold(cb), bold(db)),
              r'\hline']
    L.append('0:00 储电量 & %s & & 24:00 储电量 & %s & \\\\' % (
        bold(soc.get('00:00') or soc.get('0:00')), bold(soc.get('24:00'))))
    L += [r'\hline', r'\end{tabular}']
    if cap:
        L.append(r'\par\vspace{1pt}{\zihao{6}%s}' % cap)
    return '\n'.join(L) + '\n'


def table3(rec, cap=''):
    """题目表 3 版式：四日期并排。"""
    segs = [rec['em'].get(d) or [] for d in DATES]
    n = max([len(s) for s in segs] + [1])
    L = [r'\begin{tabular}{|c|r|c|r|c|r|c|r|}', r'\hline',
         ' & '.join(r'\multicolumn{2}{c|}{%s}' % t for t in DTAG) + r' \\', r'\hline',
         ' & '.join(['时间段', '购电量/kWh'] * 4) + r' \\', r'\hline']
    for k in range(n):
        cells = []
        for s in segs:
            cells += ([str(s[k][0]), bold(s[k][1])] if k < len(s) else ['', ''])
        L += [' & '.join(cells) + r' \\', r'\hline']
    L.append(r'\end{tabular}')
    if cap:
        L.append(r'\par\vspace{1pt}{\zihao{6}%s}' % cap)
    return '\n'.join(L) + '\n'


def block(title, blocks):
    """内联块：不单独占页，直接排在行文中。"""
    L = [WRAP, r'\begin{center}']
    L += blocks
    L += [r'\end{center}', r'}']
    return '\n'.join(L) + '\n'


def main():
    import scipy.io as sio
    r1 = read_all('result1.xlsx')
    r1['plan']['total'] = sum(v for k, v in r1['plan']['slot'].items() if ':' in k)
    r1['plan']['cost'] = float(sio.loadmat(os.path.join(OUT, 'final_results_q1.mat'))['Z'].ravel()[0])
    for k in ('soc', 'blk'):
        r1[k] = {'_': r1[k].get('_', {})}

    pages = {}
    pages['t_q1'] = block('', [
        table1(r1, cap='表 1　微网在指定时间段的购电量及全天的购电量和购电费'),
        r'\vspace{0.3\baselineskip}',
        table2(r1, cap='表 2　储能设备在指定时间段的充放电量及 0:00 和 24:00 的储电量')])

    for path, tag, name in [('result2_q2c.xlsx', 'q2', '问题二'),
                            ('result3.xlsx', 'q3', '问题三')]:
        rec = read_all(path)
        b = []
        for i, d in enumerate(DATES):
            b += [table1(rec, d, cap='表 1（%s）　%s' % (DTAG[i], name)),
                  r'\vspace{0.3\baselineskip}']
            b += [table2(rec, d, cap='表 2（%s）　%s' % (DTAG[i], name)),
                  r'\vspace{0.3\baselineskip}']
        b.append(table3(rec, cap='表 3　微网在指定日期的紧急购电量（%s）' % name))
        pages['t_%s' % tag] = block('', b)

    os.makedirs(TAB, exist_ok=True)
    for k, v in pages.items():
        open(os.path.join(TAB, k + '.tex'), 'w', encoding='utf-8').write(v)
    for old in ['tab1_q1', 'tab2_q1', 'tab1_q2', 'tab2_q2', 'tab3_q2',
                'tab1_q3', 'tab2_q3', 'tab3_q3', 't_q2_1', 't_q2_2', 't_q3_1', 't_q3_2',
                't_q2_12', 't_q2_3', 't_q3_12', 't_q3_3']:
        p = os.path.join(TAB, old + '.tex')
        if os.path.exists(p):
            os.remove(p)
    print('已生成内联强制表 3 个片段：%s' % ', '.join(sorted(pages)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
