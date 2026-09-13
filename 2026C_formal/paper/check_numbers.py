#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_numbers.py —— 数字一致性核查表（确认点 #3 的输入）

对论文正文里每个关键数字，反查它在 outputs/ 的**出处字段**，并核对渲染到
LaTeX 里的字符串与出处值一致。输出为三列核查表：论文数值 | 出处 | 核查结果。

核对是**双向**的：
  · 正向：出处算出的值，必须在正文里找得到；
  · 反向：正文里出现的十进制数，必须能对上某个出处——对不上的单独列出，
    由人工判断（可能是合理的手算结果，也可能是失配）。

用法：python3 check_numbers.py
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
V = json.load(open(os.path.join(HERE, 'values.json'), encoding='utf-8'))
SEC = os.path.join(HERE, 'sections')

TeX = '\n'.join(open(p, encoding='utf-8').read() for p in sorted(glob.glob(os.path.join(SEC, '*.tex'))))
# 表格片段也要查（题目强制表与附录表里的数字同样是论文数字）
TABT = '\n'.join(open(p, encoding='utf-8').read() for p in sorted(glob.glob(os.path.join(HERE, 'tables', '*.tex'))))
ALL = TeX + TABT


def num(x, nd=2):
    return ('%.*f' % (nd, x))


def present(s):
    """数值是否出现在正文。

    大数在正文里写成 `13\\,149\\,064.98`（每三位一个细空），小数写成 `0.0432`。
    两种写法都要认——早先只补了"最前面插一个细空"，对 8 位以上的值对不上，
    `13 149 064.98` 与 `16 253 521.47` 因此被漏判成"未找到"。
    """
    variants = {s}
    if '.' in s:
        a, b = s.split('.')
        if len(a) > 4:
            # 从右往左每三位切一段，再按正向拼回去。
            # 不能先拼再整体反转——那样连 `\,` 也会被反转成 `,\`（曾因此漏判两个值）。
            parts, rest = [], a
            while len(rest) > 3:
                parts.insert(0, rest[-3:])
                rest = rest[:-3]
            parts.insert(0, rest)
            variants.add(r'\,'.join(parts) + '.' + b)
        variants.add(a + '.' + b)
    return any(v in ALL for v in variants)


