#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_docx.py —— 把纯文本说明转成交付用的 .docx

用法：python3 make_docx.py <输入.txt> <输出.docx> <标题>

输入文本约定：以 '#' 开头的行为小标题，其余非空行为正文段落。
按交付规范，正文为自然段落，只写清三件事：算的是什么 / 按什么思路实现 / 得到什么结果；
不出现运行入口、命令行、目录树。

排版要求（交付统一）：**全部文字宋体、颜色纯黑**。

为什么需要专门处理颜色：Word 内置的 Heading 样式用的是主题色
（accent1 → 4F81BD 蓝等），python-docx 默认沿用，生成的 docx 里标题就是蓝的。
所以这里对 Normal 与各级 Heading 样式、以及每个 run 都显式写入
「宋体 + 000000」，并清掉 color 上的 themeColor 引用，确保不受主题影响。
"""
import sys

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

FONT = '宋体'
BLACK = '000000'
STYLES = ['Normal', 'Heading 1', 'Heading 2', 'Heading 3', 'Title']


def force_font_and_color(rPr):
    """把一段 rPr 的字体改成宋体、颜色改成纯黑，并去掉主题色引用。"""
    if rPr is None:
        return
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.insert(0, rFonts)
    for a in ('w:ascii', 'w:hAnsi', 'w:eastAsia', 'w:cs'):
        rFonts.set(qn(a), FONT)

    color = rPr.find(qn('w:color'))
    if color is None:
        color = OxmlElement('w:color')
        rPr.append(color)
    color.set(qn('w:val'), BLACK)
    for a in ('w:themeColor', 'w:themeTint', 'w:themeShade'):
        if color.get(qn(a)) is not None:
            del color.attrib[qn(a)]


def set_doc_fonts(doc, size=Pt(12)):
    """文档级：默认字体、各内置样式，全部置为宋体 + 纯黑。"""
    # docDefaults（styles.xml 的根默认，优先级最低但覆盖最广）
    try:
        dd = doc.styles.element.find(qn('w:docDefaults'))
        if dd is not None:
            rpr = dd.find(qn('w:rPrDefault'))
            if rpr is not None:
                force_font_and_color(rpr.find(qn('w:rPr')))
    except Exception:
        pass

    for name in STYLES:
        try:
            st = doc.styles[name]
        except KeyError:
            continue
        st.font.name = FONT
        st.font.color.rgb = RGBColor(0, 0, 0)
        if name == 'Normal':
            st.font.size = size
        rPr = st.element.get_or_add_rPr()
        force_font_and_color(rPr)


def neutralize_theme_zip(path):
    """把 docx 包内 styles.xml 与 theme1.xml 的**文字**字体颜色统一为宋体纯黑。

    用 XML 解析而非正则改写：正则拼属性会写出重复的 w:hAnsi，产出非法 XML，
    Word 直接打不开（本轮踩过）。

    只动"字色"，不动"底色"：主题里的 <a:sysClr .../> 是窗口背景色（白），
    一并改黑会导致整页黑底。
    """
    import shutil
    import zipfile

    from lxml import etree

    W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    A = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    NS = {'w': W, 'a': A}

    def fix_styles(data):
        root = etree.fromstring(data)
        for rf in root.iter('{%s}rFonts' % W):
            for a in ('ascii', 'hAnsi', 'eastAsia', 'cs'):
                rf.set('{%s}%s' % (W, a), FONT)
        for c in root.iter('{%s}color' % W):
            c.set('{%s}val' % W, BLACK)
            for a in ('themeColor', 'themeTint', 'themeShade'):
                k = '{%s}%s' % (W, a)
                if k in c.attrib:
                    del c.attrib[k]
        return etree.tostring(root, xml_declaration=True,
                              encoding='UTF-8', standalone=True)

    def fix_theme(data):
        root = etree.fromstring(data)
        for c in root.iter('{%s}srgbClr' % A):      # 只改 srgbClr（前景/强调色）
            c.set('val', BLACK)
        return etree.tostring(root, xml_declaration=True,
                              encoding='UTF-8', standalone=True)

    tmp = path + '.tmp'
    with zipfile.ZipFile(path) as zin, \
            zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/styles.xml':
                data = fix_styles(data)
            elif item.filename == 'word/theme/theme1.xml':
                data = fix_theme(data)
            zout.writestr(item, data)
    shutil.move(tmp, path)


def main():
    src, dst, title = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(src, encoding='utf-8') as f:
        lines = [ln.rstrip() for ln in f]

    doc = Document()
    set_doc_fonts(doc)
    for s in doc.sections:
        s.left_margin = s.right_margin = Cm(2.6)

    h = doc.add_heading(title, level=1)
    for ln in lines:
        t = ln.strip()
        if not t:
            continue
        if t.startswith('#'):
            doc.add_heading(t.lstrip('#').strip(), level=2)
        else:
            doc.add_paragraph(t)

    # 兜底：逐个 run 再写一遍，任何继承来的字体/颜色都被覆盖
    for p in doc.paragraphs:
        force_font_and_color(p._p.get_or_add_pPr().find(qn('w:rPr')))
        for r in p.runs:
            r.font.name = FONT
            r.font.color.rgb = RGBColor(0, 0, 0)
            force_font_and_color(r._element.get_or_add_rPr())

    doc.save(dst)
    neutralize_theme_zip(dst)
    print(f'已生成 {dst}')


if __name__ == '__main__':
    main()
