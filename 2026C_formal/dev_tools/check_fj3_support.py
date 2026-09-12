# -*- coding: utf-8 -*-
"""零支撑集对照：实际光伏 >0 的小时集 与 预报 >0 的小时集 在两种读法下是否吻合"""
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
iss = [(ws3.cell(r, 2).value, [float(ws3.cell(r, c).value or 0) for c in range(3, 27)])
       for r in range(2, ws3.max_row + 1)]

print('【支撑集对照】P(实际>0) 与 P(预报>0) 逐小时（0:00 发布）')
print('%4s %12s %14s %14s' % ('h', 'P(实际>0)', 'P(预报>0)读A', 'P(预报>0)读B'))
for h in range(24):
    pa = sum(1 for d in range(D) if act[d][h] > 0) / D
    fa = sum(1 for d in range(D-1) if iss[d*4][1][h] > 0) / (D-1)          # k=h+1 ↔ 读A
    fb = sum(1 for d in range(1, D) if iss[d*4][1][h-1] > 0) / (D-1)        # k=h   ↔ 读B
    print('%4d %12.3f %14.3f %14.3f' % (h, pa, fa, fb))

print()
print('【日级一致性】每天：实际>0 的小时集 vs 预报>0 的小时集（0:00 发布，定义"日出小时"为首个>0）')
cA = cB = cN = 0
for d in range(D-1):
    asun = next((h for h in range(24) if act[d][h] > 0), None)
    aset = next((h for h in range(23, -1, -1) if act[d][h] > 0), None)
    fy = iss[d*4][1]
    fsun = next((k for k in range(24) if fy[k] > 0), None)
    fset = next((k for k in range(23, -1, -1) if fy[k] > 0), None)
    if None in (asun, aset, fsun, fset):
        cN += 1; continue
    if abs((fsun+1) - asun) <= abs(fsun - asun): cA += 1
    else: cB += 1
    if abs((fsun+1)-asun) != abs(fsun-asun):
        pass
print('  日出时刻：读A 更近 %d 天；读B 更近 %d 天；无法判定 %d 天' % (cA, cB, cN))