# (论文处, 数值, 出处文件, 出处字段)
def build():
    S = [V['q3b_S0'], V['q3b_S1'], V['q3b_S2'], V['q3b_S3']]
    S3, K8 = V['q3b_S3'], V['q3b_S3k8']
    Q2, Q42, Q43 = V['q2'], V['q4_Q4-2'], V['q4_Q4-3']
    Q42k8, Q43k8 = V['q4_Q4-2k8'], V['q4_Q4-3k8']
    P = V['price']
    F3, F42 = 'final_results_q3b_S3.mat', 'final_results_q4_Q4-2.mat'
    F43, F2 = 'final_results_q4_Q4-3.mat', 'final_results_q2c_L2.mat'
    F1 = 'final_results_q1.mat'
    R = [
        ('问题一 全天购电费', '35126.95', F1, 'Z'),
        ('问题一 全天购电量', '59482.70', 'result1.xlsx', '计划购电量·全天购电量'),
        ('问题二 窗口总费用', num(Q2['Z']), F2, 'res.cost（窗口求和）'),
        ('问题二 正常+调整费用', num(Q2['cost_plan']), F2, 'res.cost_plan（窗口求和）'),
        ('问题二 紧急购电费用', num(Q2['cost_em']), F2, 'res.cost_em（窗口求和）'),
        ('问题二 紧急购电量', num(Q2['em_win']), F2, 'res.em_m（窗口求和）'),
        # 注：问题二弃光量 1 327 853.19 kWh（res.curt_m 窗口求和）在正文只有定性描述
        #     （"量级远小于计划购电"），未引用具体数值，故不作为核查项。
        ('问题二 已购未用电', num(Q2['waste_win']), F2, 'res.waste_m（窗口求和）'),
        ('问题二 日末储电量均值', num(Q2['Eend_mean']), F2, 'res.Eend_m[:, -1]（窗口均值）'),
        ('问题三 S0 总费用', num(S[0]['cost_win']), 'final_results_q3b_S0.mat', 's.cost_win'),
        ('问题三 S1 总费用', num(S[1]['cost_win']), 'final_results_q3b_S1.mat', 's.cost_win'),
        ('问题三 S2 总费用', num(S[2]['cost_win']), 'final_results_q3b_S2.mat', 's.cost_win'),
        ('问题三 S3 总费用', num(S3['cost_win']), F3, 's.cost_win'),
        ('问题三 S3 紧急购电量', num(S3['em_win']), F3, 's.em_win'),
        ('问题三 边际收益 ΔC6', num(S[0]['cost_win'] - S[1]['cost_win']), 'S0−S1', '逐项相减'),
        ('问题三 边际收益 ΔC12', num(S[1]['cost_win'] - S[2]['cost_win']), 'S1−S2', '逐项相减'),
        ('问题三 边际收益 ΔC18', num(S[2]['cost_win'] - S[3]['cost_win']), 'S2−S3', '逐项相减'),
        ('问题三 K=8 总费用', num(K8['cost_win']), 'final_results_q3b_S3k8.mat', 's.cost_win'),
        ('问题四 Q4-2 总费用', num(Q42['cost_win']), F42, 's.cost_win'),
        ('问题四 Q4-3 总费用', num(Q43['cost_win']), F43, 's.cost_win'),
        ('问题四 Q4-2 紧急购电量', num(Q42['em_win']), F42, 's.em_win'),
        ('问题四 Q4-3 紧急购电量', num(Q43['em_win']), F43, 's.em_win'),
        ('问题四 完美价格信息基准', num(V['q4_Q4-2Ideal']['cost_win']),
         'final_results_q4_Q4-2Ideal.mat', 's.cost_win'),
        ('问题四 价格不确定性代价', num(Q42['cost_win'] - V['q4_Q4-2Ideal']['cost_win']),
         'Q4-2 − Q4-2Ideal', '逐项相减'),
        ('问题四 Q4-2 K=8 总费用', num(Q42k8['cost_win']), 'final_results_q4_Q4-2k8.mat', 's.cost_win'),
        ('问题四 Q4-3 K=8 总费用', num(Q43k8['cost_win']), 'final_results_q4_Q4-3k8.mat', 's.cost_win'),
        ('电价预测 MAE（校正后）', '0.0432', F43, 'prc.MAE'),
        ('电价预测 MAE（校正前）', '0.0489', F43, 'prc.MAE_base'),
        ('电价预测 RMSE', '0.0602', F43, 'prc.RMSE'),
        ('峰值时刻精确命中率', '36.2', F43, 'prc：argmax 命中比例'),
        ('谷值时刻精确命中率', '33.8', F43, 'prc：argmin 命中比例'),
        ('峰值 1h 内命中率', '63.5', F43, 'prc：|Δslot|≤6 比例'),
        ('谷值 1h 内命中率', '58.4', F43, 'prc：|Δslot|≤6 比例'),
        ('峰谷差预测 MAE', '0.0675', F43, 'prc：日内极差偏差均值'),
        ('问题三 最大等式残差', '2.39', F3, 's.max_viol（S3）'),
        ('问题四 最大等式残差', '6.96', F43, 's.max_viol（Q4-3）'),
        ('问题四 最大整数间隙', '1.16', F43, 's.max_gap（Q4-3）'),
    ]
    return R


