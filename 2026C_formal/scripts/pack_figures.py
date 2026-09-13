#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""pack_figures.py —— 把**全部图件**（含绘图脚本与数据）打包进 deliver/

用法：python3 scripts/pack_figures.py

为什么要有这一层（2026-09-13 编程手裁定）：
    deliver 的图件**不是"每问选一张"**，而是要交付**完整附件**。
    因此把 `figures/<问题X>/<NN 图名>/` 整个自包含文件夹原样复制到
    `deliver/图件/<问题X>/<NN 图名>/`，每张图都带齐四件：

        绘图脚本 plot_*.m  +  data.csv  +  <交付中文名>.png  +  <交付中文名>.pdf

    这样评审拿到任意一张图，都能对出"这个数字是怎么画出来的"。
    `deliver/` 顶层的每问一张 jpg 是**另外**的东西——那是给评审一眼看结论的提要图，
    与本目录并存不冲突。

跳过规则：只复制 `figures/<问题X>/<NN 图名>/` 这一层（即"NN 图名"为子目录名），
其余以 `_` 开头的目录（`_已删除_勿引用/`、`_旧版_勿引用/` 等）一律不进交付面——
按本仓约定，"勿引用"目录是历史留档，论文与交付都不得引用。
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QS = ['问题一', '问题二', '问题三', '问题四']
DST_BASE = os.path.join(ROOT, 'deliver', '图件')


def main():
    if os.path.isdir(DST_BASE):
        shutil.rmtree(DST_BASE)                      # 幂等：先清旧，避免残留已删图
    n_fig = 0
    for q in QS:
        src_q = os.path.join(ROOT, 'figures', q)
        if not os.path.isdir(src_q):
            print('  [警告] 缺少图件目录 %s' % src_q, file=sys.stderr)
            continue
        for name in sorted(os.listdir(src_q)):
            if name.startswith('_'):
                continue
            src = os.path.join(src_q, name)
            if not os.path.isdir(src):
                continue
            files = os.listdir(src)
            if not any(f.endswith('.png') for f in files):
                continue
            dst = os.path.join(DST_BASE, q, name)
            shutil.copytree(src, dst, dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns('改.png'))   # 人工改图是内部对照件，不进交付
            n_fig += 1
            miss = [e for e in ('.png', '.pdf', 'data.csv') if not any(f.endswith(e) for f in files)]
            if not any(f.startswith('plot_') for f in files):
                miss.append('plot_*.m')
            print('  %s/%s%s' % (q, name, '  [缺 ' + '、'.join(miss) + ']' if miss else ''))
    print('图件已打包 %d 张 → deliver/图件/<问题X>/<NN 图名>/' % n_fig)
    return 0


if __name__ == '__main__':
    sys.exit(main())
