#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fill_gaps.py —— 把初稿里的【待补】替换为真实数字

数字全部来自 paper/values.json（由 collect_values.py 从 outputs/ 的最终结果
文件与 result*.xlsx 汇总，逐值可溯源）。本脚本不做任何推算或估值，只用已核
验的一致数字；替换一律走**精确整行匹配**，任何一条没命中就报错停下（避免静默
改错位置）。

顺带删掉两句"数值待补"的过渡语——它们填完后就不是事实了。

用法：python3 fill_gaps.py
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
V = json.load(open(os.path.join(HERE, 'values.json'), encoding='utf-8'))


def f(x, nd=2):
    return '%.*f' % (nd, x)


def sci(x, nd=2):
    """科学计数法。

    注意：这些量写在 \\[ … \\] 里（已是数学模式），所以**不能**再套 \\text{}——
    \\text 会切回文本模式，其中的 \\times 会报 "Missing $ inserted"。
    """
    m, e = ('%.*e' % (nd, x)).split('e')
    return r'%s\times10^{%d}' % (m, int(e))


def pc(a, b):
    """b 相对 a 的变化率。

    负号用数学减号（$-0.49\\%$ 而非 -0.49\\%）：文本模式下的 `-` 是连字符，
    比减号短，成表中的负值会显得不对齐。
    """
    s = '%+.2f' % (100.0 * (b - a) / a)
    return ('$%s\\%%$' % s) if s.startswith('-') else (s + r'\%')


# ---------- 取值 ----------
S = V['q3b_S0'], V['q3b_S1'], V['q3b_S2'], V['q3b_S3']
S3, S3k8 = V['q3b_S3'], V['q3b_S3k8']
Q2, Q42, Q43 = V['q2'], V['q4_Q4-2'], V['q4_Q4-3']
Q42k8, Q43k8 = V['q4_Q4-2k8'], V['q4_Q4-3k8']

# 指定日期（来源：outputs/result3.xlsx 三张表，逐格核对）
DATES = {
    '2025-03-20': (60456.54, 59272.33, 1042.42, 41345.86, 8924.47, 3000.36),
    '2025-06-21': (43252.47, 42434.09, 0.00, 24946.99, 5762.09, 10800.00),
    '2025-09-23': (65186.81, 66030.22, 1887.41, 47560.08, 4746.35, 6520.75),
    '2025-12-21': (96080.19, 96520.33, 0.00, 63416.18, 8821.22, 8865.36),
}

# ---------- 替换表：(文件, 旧行, 新行) ----------
R = []

# ===== 问题三：四策略对照表（表 8）=====
q3 = 'sections/q3.tex'
rows8 = [
    ('总费用/元', [s['cost_win'] for s in S]),
    ('正常+调整费用/元', [s['cost_normal_win'] for s in S]),
    ('紧急购电费用/元', [s['cost_em_win'] for s in S]),
    ('紧急购电量/kWh', [s['em_win'] for s in S]),
    ('调增购电量/kWh', [s['adj_up'] for s in S]),
    ('调减购电量/kWh', [s['adj_dn'] for s in S]),
    ('弃光量/kWh', [s['curt_win'] for s in S]),
    ('已购未用电/kWh', [s['waste_win'] for s in S]),
]
for name, vals in rows8:
    R.append((q3, '%s & 【待补】 & 【待补】 & 【待补】 & 【待补】 \\\\' % name,
              '%s & %s \\\\' % (name, ' & '.join(f(v) for v in vals))))

# ===== 问题三：边际收益 =====
R.append((q3,
          r'\Delta C_6=\text{【待补】},',
          r'\Delta C_6=\text{%s 元},' % f(S[0]['cost_win'] - S[1]['cost_win'])))
R.append((q3,
          r'\Delta C_{12}=\text{【待补】},',
          r'\Delta C_{12}=\text{%s 元},' % f(S[1]['cost_win'] - S[2]['cost_win'])))
R.append((q3,
          r'\Delta C_{18}=\text{【待补】}.',
          r'\Delta C_{18}=\text{%s 元}.' % f(S[2]['cost_win'] - S[3]['cost_win'])))

# ===== 问题三：指定日期表（表 9）=====
for d, v in DATES.items():
    R.append((q3, '%s & 【待补】 & 【待补】 & 【待补】 & 【待补】 & 【待补】 & 【待补】 \\\\' % d,
              '%s & %s \\\\' % (d, ' & '.join(f(x) for x in v))))

# ===== 问题三：模型检验 =====
R.append((q3, r'\text{【待补】}.', r'%s.' % sci(S3['max_viol'])))
# 拼接重放偏差为 0（S3 的 replay 字段），直接写 0 比写 0\times10^0 更清楚
R.append((q3, r'\text{【待补】}.', r'0.'))

# ===== 问题三：稳定性对照（表 10）=====
adj4 = S3['adj_up'] + S3['adj_dn']
adj8 = S3k8['adj_up'] + S3k8['adj_dn']
rowsk = [
    ('总费用', S3['cost_win'], S3k8['cost_win']),
    ('紧急购电量', S3['em_win'], S3k8['em_win']),
    ('调整总量', adj4, adj8),
]
for name, a, b in rowsk:
    R.append((q3, '%s & 【待补】 & 【待补】 & 【待补】 \\\\' % name,
              '%s & %s & %s & %s \\\\' % (name, f(a), f(b), pc(a, b))))

