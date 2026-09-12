# -*- coding: utf-8 -*-
"""附件3 与 附件2 实际光伏的对齐交叉验证（钉死"预报k小时"的时间归属）"""
import openpyxl, datetime

# ---- 读附件2 实际光伏，按已定时间轴口径铺成全年逐槽序列 ----
wb2 = openpyxl.load_workbook('data/附件/附件2.xlsx', data_only=True)
ws2 = wb2['光伏发电实际功率']
D = ws2.max_row - 1                      # 365
T = 144
raw = [[float(ws2.cell(r, c).value) for c in range(2, 2+T)] for r in range(2, 2+D)]
# 列标签为时段起始，末列 0:00+1 属次日首槽 → 第 d 天首槽取第 d-1 天末列
pv = [[raw[d-1][T-1]] + raw[d-1][:T-1] if d >= 1 else raw[0] for d in range(D)]
pv[0] = [raw[0][T-1]] + raw[0][:T-1]     # 第1天无前一日，取本日末列

# 逐小时均值：第 d 天 h 时段 = 槽 6h-5 .. 6h
act_hour = {}
for d in range(D):
    for h in range(24):
        act_hour[(d, h)] = sum(pv[d][6*h:6*h+6]) / 6.0

# ---- 读附件3 ----
wb3 = openpyxl.load_workbook('data/附件/附件3.xlsx', data_only=True)
ws3 = wb3['Sheet1']
issues = []
tmap = {'0:00': 0, '6:00': 6, '12:00': 12, '18:00': 18}
for r in range(2, ws3.max_row + 1):
    lab = ws3.cell(r, 2).value
    fy = [ws3.cell(r, c).value for c in range(3, 27)]
    issues.append((lab, [float(v) if v is not None else 0.0 for v in fy]))
assert len(issues) == 4 * D

# ---- 两种读法下的相关度 ----
def series(reading):
    """reading='A': 预报k小时 ↔ [τ+(k-1)h, τ+kh)；'B': ↔ [τ+kh, τ+(k+1)h)"""
    off = 0 if reading == 'A' else 1
    xs, ys = [], []
    for i, (lab, fy) in enumerate(issues):
        # k=1..24 对应的小时序号（0 起，跨日取模）
        for k in range(1, 25):
            hh = tmap[lab] + (k - 1) + off
            d = i // 4 + hh // 24
            h = hh % 24
            if d < D:
                xs.append(fy[k-1]); ys.append(act_hour[(d, h)])
    n = len(xs)
    mx, my = sum(xs)/n, sum(ys)/n
    sxy = sum((a-mx)*(b-my) for a, b in zip(xs, ys))
    sxx = sum((a-mx)**2 for a in xs); syy = sum((b-my)**2 for b in ys)
    mae = sum(abs(a-b) for a, b in zip(xs, ys))/n
    return sxy/(sxx*syy)**0.5, mae, n

for rd in ('A', 'B'):
    c, mae, n = series(rd)
    print('读法 %s：corr = %.4f   MAE = %8.1f kW   （n = %d 组）' % (rd, c, mae, n))
