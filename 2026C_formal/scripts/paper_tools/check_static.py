#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_static.py —— 论文 LaTeX 源码静态自检（L0–L7）

本机没有 TeX 引擎，编译期才暴露的问题查不到（清单见 README），
但凡能静态查的都在这里查完：编码、配对、计数不变式、文本模式危险字符、
规范合规、Markdown 残留、引用与浮动体、附录代码。

用法：python3 check_static.py            # 输出到 stdout 并写 check_report.txt
返回码：0 = 全绿；1 = 有 FAIL
"""
import glob
import os
import re
import sys

# 本脚本在 scripts/paper_tools/ 下，产物一律写回 ../../paper/
PAPER = os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), 'paper')
HERE = os.path.dirname(os.path.abspath(__file__))   # 报告只落在工具目录
SECT = os.path.join(PAPER, 'sections')
TAB = os.path.join(PAPER, 'tables')
CODE = os.path.join(PAPER, 'code')

# 计数不变式（改稿后应同步更新这里的期望值）
N_EQUATION = 52
N_FIG = 11                     # 10 张结果图 + 1 张总体流程图
N_TAB = 31
N_SUB = 2                     # 附录 B/C 的 \subsection 数（不计 code_manifest 内的）

R = []                        # (层, 项, 结果, 说明)


def rec(lv, item, ok, note=''):
    R.append((lv, item, 'PASS' if ok else 'FAIL', note))
    return ok


def files(pattern, root):
    return sorted(glob.glob(os.path.join(root, pattern)))


def strip_comments(text):
    """按行去注释。

    strip_comment 是**单行**语义；若直接对整篇文本调用，它会在全文第一个 % 处
    截断，后面的内容全部丢失——L1 的环境栈与花括号检查曾因此只检查了前几行。
    """
    return '\n'.join(strip_comment(x) for x in text.split('\n'))


def strip_comment(line):
    """去掉 LaTeX 注释，但保留 \\% 转义。注意：参数必须是**一行**。"""
    out, i = [], 0
    while i < len(line):
        if line[i] == '\\' and i + 1 < len(line):
            out.append(line[i:i + 2]); i += 2; continue
        if line[i] == '%':
            break
        out.append(line[i]); i += 1
    return ''.join(out)


def main():
    tex_main = os.path.join(PAPER, 'main.tex')
    all_tex = [tex_main] + files('*.tex', SECT) + files('*.tex', TAB)
    body = {os.path.basename(p): open(p, encoding='utf-8').read() for p in all_tex}
    print('自检 %d 个 .tex 文件\n' % len(all_tex))

    # ---------------- L0 编码 ----------------
    bad = []
    for p in all_tex:
        raw = open(p, 'rb').read()
        if raw.startswith(b'\xef\xbb\xbf'):
            bad.append(os.path.basename(p) + ':BOM')
        if b'\r\n' in raw:
            bad.append(os.path.basename(p) + ':CRLF')
        try:
            raw.decode('utf-8')
        except UnicodeDecodeError:
            bad.append(os.path.basename(p) + ':非UTF-8')
        # 控制字符（保留 \n \t）
        for ch in set(raw):
            if ch < 9 or (13 < ch < 32):
                bad.append('%s:控制字符 0x%02x' % (os.path.basename(p), ch))
                break
    rec('L0', '编码（BOM / CRLF / UTF-8 / 控制字符）', not bad, '; '.join(bad[:5]))

    # ---------------- L1 配对 ----------------
    issues = []
    for name, t in body.items():
        # 花括号
        d = 0
        for ch in strip_comments(t):
            if ch == '{':
                d += 1
            elif ch == '}':
                d -= 1
                if d < 0:
                    break
        if d != 0:
            issues.append('%s:花括号差 %d' % (name, d))
        # 行间公式
        # \\[1mm] 是换行加空距，不是行间公式定界符，须排除
        if len(re.findall(r'(?<!\\)\\\[', t)) != len(re.findall(r'(?<!\\)\\\]', t)):
            issues.append('%s:\\[ \\] 不等 (%d/%d)' % (name, t.count(r'\['), t.count(r'\]')))
        if t.count(r'\(') != t.count(r'\)'):
            issues.append('%s:\\( \\) 不等' % (name,))
        # 环境栈
        st = []
        for m in re.finditer(r'\\(begin|end)\{([^}]+)\}', strip_comments(t)):
            if m.group(1) == 'begin':
                st.append(m.group(2))
            else:
                if not st:
                    issues.append('%s:\\end{%s} 多余' % (name, m.group(2))); break
                if st[-1] != m.group(2):
                    issues.append('%s:\\end{%s} 与 \\begin{%s} 不匹配' % (name, m.group(2), st[-1])); break
                st.pop()
        if st:
            issues.append('%s:未闭合环境 %s' % (name, st))
        # \left / \right
        if len(re.findall(r'\\left(?![a-zA-Z])', t)) != len(re.findall(r'\\right(?![a-zA-Z])', t)):
            issues.append('%s:\\left/\\right 不等' % name)
    rec('L1', '配对（花括号 / \\[ \\] / 环境栈 / \\left\\right）', not issues,
        '; '.join(issues[:4]))

    # ---------------- L2 计数不变式 ----------------
    j = '\n'.join(body.values())
    n_eq = j.count(r'\begin{equation}')
    # 表格体总数 = 普通 tabular + longtable。
    # 横版强制表页里是**裸 tabular**（landscape 页即容器，不再套 table 浮动体），
    # 因此不能用"table 环境数 == tabular 数"当不变式，直接核对表格体总数。
    n_tab_env = j.count(r'\begin{tabular}') + j.count(r'\begin{longtable}')
    n_tabular = n_tab_env
    n_fig = j.count(r'\includegraphics')
    n_inc = n_eq and None
    checks = [
        ('equation == %d' % N_EQUATION, n_eq == N_EQUATION, '实际 %d' % n_eq),
        ('table 环境 + longtable + 横版裸 tabular 总数', n_tab_env == n_tabular, '%d / %d' % (n_tab_env, n_tabular)),
        ('表格体总数 == %d' % N_TAB, n_tab_env == N_TAB, '实际 %d' % n_tab_env),
        ('includegraphics == %d' % N_FIG, n_fig == N_FIG, '实际 %d' % n_fig),
        ('\\tag 残留 == 0', j.count(r'\tag{') == 0, '实际 %d' % j.count(r'\tag{')),
        ('$$ 残留 == 0', j.count('$$') == 0, '实际 %d' % j.count('$$')),
        ('\\[ == \\]（排除 \\\\[ 换行）',
         len(re.findall(r'(?<!\\)\\\[', j)) == len(re.findall(r'(?<!\\)\\\]', j)),
         '%d / %d' % (len(re.findall(r'(?<!\\)\\\[', j)), len(re.findall(r'(?<!\\)\\\]', j)))),
    ]
    # 行内 $ 必须成对。少一个会让后面整段变成数学模式，错得很远，
    # 编译信息常常指不到真正的位置。
    for name, t in body.items():
        n = 0
        for ln in strip_comments(t).split('\n'):
            n += len(re.findall(r'(?<!\\)\$', ln))
        if n % 2:
            checks.append(('%s 行内 $ 成对' % name, False, '计数 %d（奇数）' % n))
    for item, ok, note in checks:
        rec('L2', item, ok, note)

    # ---------------- L3 文本模式危险字符 ----------------
    # 状态机：注释 → 跳过；行内 $…$、行间 \[…\]、数学环境 → 跳过；verbatim → 跳过
    MATH_ENV = {'equation', 'equation*', 'align', 'align*', 'gather', 'gather*',
                'array', 'matrix', 'pmatrix', 'bmatrix', 'cases', 'split'}
    VERB_ENV = {'verbatim', 'Verbatim', 'VerbatimInput', 'lstlisting', 'minted'}
    dangers = []
    for name, t in body.items():
        lines = t.split('\n')
        in_math_env, in_verb, in_disp = None, False, False
        in_inline = False
        for ln_no, raw in enumerate(lines, 1):
            s = strip_comment(raw)
            for m in re.finditer(r'\\(begin|end)\{([^}]+)\}', s):
                e = m.group(2)
                if m.group(1) == 'begin' and e in MATH_ENV:
                    in_math_env = e
                elif m.group(1) == 'end' and e == in_math_env:
                    in_math_env = None
                if m.group(1) == 'begin' and e in VERB_ENV:
                    in_verb = True
                if m.group(1) == 'end' and e in VERB_ENV:
                    in_verb = False
            if in_verb:
                if not any(('\\end{%s}' % v) in s or ('\\%s' % v) in s for v in VERB_ENV):
                    continue
            if in_math_env or in_disp:
                if r'\]' in s:
                    in_disp = False
                if in_math_env or r'\]' not in s:
                    if r'\begin{equation}' in s or r'\end{equation}' in s:
                        pass
                    continue
                continue
            if r'\[' in s:
                in_disp = True
                continue
            if s.strip().startswith(r'\begin{equation}'):
                in_math_env = 'equation'
                continue
            # 文件名参数不排版（\input{code_manifest} 里的 _ 合法），先摘掉
            s = re.sub(r'\\(?:input|includegraphics)(\[[^\]]*\])?\{[^}]*\}', '', s)
            # 逐字符扫描，跳过数学模式与转义。
            # 表格体内 & 是列分隔符、_ 与 ^ 常见于格式串，均属合法，整行跳过。
            i = 0
            while i < len(s):
                c = s[i]
                # \(…\) 也是行内公式，其中的 _ ^ 合法。必须先于通用转义判断，
                # 否则会被"\\ + 任意字符"那一支提前吃掉。
                if s[i:i+2] == r'\(':
                    in_inline = True; i += 2; continue
                if s[i:i+2] == r'\)':
                    in_inline = False; i += 2; continue
                if c == '\\':
                    i += 2; continue
                if c == '$':
                    in_inline = not in_inline; i += 1; continue
                if not in_inline and c in '#&_^':
                    # 表格行：以 & 或 \\ 结尾的整行视为表体，不算危险字符
                    is_tab_row = s.count('&') >= 1 and (s.rstrip().endswith(r'\\') or s.count('&') >= 2)
                    if not is_tab_row:
                        dangers.append('%s:%d 裸 %s' % (name, ln_no, c))
                    break
                i += 1
    # \begin{tabular}{...} 里的列定义不含这些字符；\& 已由转义跳过
    # 裸 % 是**最危险**的一类：LaTeX 不报错，静默吞掉该行剩余内容。
    # 判据：% 前面是数字、中文或右括号 => 是"百分之"，不是注释（注释前一般是空白或行首）。
    for name, t in body.items():
        for ln_no, ln in enumerate(t.split('\n'), 1):
            # 一行里只有**第一个**未转义的 % 可能是"百分之"；
            # 它之后的 % 都落在注释里（注释中写 "45%" 是正常的）。
            first = next((m for m in re.finditer(r'(?<!\\)%', ln)), None)
            if first is not None:
                k = first.start()
                prev = ln[k - 1] if k > 0 else ''
                if prev and (prev.isdigit() or ord(prev) > 0x2e80 or prev in ')]'):
                    dangers.append('%s:%d 裸 %% （会吞掉该行剩余内容）' % (name, ln_no))
                prev = ln[k - 1] if k > 0 else ''
                if prev and (prev.isdigit() or ord(prev) > 0x2e80 or prev in ')]'):
                    dangers.append('%s:%d 裸 %% （会吞掉该行剩余内容）' % (name, ln_no))
                    break
    rec('L3', '文本模式危险字符（# & _ ^ 与裸 %）', not dangers, '; '.join(dangers[:6]))

    # ---------------- L4 规范合规 ----------------
    nn = []
    # 只看非注释文本：main.tex 的注释里正当地提到了 \numberwithin 的禁令
    j_nc = '\n'.join(strip_comment(x) for x in j.split('\n'))
    if r'\numberwithin' in j_nc:
        nn.append('出现 \\numberwithin（会打乱 1–85 的公式编号）')
    if 'listings' in j:
        nn.append('出现 listings（规范要求朴素 verbatim）')
    if r'\theequation' not in body.get('main.tex', ''):
        nn.append('main.tex 未显式重定义 \\theequation')
    for k in (r'\thesection', r'\thesubsection', r'\thesubsubsection'):
        if k not in body.get('main.tex', ''):
            nn.append('main.tex 未显式重定义 %s' % k)
    # 标题内不应有手写序号
    for name, t in body.items():
        for m in re.finditer(r'\\(section|subsection|subsubsection)\{([^}]*)\}', strip_comments(t)):
            # 手写序号形如『1.1 问题背景』；『7 日滚动…』是正当标题，不能误杀
            if re.match(r'^[一二三四五六七八九十]+[、.]|^\d+(\.\d+)+\s', m.group(2)):
                nn.append('%s 标题含手写序号：%s' % (name, m.group(2)[:18]))
    rec('L4', '规范合规（编号重定义 / 无 listings / 标题无手写序号）', not nn,
        '; '.join(nn[:4]))

    # ---------------- L5 Markdown 残留 ----------------
    md = []
    for name, t in body.items():
        lst = t.split('\n')
        in_disp = False          # 行间公式体内不查 Markdown 残留
        for i, ln in enumerate(lst, 1):
            s = ln.strip()
            if s.startswith('# ') or re.match(r'^#{2,4}\s', s):
                md.append('%s:%d md 标题' % (name, i))
            nc = strip_comment(ln)
            if re.search(r'(?<!\\)\\\[', nc):
                in_disp = True
                continue
            if re.search(r'(?<!\\)\\\]', nc):
                in_disp = False
                continue
            if in_disp:
                continue
            # 去掉行内数学：公式里的 | 和 ` 是正常数学符号
            nc_nomath = re.sub(r'\$[^$]*\$', '', nc)
            if nc_nomath.strip().startswith('|') and nc_nomath.count('|') >= 2:
                md.append('%s:%d 管道表' % (name, i))
            if '**' in nc_nomath:
                md.append('%s:%d **' % (name, i))
            if re.match(r'^[-*]\s+\S', nc_nomath.strip()):
                md.append('%s:%d 项目符号' % (name, i))
            if '`' in nc_nomath:
                md.append('%s:%d 反引号' % (name, i))
    # verbatim 代码里允许反引号与 % 之类，附录 B 的代码不进 md 检查
    md = [x for x in md if not x.startswith(('appendix.tex',))]
    rec('L5', 'Markdown 残留（标题 / 管道表 / ** / 项目符号 / 反引号）', not md,
        '; '.join(md[:5]))

    # ---------------- L6 引用与浮动体 ----------------
    is6 = []
    labels = re.findall(r'\\label\{([^}]*)\}', j)
    dup = {x for x in labels if labels.count(x) > 1}
    if dup:
        is6.append('重复 label：%s' % sorted(dup)[:4])
    refs = set(re.findall(r'\\ref\{([^}]*)\}', j))
    if refs - set(labels):
        is6.append('引用了不存在的 label：%s' % sorted(refs - set(labels))[:4])
    # caption 必须在 label 之前
    for name, t in body.items():
        for m in re.finditer(r'\\label\{([^}]*)\}', t):
            pre = t[:m.start()]
            if pre.rfind(r'\caption') < pre.rfind(r'\begin{table}') and \
               pre.rfind(r'\begin{table}') != -1:
                is6.append('%s：%s 的 caption 缺失或在 label 之后' % (name, m.group(1)))
                break
    # includegraphics 路径存在
    for m in re.finditer(r'\\includegraphics\[[^\]]*\]\{([^}]*)\}', j):
        p = os.path.join(PAPER, m.group(1))
        if not os.path.exists(p):
            is6.append('图片不存在：%s' % m.group(1))
    # 附录 \input 的片段存在
    for m in re.finditer(r'\\input\{([^}]*)\}', j):
        p = os.path.join(PAPER, m.group(1) + '.tex')
        if not os.path.exists(p):
            is6.append('\\input 目标不存在：%s' % m.group(1))
    # 浮动体套浮动体：编译报 "Not in outer par mode"（曾因插图锚点取在
    # \label{tab:12} 之后、\end{table} 之前而真实发生）
    NEST_BAD = {'table', 'figure', 'equation', 'align', 'gather',
                'tabular', 'array', 'cases', 'split'}
    for name, t in body.items():
        st = []
        for m in re.finditer(r'\\(begin|end)\{([^}]+)\}', strip_comments(t)):
            e = m.group(2)
            if m.group(1) == 'begin':
                if e in ('figure', 'table') and any(x in NEST_BAD for x in st):
                    bad = next(x for x in reversed(st) if x in NEST_BAD)
                    is6.append('%s：\\begin{%s} 嵌在 %s 内（浮动体套浮动体，编译必错）'
                               % (name, e, bad))
                st.append(e)
            elif st and st[-1] == e:
                st.pop()
    rec('L6', '引用与浮动体（label 唯一 / 引用可解 / 图片与 input 存在 / 不套嵌）',
        not is6, '; '.join(is6[:5]))

    # ---------------- L7 附录代码 ----------------
    is7 = []
    for p in files('*.m', CODE):
        lines = open(p, encoding='utf-8').read().split('\n')
        for i, ln in enumerate(lines, 1):
            if '\t' in ln:
                is7.append('%s:%d 含制表符' % (os.path.basename(p), i))
                break
    # main.tex 里 \fvset 必须关行号与边框
    mt = body.get('main.tex', '')
    if 'numbers=none' not in mt:
        is7.append('main.tex 的 \\fvset 未关行号')
    if 'breaklines=true' not in mt:
        is7.append('main.tex 的 \\fvset 未开软折行（超宽行会溢出）')
    if 'frame=none' not in mt:
        is7.append('main.tex 的 \\fvset 未关边框')
    # 附录代码要求**完整**（2026-09-13 编程手要求），不再按 6 页预算截断；
    # 这里只报行数供参考，不作为失败项。正文 30 页另由 L8 约束。
    n_code = sum(len(open(p, encoding='utf-8').read().split('\n')) for p in files('*.m', CODE))
    rec('L7', '附录代码（制表符 / 排版开关；%d 行，要求完整不截断）' % n_code,
        not is7, '; '.join(is7[:4]))

    # ---------------- 汇总 ----------------
    print('%-4s %-56s %-5s %s' % ('层', '检查项', '结果', '说明'))
    print('-' * 110)
    nf = 0
    for lv, item, res, note in R:
        print('%-4s %-56s %-5s %s' % (lv, item[:56], res, note[:44]))
        nf += (res == 'FAIL')
    print('-' * 110)
    print('共 %d 项：PASS %d，FAIL %d' % (len(R), len(R) - nf, nf))

    rep = '\n'.join('%-4s %-56s %-5s %s' % r for r in R)
    open(os.path.join(HERE, 'check_report.txt'), 'w', encoding='utf-8').write(
        rep + '\n\n共 %d 项：PASS %d，FAIL %d\n' % (len(R), len(R) - nf, nf))
    print('\n报告已写 check_report.txt')
    return 1 if nf else 0


if __name__ == '__main__':
    sys.exit(main())
