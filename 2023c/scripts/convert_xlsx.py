#!/usr/bin/env python3
# convert_xlsx.py — 附件 xlsx → CSV 转换脚本（仅 Python 标准库，流式解析）
# 用途: MATLAB readtable 读取 39MB xlsx 极慢（实测附件3已超6分钟），
#       故由本脚本将附件 1~4 原始数据转换为 CSV，供 MATLAB 主程序读取。
#       （数据通道裁定 Q3-修正2；所有数学处理仍在 MATLAB 内完成）
# 用法: python3 convert_xlsx.py <PROJ_ROOT>
# 产物: <PROJ_ROOT>/outputs/raw_附件1.csv / raw_附件2.csv / raw_附件3.csv
#                     / raw_附件4_单品.csv / raw_附件4_小分类.csv
import zipfile
import sys
import csv
import os
from xml.etree import ElementTree as ET

NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
REL_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'


def load_shared_strings(z):
    """读取 xlsx 共享字符串表（'单品名称'等文本字段的存储方式）"""
    if 'xl/sharedStrings.xml' not in z.namelist():
        return []
    root = ET.parse(z.open('xl/sharedStrings.xml')).getroot()
    return [''.join(t.text or '' for t in si.iter('{%s}t' % NS)) for si in root]


def sheet_to_csv(z, sheet_path, out_csv, ss):
    """流式解析单个 sheet，写入 CSV；列序以表头为准，缺失单元格补空串"""
    header_cols = None
    n = 0
    with open(out_csv, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        for event, elem in ET.iterparse(z.open(sheet_path), events=('end',)):
            if elem.tag != '{%s}row' % NS:
                continue
            cells = {}
            for c in elem.findall('{%s}c' % NS):
                ref = c.get('r') or ''
                col = ''.join(ch for ch in ref if ch.isalpha())
                t = c.get('t')
                v = c.find('{%s}v' % NS)
                val = ''
                if v is not None:
                    val = ss[int(v.text)] if t == 's' else v.text
                cells[col] = val
            elem.clear()
            if not cells:
                continue
            if header_cols is None:
                header_cols = sorted(cells, key=lambda x: (len(x), x))
            w.writerow([cells.get(c, '') for c in header_cols])
            n += 1
    return n


def main():
    proj_root = sys.argv[1] if len(sys.argv) > 1 else '..'
    data_dir = os.path.join(proj_root, 'data')
    out_dir = os.path.join(proj_root, 'outputs')
    os.makedirs(out_dir, exist_ok=True)

    # 附件 1~3: 单 sheet
    jobs = [
        ('附件1.xlsx', 'xl/worksheets/sheet1.xml', 'raw_附件1.csv'),
        ('附件2.xlsx', 'xl/worksheets/sheet1.xml', 'raw_附件2.csv'),
        ('附件3.xlsx', 'xl/worksheets/sheet1.xml', 'raw_附件3.csv'),
    ]
    for fname, sheet_path, out_name in jobs:
        print('converting %s ...' % fname, flush=True)
        z = zipfile.ZipFile(os.path.join(data_dir, fname))
        ss = load_shared_strings(z)
        n = sheet_to_csv(z, sheet_path, os.path.join(out_dir, out_name), ss)
        z.close()
        print('  -> %s  (%d 行)' % (out_name, n), flush=True)

    # 附件 4: 两个 sheet（sheet1=小分类损耗率, Sheet1=单品损耗率）
    z = zipfile.ZipFile(os.path.join(data_dir, '附件4.xlsx'))
    ss = load_shared_strings(z)
    wb = ET.parse(z.open('xl/workbook.xml')).getroot()
    rels = ET.parse(z.open('xl/_rels/workbook.xml.rels')).getroot()
    relmap = {r.get('Id'): r.get('Target') for r in rels}
    for s in wb.find('{%s}sheets' % NS):
        name = s.get('name')
        target = relmap.get(s.get('{%s}id' % REL_NS), '')
        if not target.startswith('xl/'):
            target = 'xl/' + target.lstrip('/')
        out_name = 'raw_附件4_单品.csv' if name == 'Sheet1' else 'raw_附件4_小分类.csv'
        n = sheet_to_csv(z, target, os.path.join(out_dir, out_name), ss)
        print('附件4 sheet "%s" -> %s  (%d 行)' % (name, out_name, n), flush=True)
    z.close()
    print('all done', flush=True)


if __name__ == '__main__':
    main()