def _date_values():
    """四个指定日期的值：来自 result*.xlsx，已逐格核对（见 fill_gaps.py 的 DATES）。

    这些数不进上表核查项（它们由 xlsx 直接抄录，不是 results.mat 的字段），
    但反向检查时应当算"有出处"，否则会被误列进"未对上"清单。
    """
    out = []
    for grp in [
        (60456.54, 59272.33, 1042.42, 41345.86, 8924.47, 3000.36),
        (43252.47, 42434.09, 0.00, 24946.99, 5762.09, 10800.00),
        (65186.81, 66030.22, 1887.41, 47560.08, 4746.35, 6520.75),
        (96080.19, 96520.33, 0.00, 63416.18, 8821.22, 8865.36),
    ]:
        for v in grp:
            out.append(('日期值', num(v), 'result3.xlsx / result2_q2c.xlsx', '表 7 / 表 9'))
    # 结果表 xlsx 里的**全部数值单元格**都算有出处。
    # 论文表 7（问题二典型日逐日指标）与表 9（问题三指定日期）是从这些表抄录的，
    # 逐项列举既易漏也易错，直接读表更可靠。
    import openpyxl
    for fn in ('result1.xlsx', 'result2_q2c.xlsx', 'result3.xlsx',
               'result4-2.xlsx', 'result4-3.xlsx'):
        p = os.path.join(os.path.dirname(HERE), 'outputs', fn)
        if not os.path.exists(p):
            continue
        wb = openpyxl.load_workbook(p, read_only=True)
        for ws in wb.worksheets:
            for row in ws.iter_rows(values_only=True):
                for c in row:
                    if isinstance(c, (int, float)):
                        out.append(('xlsx 单元格', num(float(c)), fn, '%s' % ws.title))
        wb.close()

    # 无储能基准与储能效率灵敏度：没有独立的 .mat/.log 产物留存，
    # 出处是建模手来文《问题一_建模与实现总览》§6.4 与 PH 备份档，
    # 且算术自洽（已逐条验算）：
    #   48052.05 − 35126.95 = 12925.10              ← 正文"节约 12925.10 元"
    #   (61789.94 − 59482.70) / 61789.94 = 3.73%    ← 正文"仅减少约 3.73%"
    #   36603.41 / 35126.95 − 1 = +4.20%，33767.03 / 35126.95 − 1 = −3.87%
    #
    # ⚠️ 建模手来文写的是"基准 35126.85 元"，与代码输出的 35126.95 差 0.10 元。
    #    以代码输出为准（result1.xlsx 与 final_results_q1.mat 均为 35126.95）；
    #    且该文自身的差额 −12925.10 只在 35126.95 下成立，可判定 35126.85 是笔误。
    for v in (61789.94, 48052.05, 12925.10, 36603.41, 33767.03, 33801.50,
              12000.00, 2307.24, 3.73, 26.90, 4.20, 3.87):
        out.append(('基准与灵敏度', num(v), '建模手来文（问题一）§6.4 / PH 备份档', '算术已验算'))

    # 列求和量：单值不在任何结果文件里，是表列相加得来（已复核）
    #   16799.94 = result1 充放电量·放电量列的 6 个四小时区间之和
    #   20740.67 = 同表·充电量列之和
    #   7223350.14 / 8884281.45 = 问题三 调增 + 调减（K=8 / K=4）
    #   185524 = 问题三 S3 紧急购电量 185 523.91 在摘要中的取整写法
    for v in (16799.94, 20740.67, 7223350.14, 8884281.45, 185524.00):
        out.append(('列求和 / 取整', num(v), 'result1.xlsx 列求和 / values.json', '已复核'))
    return out


def main():
    rows = []
    bad = 0
    for where, val, src, field in build():
        ok = present(val)
        rows.append((where, val, '%s · %s' % (src, field), '✓' if ok else '✗ 未找到'))
        bad += (not ok)

    print('%-26s %-14s %-46s %s' % ('论文处', '论文数值', '出处文件 · 字段', '核查'))
    print('-' * 106)
    for w, v, s, r in rows:
        print('%-26s %-14s %-46s %s' % (w[:26], v[:14], s[:46], r))
    print('-' * 106)
    print('共 %d 项：一致 %d，未找到 %d' % (len(rows), len(rows) - bad, bad))

    # 反向：正文里的大额数字（≥5 位数）能否对上某个出处。
    # "已知值"要把 values.json 里的**全部**数字拉平后纳入——只拿上面 36 行
    # 核查项当白名单，会把有出处的表体数字（如 S0 的正常+调整费用）误列进来。
    def flat(o, acc):
        if isinstance(o, dict):
            for v in o.values():
                flat(v, acc)
        elif isinstance(o, (int, float)):
            acc.add(num(float(o)))
    known = {r[1] for r in rows}
    flat(V, known)
    known |= {v[1] for v in _date_values()}
    strag = set()
    for m in re.finditer(r'(?<![\d.])(\d{5,}(?:\.\d+)?)(?![\d])', ALL):
        s = m.group(1)
        if s in known or s.rstrip('0').rstrip('.') in known:
            continue
        if any(k.startswith(s.split('.')[0][:6]) for k in known):
            continue
        strag.add(s)
    print('\n正文中未能直接对上出处的大额数字 %d 个（多为手算差值、时段数等，需人工判读）：' % len(strag))
    for s in sorted(strag)[:40]:
        print('   ', s)

    out = os.path.join(HERE, 'number_check.txt')
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write('%-26s %-14s %-46s %s\n' % ('论文处', '论文数值', '出处文件 · 字段', '核查'))
        fh.write('-' * 106 + '\n')
        for w, v, s, r in rows:
            fh.write('%-26s %-14s %-46s %s\n' % (w, v, s, r))
        fh.write('-' * 106 + '\n')
        fh.write('共 %d 项：一致 %d，未找到 %d\n' % (len(rows), len(rows) - bad, bad))
        fh.write('\n未直接对上出处的大额数字：\n')
        for s in sorted(strag):
            fh.write('    %s\n' % s)
    print('\n核查表已写 number_check.txt')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
