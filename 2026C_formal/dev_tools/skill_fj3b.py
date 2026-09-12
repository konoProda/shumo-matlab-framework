# -*- coding: utf-8 -*-
"""附件3 预报 vs 自建预测器：口径统一后的公平对照（仅白天时段）+ 形状偏差修正后的 MAE"""
import openpyxl

wb2 = openpyxl.load_workbook('data/附件/附件2.xlsx', data_only=True)
ws2 = wb2['光伏发电实际功率']
D, T = 365, 144
raw = [[float(ws2.cell(r, c).value) for c in range(2, 2+T)] for r in range(2, 2+D)]
pv = [[raw[0][T-1]] + raw[0][:T-1]] + [[raw[d-1][T-1]] + raw[d-1][:T-1] for d in range(1, D)]
act = [[sum(pv[d][6*h:6*h+6])/6.0 for h in range(24)] for d in range(D)]

wb3 = openpyxl.load_workbook('data/附件/附件3.xlsx', data_only=True)
ws3 = wb3['Sheet1']
f3 = [[[float(ws3.cell(d*4+j+2, c).value or 0) for c in range(3, 27)] for j in range(4)] for d in range(D)]

# ① 日间时段（6:00-19:00）公平对照
K = 4
es, ef = [], []
for d in range(28, D):
    S = [d - 7*(j+1) for j in range(K)]
    for h in range(6, 19):
        p = sum(act[s][h] for s in S)/K
        es.append(abs(p - act[d][h])); ef.append(abs(f3[d][0][h] - act[d][h]))
print('【日间 6:00-19:00 对照】自建K=4 MAE %.1f kW   附件3(0:00发布) MAE %.1f kW   （n=%d）'
      % (sum(es)/len(es), sum(ef)/len(ef), len(es)))
print('  自建K=4 MAE 占该时段均值 %.1f%%；附件3 MAE 占该时段均值 %.1f%%'
      % (100*sum(es)/len(es)/(sum(act[d][h] for d in range(28,D) for h in range(6,19))/(len(es))),
         100*sum(ef)/len(ef)/(sum(act[d][h] for d in range(28,D) for h in range(6,19))/(len(es)))))

# ② 同星期邻近日的固有差异（天气噪声量级）
dd = [abs(act[d][h] - act[d-7][h]) for d in range(28, D) for h in range(6, 19)]
print('\n【固有天气噪声】相邻同星期日的日均绝对差 = %.1f kW（日间），即"完美气候预报"的误差下界' % (sum(dd)/len(dd)))

# ③ 附件3 逐小时偏差（形状偏差）
bias = [0.0]*24
for d in range(D):
    for h in range(24):
        if d + (0) >= 0:
            bias[h] += f3[d][0][h] - act[d][h]
bias = [b/D for b in bias]
print('\n【附件3 逐小时平均偏差（0:00 发布，kW）】')
print('  ' + '  '.join('%2d:%+6.0f' % (h, bias[h]) for h in range(24)))
ec = []
for d in range(28, D):
    for h in range(6, 19):
        ec.append(abs(f3[d][0][h] - bias[h] - act[d][h]))
print('  扣除逐小时平均偏差后的 MAE = %.1f kW（日间）→ 形状偏差贡献了误差的 %.0f%%'
      % (sum(ec)/len(ec), 100*(1 - sum(ec)/len(ec)/(sum(ef)/len(ef)))))
