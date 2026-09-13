#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_tables.py —— 生成题目强制要求的表 1 / 表 2 / 表 3

赛题原文要求（data/C题.md）：
  问题 1：论文中**以表 1 的格式**给出指定时间段的购电量及全天购电量和购电费，
          **以表 2 的格式**给出储能设备在指定时间段的充放电量及 0:00/24:00 储电量。
  问题 2、3：论文中**按表 1、表 2 和表 3 的格式**给出表 3 中指定日期的结果。

表 1 = 六个指定 10 分钟时段的购电量 + 全天购电量 + 全天购电费
表 2 = 六个四小时区间的充电量/放电量 + 0:00 储电量 + 24:00 储电量
表 3 = 四个指定日期的紧急购电时间段与购电量

数据源：outputs/result1.xlsx（问题一）与 result2_q2c.xlsx / result3.xlsx（问题二、三）。
表 1/表 2 对四个指定日期**合并成一张**（行＝指标、列＝日期），字段与题目完全一致，
省版面且更便于横向比较；表 3 按题目原样四栏并排。

用法：python3 gen_tables.py
"""
import os
import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'outputs')
TAB = os.path.join(HERE, 'tables')

SLOTS = ['10:00-10:10', '12:00-12:10', '14:00-14:10',
         '16:00-16:10', '18:00-18:10', '20:00-20:10']
BLOCKS = ['0:00-4:00', '4:00-8:00', '8:00-12:00',
          '12:00-16:00', '16:00-20:00', '20:00-24:00']
DATES = ['2025-03-20', '2025-06-21', '2025-09-23', '2025-12-21']
DTAG = ['2025.3.20', '2025.6.21', '2025.9.23', '2025.12.21']


def num(v, nd=2):
    return '—' if v is None else ('%.*f' % (nd, float(v)))


def read_sheet(path, sheet):
    ws = openpyxl.load_workbook(os.path.join(OUT, path), read_only=True)[sheet]
    return [r for r in ws.iter_rows(values_only=True)]


def date_rows(path):
    """把 per-date 的三张表读成 {日期: {...}}。"""
    out = {}
    plan = read_sheet(path, '计划购电量')
    hdr = [str(c) for c in plan[0]]
    for r in plan[1:]:
        if not r[0]:
            continue
        d = str(r[0])[:10]
        rec = {'plan': dict(zip(hdr[1:], r[1:]))}
        out[d] = rec
    try:
        adj = read_sheet(path, '调整购电量')
        ahdr = [str(c) for c in adj[0]]
        for r in adj[1:]:
            if r[0]:
                out.setdefault(str(r[0])[:10], {})['adj'] = dict(zip(ahdr[1:], r[1:]))
    except Exception:
        pass
    chg = read_sheet(path, '充放电量')
    cur = None
    for r in chg[1:]:
        if r[0]:
            cur = str(r[0])[:10]
            out.setdefault(cur, {})['soc'] = {}
        if cur and r[4] is not None:
            out[cur]['soc'][str(r[4]).strip()] = r[5]
        if cur and r[1]:
            out[cur].setdefault('blk', {})[str(r[1]).strip()] = (r[2], r[3])
    em = read_sheet(path, '紧急购电量')
    cur, pend = None, None
    for r in em[1:]:
        if r[0]:
            cur = str(r[0])[:10]
            out.setdefault(cur, {})['em'] = []
            pend = None
        if r[1]:
            pend = str(r[1])
        if r[2] is not None and cur and pend:
            out[cur]['em'].append((pend, r[2]))     # 金额在时段行的下一行
            pend = None
    return out


def tab1_tex(title, label, recs, cols, note='', hdr=None):
    """表 1 格式：行＝指标，列＝日期（问题一时只有一列）。"""
    L = [r'\begin{table}[H]', r'\centering', r'\zihao{5}',
         r'\begin{tabular}{l' + 'r' * len(cols) + '}', r'\toprule',
         ' & '.join(['指标'] + (hdr or cols)) + r' \\', r'\midrule']
    for s in SLOTS:
        L.append(' & '.join([s] + [num(recs[c]['plan'].get(s)) for c in cols]) + r' \\')
    L.append(r'\midrule')
    L.append(' & '.join(['全天购电量/kWh'] + [num(recs[c]['plan'].get('全天购电量')) for c in cols]) + r' \\')
    L.append(' & '.join(['全天购电费/元'] + [num(recs[c]['plan'].get('全天购电费')) for c in cols]) + r' \\')
    L += [r'\bottomrule', r'\end{tabular}', r'\caption{%s}' % title, r'\label{%s}' % label,
          r'\end{table}']
    if note:
        L.append(r'\par\vspace{1pt}{\zihao{6}注：%s}' % note)
    return '\n'.join(L) + '\n'


def tab2_tex(title, label, recs, cols, note='', hdr=None):
    L = [r'\begin{table}[H]', r'\centering', r'\zihao{5}',
         r'\begin{tabular}{l' + 'r' * len(cols) + '}', r'\toprule',
         ' & '.join(['时间段'] + (hdr or cols)) + r' \\', r'\midrule']
    L.append(r'\multicolumn{%d}{l}{\textit{充电量/kWh}} \\' % (len(cols) + 1))
    for b in BLOCKS:
        L.append(' & '.join([b] + [num(recs[c]['blk'].get(b, (None, None))[0]) for c in cols]) + r' \\')
    L.append(r'\midrule')
    L.append(r'\multicolumn{%d}{l}{\textit{放电量/kWh}} \\' % (len(cols) + 1))
    for b in BLOCKS:
        L.append(' & '.join([b] + [num(recs[c]['blk'].get(b, (None, None))[1]) for c in cols]) + r' \\')
    L.append(r'\midrule')
    L.append(' & '.join(['0:00 储电量/kWh'] + [num(recs[c]['soc'].get('0:00') or recs[c]['soc'].get('00:00')) for c in cols]) + r' \\')
    L.append(' & '.join(['24:00 储电量/kWh'] + [num(recs[c]['soc'].get('24:00')) for c in cols]) + r' \\')
    L += [r'\bottomrule', r'\end{tabular}', r'\caption{%s}' % title, r'\label{%s}' % label,
          r'\end{table}']
    if note:
        L.append(r'\par\vspace{1pt}{\zihao{6}注：%s}' % note)
    return '\n'.join(L) + '\n'


def tab1_two_tex(title, label, recs, cols, hdr, note=''):
    """表 1 格式（问题三）：`计划购电量`与`调整购电量`两个口径各成一组。"""
    L = [r'\begin{table}[H]', r'\centering', r'\zihao{5}',
         r'\begin{tabular}{l' + 'r' * len(cols) + '}', r'\toprule',
         ' & '.join(['指标'] + hdr) + r' \\', r'\midrule']
    for key, name in [('plan', '0:00 计划购电量'), ('adj', '调整后购电量')]:
        L.append(r'\multicolumn{%d}{l}{\textit{%s/kWh}} \\' % (len(cols) + 1, name))
        for s in SLOTS:
            L.append(' & '.join([s] + [num(recs[c][key].get(s)) for c in cols]) + r' \\')
        L.append(' & '.join(['全天'] + [num(recs[c][key].get('全天购电量')) for c in cols]) + r' \\')
        L.append(r'\midrule')
    L.append(' & '.join(['全天购电费/元'] + [num(recs[c]['plan'].get('全天购电费')) for c in cols]) + r' \\')
    L += [r'\bottomrule', r'\end{tabular}', r'\caption{%s}' % title, r'\label{%s}' % label,
          r'\end{table}']
    if note:
        L.append(r'\par\vspace{1pt}{\zihao{6}注：%s}' % note)
    return '\n'.join(L) + '\n'


def tab3_tex(title, label, recs, note=''):
    """表 3 格式：四个日期并排，每栏"时间段 + 购电量"，行数按最多的那天取。"""
    cols = [str(x) for d in DATES for x in (DTAG[DATES.index(d)], '购电量/kWh')]
    segs = [recs[d].get('em', []) or [] for d in DATES]
    nrow = max([len(s) for s in segs] + [1])
    L = [r'\begin{table}[H]', r'\centering', r'\zihao{5}',
         r'\begin{tabular}{' + 'l' * len(cols) + '}', r'\toprule',
         ' & '.join([r'\multicolumn{2}{c}{%s}' % t for t in DTAG]) + r' \\', r'\cmidrule(lr){1-2}\cmidrule(lr){3-4}\cmidrule(lr){5-6}\cmidrule(lr){7-8}',
         ' & '.join(['时间段', '购电量'] * 4) + r' \\', r'\midrule']
    for k in range(nrow):
        cells = []
        for s in segs:
            if k < len(s):
                cells += [s[k][0], num(s[k][1])]
            else:
                cells += ['—', '—']
        L.append(' & '.join(cells) + r' \\')
    L += [r'\bottomrule', r'\end{tabular}', r'\caption{%s}' % title, r'\label{%s}' % label,
          r'\end{table}']
    if note:
        L.append(r'\par\vspace{1pt}{\zihao{6}注：%s}' % note)
    return '\n'.join(L) + '\n'


def main():
    os.makedirs(TAB, exist_ok=True)
    # ---- 问题一（单日，题目原格式）----
    plan1 = {str(a): b for a, b in read_sheet('result1.xlsx', '计划购电量') if a}
    soc1, blk1 = {}, {}
    for r in read_sheet('result1.xlsx', '充放电量')[1:]:
        if r[0]:
            blk1[str(r[0])] = (r[1], r[2])
        if r[3]:
            soc1[str(r[3]).strip()] = r[4]
    import scipy.io as sio
    Z1 = float(sio.loadmat(os.path.join(OUT, 'final_results_q1.mat'))['Z'].ravel()[0])
    plan1['全天购电量'] = sum(v for k, v in plan1.items() if ':' in k)
    plan1['全天购电费'] = Z1
    rec1 = {'plan': plan1, 'blk': blk1, 'soc': soc1}
    open(os.path.join(TAB, 'tab1_q1.tex'), 'w', encoding='utf-8').write(
        tab1_tex('微网在指定时间段的购电量及全天的购电量和购电费（问题一）', 'tab:m1-q1',
                 {'—': rec1}, ['—'],
                 '购电量单位 kWh，购电费单位元；全天按 144 个 10 min 时段累计。',
                 hdr=['购电量/kWh']))
    open(os.path.join(TAB, 'tab2_q1.tex'), 'w', encoding='utf-8').write(
        tab2_tex('储能设备在指定时间段的充放电量及 0:00 和 24:00 的储电量（问题一）', 'tab:m2-q1',
                 {'—': rec1}, ['—'], '充放电量与储电量单位均为 kWh。', hdr=['数值/kWh']))

    # ---- 问题二、三（四个指定日期）----
    for path, tag, name in [('result2_q2c.xlsx', 'q2', '问题二'), ('result3.xlsx', 'q3', '问题三')]:
        recs = date_rows(path)
        miss = [d for d in DATES if d not in recs]
        if miss:
            print('  !! %s 缺日期 %s' % (path, miss))
        ttl1 = '微网在指定时间段的购电量及全天的购电量和购电费（%s）' % name
        nt1 = '购电量单位 kWh，购电费单位元；列对应题目表 3 的四个指定日期。'
        if tag == 'q3':
            body1 = tab1_two_tex(ttl1, 'tab:m1-%s' % tag, recs, DATES, DTAG)
        else:
            body1 = tab1_tex(ttl1, 'tab:m1-%s' % tag, recs, DATES, nt1, hdr=DTAG)
        open(os.path.join(TAB, 'tab1_%s.tex' % tag), 'w', encoding='utf-8').write(body1)
        open(os.path.join(TAB, 'tab2_%s.tex' % tag), 'w', encoding='utf-8').write(
            tab2_tex('储能设备在指定时间段的充放电量及 0:00 和 24:00 的储电量（%s）' % name,
                     'tab:m2-%s' % tag, recs, DATES,
                     '充放电量与储电量单位均为 kWh。', hdr=DTAG))
        open(os.path.join(TAB, 'tab3_%s.tex' % tag), 'w', encoding='utf-8').write(
            tab3_tex('微网在指定日期的紧急购电量（%s）' % name, 'tab:m3-%s' % tag, recs,
                     '购电量单位 kWh；"—"表示该日期段数少于其他日期。'))
        print('  已生成 %s 的三张强制表' % name)

    print('题目强制表已写入 paper/tables/')


if __name__ == '__main__':
    main()
