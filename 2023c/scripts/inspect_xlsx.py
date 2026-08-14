#!/usr/bin/env python3
# inspect_xlsx.py — 附件 xlsx 结构检查脚本（/prep 数据格式校验用，仅标准库）
# 输出各附件 sheet 清单、尺寸、前几行内容、总行数
import zipfile
import sys
from xml.etree import ElementTree as ET

NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
REL_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'


def load_shared_strings(z):
    if 'xl/sharedStrings.xml' not in z.namelist():
        return []
    root = ET.parse(z.open('xl/sharedStrings.xml')).getroot()
    ss = []
    for si in root:
        text = ''.join(t.text or '' for t in si.iter('{%s}t' % NS))
        ss.append(text)
    return ss


def dump_sheet(z, sheetname, ss, max_rows=8, max_cols=12):
    total = 0
    dim = None
    for event, elem in ET.iterparse(z.open(sheetname), events=('start', 'end')):
        if event == 'start' and elem.tag == '{%s}dimension' % NS:
            dim = elem.get('ref')
        if event == 'end' and elem.tag == '{%s}row' % NS:
            total += 1
            if total <= max_rows:
                vals = []
                for c in elem.findall('{%s}c' % NS):
                    t = c.get('t')
                    v = c.find('{%s}v' % NS)
                    val = ''
                    if v is not None:
                        val = ss[int(v.text)] if t == 's' else v.text
                    vals.append('%s=%s' % (c.get('r'), val))
                print('  row %d : %s' % (total, '; '.join(vals[:max_cols])))
            elem.clear()
    print('  dimension: %s, total rows: %d' % (dim, total))


for fname in sys.argv[1:]:
    path = '2023c/data/' + fname
    print('===== %s =====' % fname)
    z = zipfile.ZipFile(path)
    wb = ET.parse(z.open('xl/workbook.xml')).getroot()
    sheet_els = wb.find('{%s}sheets' % NS)
    rels = ET.parse(z.open('xl/_rels/workbook.xml.rels')).getroot()
    relmap = {r.get('Id'): r.get('Target') for r in rels}
    for s in sheet_els:
        name = s.get('name')
        target = relmap.get(s.get('{%s}id' % REL_NS), '')
        if not target.startswith('xl/'):
            target = 'xl/' + target.lstrip('/')
        print('-- sheet: %s (%s) --' % (name, target))
        ss = load_shared_strings(z)
        dump_sheet(z, target, ss)
    z.close()