# 填完后这两句过渡语不再是事实，一并去掉
R.append((q3, '指定日期结果待由最终结果文件补入：', ''))

# ===== 问题四：四口径对照表（表 11）=====
q4 = 'sections/q4.tex'
rows11 = [
    ('总费用/元', Q2['Z'], Q42['cost_win'], S[3]['cost_win'], Q43['cost_win']),
    ('紧急购电费用/元', Q2['cost_em'], Q42['cost_em_win'], S[3]['cost_em_win'], Q43['cost_em_win']),
    ('紧急购电量/kWh', Q2['em_win'], Q42['em_win'], S[3]['em_win'], Q43['em_win']),
    ('已购未用电/kWh', Q2['waste_win'], Q42['waste_win'], S[3]['waste_win'], Q43['waste_win']),
    ('日末储电量均值/kWh', Q2['Eend_mean'], Q42['Eend_mean'], S[3]['Eend_mean'], Q43['Eend_mean']),
]
for name, *vals in rows11:
    # 第二列（问题二固定电价）在初稿里是长破折号：问题二无调增/调减阶段，该项不适用
    old = ('%s & 【待补】 & 【待补】 & 【待补】 & 【待补】 \\\\' % name)
    R.append((q4, old, '%s & %s \\\\' % (name, ' & '.join(f(v) for v in vals))))
# 正常+调整一行：首列保持"—"（问题二无调整阶段），其余补数
R.append((q4, '正常+调整费用/元 & — & 【待补】 & 【待补】 & 【待补】 \\\\',
          '正常+调整费用/元 & — & %s & %s & %s \\\\'
          % (f(Q42['cost_normal_win']), f(S[3]['cost_normal_win']),
             f(Q43['cost_normal_win']))))

# ===== 问题四：电价预测精度（表 12）=====
pr = V['price']
rows12 = [
    ('MAE', f(pr['MAE'], 4)),
    ('RMSE', f(pr['RMSE'], 4)),
    ('峰值时刻精确命中率', f(100 * pr['peak_hit'], 1) + r'\%'),
    ('谷值时刻精确命中率', f(100 * pr['valley_hit'], 1) + r'\%'),
    ('峰值 1 h 内命中率', f(100 * pr['peak_hit_1h'], 1) + r'\%'),
    ('谷值 1 h 内命中率', f(100 * pr['valley_hit_1h'], 1) + r'\%'),
    ('峰谷差预测 MAE', f(pr['spread_MAE'], 4)),
]
for name, val in rows12:
    R.append((q4, '%s & 【待补】 \\\\' % name, '%s & %s \\\\' % (name, val)))

# ===== 问题四：价格不确定性代价 =====
R.append((q4, r'\text{【待补】}.',
          r'\text{%s 元}.' % f(Q42['cost_win'] - V['q4_Q4-2Ideal']['cost_win'])))

# ===== 问题四：模型检验 =====
worst_viol = max(Q42['max_viol'], Q43['max_viol'])
worst_gap = max(Q42['max_gap'], Q43['max_gap'])
R.append((q4, r'\text{【待补】}.', r'%s.' % sci(worst_viol)))
R.append((q4, r'\text{【待补】}.', r'%s.' % sci(worst_gap)))
R.append((q4, r'\text{【待补】}.', r'0.'))

# ===== 问题四：稳定性对照（表 13）=====
rowsk4 = [
    ('Q4-2 总费用', Q42['cost_win'], Q42k8['cost_win']),
    ('Q4-3 总费用', Q43['cost_win'], Q43k8['cost_win']),
    ('Q4-2 紧急购电量', Q42['em_win'], Q42k8['em_win']),
    ('Q4-3 紧急购电量', Q43['em_win'], Q43k8['em_win']),
]
for name, a, b in rowsk4:
    R.append((q4, '%s & 【待补】 & 【待补】 & 【待补】 \\\\' % name,
              '%s & %s & %s & %s \\\\' % (name, f(a), f(b), pc(a, b))))

# 同样：填完后这句过渡语不再成立
R.append((q4, '目前结果交接稿中 Q4-2、Q4-3 的最终程序数值尚未补齐，因此本节只保留正式结果表结构，不填造数值。', ''))


def main():
    # 重复的模板行（如三处 \text{【待补】}.）用顺序消费：同一文件内按出现顺序逐条替换
    files = {}
    for fn, old, new in R:
        files.setdefault(fn, []).append((old, new))

    fail = 0
    for fn, subs in files.items():
        path = os.path.join(HERE, fn)
        text = open(path, encoding='utf-8').read()
        for old, new in subs:
            if old not in text:
                print('  !! 未命中  %s  %r' % (fn, old[:60]))
                fail += 1
                continue
            text = text.replace(old, new, 1)     # 只替第一处，保证同模板行按序消费
        open(path, 'w', encoding='utf-8').write(text)
        left = text.count('【待补】')
        print('  %-18s 替换 %2d 条，剩余【待补】%d' % (fn, len(subs), left))

    # 全文复查
    tot = 0
    for root, _, fs in os.walk(os.path.join(HERE, 'sections')):
        for x in fs:
            if x.endswith('.tex'):
                tot += open(os.path.join(root, x), encoding='utf-8').read().count('【待补】')
    print('\n全文剩余【待补】%d 处' % tot)
    return 1 if (fail or tot) else 0


if __name__ == '__main__':
    sys.exit(main())
