#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""pack_figures.py —— 把入选图件打包进 deliver/图件/

用法：python3 scripts/pack_figures.py

入选口径（2026-09-13 编程手裁定）：
    `figures/问题X/<NN 图名>/` 下**还留着的就是入选的**——未入选的 4 张已移到
    `figures/_未入选_勿引用/`，带 `_` 前缀的目录一律不进交付。每个入选文件夹带齐：

        plot_*.m   +   data.csv   +   <问题X 图名>.png

    其中 `<问题X 图名>.png` 是**人工修证后的定稿**（原 `改.png` 已正式改名并替换脚本输出）。

不做的事：
    不带 .pdf（交付不出 pdf）；不带 `_未入选_勿引用/`、`_旧版_勿引用/`、
    `_已删除_勿引用/`、`_人工改图_备份/` 等以 `_` 开头的目录。
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QS = ['问题一', '问题二', '问题三', '问题四']
DST_BASE = os.path.join(ROOT, 'deliver', '图件')
KEEP_EXT = ('.m', '.csv', '.png')


def main():
    if os.path.isdir(DST_BASE):
        shutil.rmtree(DST_BASE)                      # 幂等：先清旧，避免残留已删图
    n_fig = 0
    for q in QS:
        src_q = os.path.join(ROOT, 'figures', q)
        if not os.path.isdir(src_q):
            continue
        for name in sorted(os.listdir(src_q)):
            if name.startswith('_'):
                continue
            src = os.path.join(src_q, name)
            if not os.path.isdir(src):
                continue
            files = os.listdir(src)
            dst = os.path.join(DST_BASE, q, name)
            os.makedirs(dst, exist_ok=True)
            for f in files:
                if f.endswith(KEEP_EXT):
                    shutil.copy2(os.path.join(src, f), os.path.join(dst, f))
            n_fig += 1
            miss = [e for e in ('data.csv',) if e not in files]
            if not any(f.endswith('.png') for f in files):
                miss.append('PNG 定稿')
            if not any(f.startswith('plot_') for f in files):
                miss.append('plot_*.m')
            print('  %s/%s%s' % (q, name, '  [缺 ' + '、'.join(miss) + ']' if miss else ''))
    print('图件已打包 %d 张 → deliver/图件/<问题X>/<NN 图名>/' % n_fig)
    return 0


if __name__ == '__main__':
    sys.exit(main())
