#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""flatten_deliver_code.py —— 整理交付文件夹里的 .m 副本

用法：python3 scripts/flatten_deliver_code.py <交付文件夹>

做两件事，都只动交付副本、不动 src/ 原文件：

1. **摘掉指向 src/ 的 addpath**。交付文件夹是平铺的，入口程序与子函数同目录，
   MATLAB 自动解析兄弟函数；原 addpath 指向的 `../src` 在交付目录里并不存在，
   评审一运行就会看到一条空路径告警。改为一行中文说明注释。
2. **把入口程序顶部补一句"同目录函数自动可用"的提示**，让评审明白这批 .m 是一个整体。

脚本可反复运行（幂等）：已经处理过的文件不再变化。
"""
import os
import re
import sys

# 整行判定：行首为 addpath( 且该行含 'src' 即视为"挂 src 路径"。
# 不用正则匹配括号（`fullfile(PROJ_ROOT, 'src')` 含嵌套括号，字符类写法会漏匹配——本轮踩过）。
NOTE = '%% 本文件夹内的子函数与本程序同目录，MATLAB 自动解析，无需额外添加搜索路径。'

# 入口程序（补同目录提示）
ENTRIES = ('main_q1.m', 'main_q2c.m', 'main_q3b.m', 'main_q4.m')


def strip_src_addpath(text):
    """把整行 `addpath(...'src'...)` 替换为同目录提示；返回 (新文本, 替换条数)。"""
    out, n = [], 0
    for ln in text.splitlines(keepends=True):
        s = ln.strip()
        if s.startswith('addpath(') and "'src'" in s and s.endswith(';'):
            out.append(NOTE + '\n')
            n += 1
        else:
            out.append(ln)
    return ''.join(out), n


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    d = sys.argv[1]
    n_path = n_note = 0
    for fn in sorted(os.listdir(d)):
        if not fn.endswith('.m'):
            continue
        p = os.path.join(d, fn)
        t = open(p, encoding='utf-8').read()
        new, k = strip_src_addpath(t)
        n_path += k
        if fn in ENTRIES and NOTE not in new:
            # 插在第一处代码行（非注释、非空行）之前
            lines = new.splitlines(keepends=True)
            for i, ln in enumerate(lines):
                s = ln.strip()
                if s and not s.startswith('%') and not s.startswith('function'):
                    lines.insert(i, NOTE + '\n')
                    break
            new = ''.join(lines)
            n_note += 1
        if new != t:
            open(p, 'w', encoding='utf-8').write(new)
    print('  整理交付副本：摘除 src 路径 %d 处、补同目录提示 %d 处' % (n_path, n_note))
    return 0


if __name__ == '__main__':
    sys.exit(main())
