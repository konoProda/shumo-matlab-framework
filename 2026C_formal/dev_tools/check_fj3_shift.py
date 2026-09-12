# -*- coding: utf-8 -*-
"""附件3 时间归属：小时移位扫描 + 日出/日落跃变时刻配对"""
import openpyxl

wb2 = openpyxl.load_workbook('data/附件/附件2.xlsx', data_only=True)
ws2 = wb2['光伏发电实际功率']
D, T = 365, 144
raw = [[float(ws2.cell(r, c).value) for c in range(2, 2+T)] for r in range(2, 2+D)]
pv = [[raw[0][T-1]] + raw[0][:T-1]] + [[raw[d-1][T-1]] + raw[d-1][:T-1] for d in range(1, D)]
act = [[sum(pv[d][6*h:6*h+6])/6.0 for h in range(24)] for d in range(D)]

wb3 = openpyxl.load_workbook('data/附件/附件3.xlsx', data_only=True)
ws3 = wb3['Sheet1']
tmap = {'0:00': 0, '6:00': 6, '12:00': 12, '18:00': 18}
iss = []
for r in range(2, ws3.max_row + 1):
    fy = [ws3.cell(r, c).value or 0.0 for c in range(3, 27)]
    iss.append((ws3.cell(r, 2).value, [float(v) for v in fy]))

def pair(s, only=None):
    xs, ys = [], []
    for i, (lab, fy) in enumerate(iss):
        if only is not None and lab != only: continue
        for k in range(1, 25):
            hh = tmap[lab] + (k-1) + s
            d, h = i//4 + hh//24, hh % 24
            if d < D:
                xs.append(fy[k-1]); ys.append(act[d][h])
    return xs, ys

print('=== 逐小时移位扫描（全体：+ 分发布时刻）===')
for s in (-2, -1, 0, 1, 2):
    xs, ys = pair(s)
    n = len(xs); mx = sum(xs)/n; my = sum(ys)/n
    c = sum((a-mx)*(b-my) for a, b in zip(xs, ys)) / (sum((a-mx)**2 for a in xs)*sum((b-my)**2 for b in ys))**0.5
    mae = sum(abs(a-b) for a, b in zip(xs, ys))/n
    print('  移位 %+d h：corr %.4f  MAE %7.1f' % (s, c, mae))
print()
for lab in ['0:00', '6:00', '12:00', '18:00']:
    row = []
    for s in (-1, 0, 1):
        xs, ys = pair(s, lab)
        n = len(xs)
        mae = sum(abs(a-b) for a, b in zip(xs, ys))/n
        row.append('s=%+d MAE %6.1f' % (s, mae))
    print('  发布 %-5s  ' % lab, '   '.join(row), ' （n=%d/组）' % (len(pair(0, lab)[0])))

print()
print('=== 日出跃变时刻配对（阈值 50 kW，仅 0:00 与 6:00 发布）===')
from collections import Counter
for lab in ['0:00', '6:00']:
    cnt = Counter()
    for i, (l2, fy) in enumerate(iss):
        if l2 != lab: continue
        d = i//4
        fs = [k for k in range(1, 25) if fy[k-1] > 50]
        as_ = [h for h in range(24) if act[d][h] > 50]
        if fs and as_:
            cnt[(fs[0]) - (as_[0])] += 1     # 预报第 k 个 >50 的 k 与 实际首个 >50 的小时序号之差
    tot = sum(cnt.values())
    top = ', '.join('%+d:%.0f%%' % (k, 100*v/tot) for k, v in sorted(cnt.items()))
    print('  发布 %-5s  k首滞后-小时首 的分布：%s   (n=%d)' % (lab, top, tot))
