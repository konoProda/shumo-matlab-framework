#!/usr/bin/env python3
# scan_sales_types.py — 附件2 字段取值扫描（销售类型 F 列取值分布、日期 A 列范围）
import zipfile
from datetime import datetime, timedelta
from xml.etree import ElementTree as ET

NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
z = zipfile.ZipFile('2023c/data/附件2.xlsx')

# shared strings
ss = []
root = ET.parse(z.open('xl/sharedStrings.xml')).getroot()
for si in root:
    ss.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS)))

types = {}
dates = {}
n_rows = 0
for event, elem in ET.iterparse(z.open('xl/worksheets/sheet1.xml'), events=('end',)):
    if elem.tag == '{%s}row' % NS:
        cells = {}
        for c in elem.findall('{%s}c' % NS):
            t = c.get('t')
            v = c.find('{%s}v' % NS)
            ref = (c.get('r') or 'A')[0]
            val = ''
            if v is not None:
                val = ss[int(v.text)] if t == 's' else v.text
            cells[ref] = val
        if n_rows > 0:  # 跳过表头
            types[cells.get('F', '')] = types.get(cells.get('F', ''), 0) + 1
            dates[cells.get('A', '')] = dates.get(cells.get('A', ''), 0) + 1
        n_rows += 1
        elem.clear()
z.close()

EPOCH = datetime(1899, 12, 30)
def serial2date(s):
    return (EPOCH + timedelta(days=int(float(s)))).strftime('%Y-%m-%d')

dmin = serial2date(min(dates, key=float))
dmax = serial2date(max(dates, key=float))
print('销售类型(F) 取值分布:', types)
print('日期(A) 不同值个数:', len(dates))
print('日期范围:', dmin, '~', dmax)
print('总数据行数(不含表头):', n_rows - 1)
