# -*- coding: utf-8 -*-
"""附件3 汇总校验（结构/完整性/非数值文本扫描/取值范围），供 preprocess_log_q3 引用"""
import openpyxl, datetime, collections

wb = openpyxl.load_workbook('data/附件/附件3.xlsx', data_only=True)
ws = wb['Sheet1']
hdr = [ws.cell(1, c).value for c in range(1, ws.max_column + 1)]
print('维度: %d 行 × %d 列' % (ws.max_row, ws.max_column))
print('表头: %r / %r / %r ... %r' % (hdr[0], hdr[1], hdr[2], hdr[24]))
assert hdr[2:] == ['预报%d小时' % k for k in range(1, 25)]

times = ['0:00', '6:00', '12:00', '18:00']
miss = 0; text = collections.Counter(); vals = []
days = []
for r in range(2, ws.max_row + 1):
    b = ws.cell(r, 2).value
    if b not in times: print('  异常预报时刻 行%d: %r' % (r, b))
    for c in range(3, 27):
        v = ws.cell(r, c).value
        if v is None: miss += 1
        elif isinstance(v, (int, float)): vals.append(float(v))
        else: text[repr(v)] += 1
    if ws.cell(r, 1).value not in (None, ''):
        days.append(ws.cell(r, 1).value)

print('数据行数: %d = 365 天 × 4 发布时刻 -> %s' % (ws.max_row - 1, (ws.max_row - 1) == 1460))
print('日期单元格数: %d（仅每日 0:00 行）' % len(days))
d0 = [datetime.datetime.strptime(str(x).strip(), '%Y-%m-%d').date() if not isinstance(x, datetime.datetime) else x.date() for x in days]
print('日期范围: %s .. %s  连续: %s' % (d0[0], d0[-1], all((d0[i+1]-d0[i]).days == 1 for i in range(len(d0)-1))))
print('缺失单元: %d   非数值文本单元: %d %s' % (miss, sum(text.values()), dict(text) if text else ''))
print('取值范围: %.4f .. %.1f   负值 %d 个' % (min(vals), max(vals), sum(1 for v in vals if v < 0)))
night = []
for d in range(365):
    for j in range(4):
        for c in (3, 4, 5):          # 预报 1~3 小时（发布时刻后 0~3 小时的区间）
            night.append(ws.cell(d*4 + j + 2, c).value or 0)
print('夜间区间(各发布时刻的预报1~3小时)全零检查: 最大 %.4f kW' % max(night))
