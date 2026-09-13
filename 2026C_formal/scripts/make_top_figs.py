#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_top_figs.py —— 把人工筛选出的关键结果图复制为 deliver/ 顶层的 jpg

用法：python3 scripts/make_top_figs.py

命名规范（交付附件命名与结构规范，命名规则 1）：
    `问题X <参数>_<目标结果>.jpg`——全中文，多个参数用、连接，
    目标结果为评审一眼可读的短语，禁"最终版"等模糊词。

选图口径：每问一张，取该问最能独立说明结论者（人工筛选，见 FIGURES_GUIDE.md §一）。
取图源：优先用人工修证稿 `改.png`（它是写进论文的定稿），没有时才退回脚本输出。
改选图只改下面 PICKS 一行即可，不要改文件名格式。
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PICKS = [
    ('figures/问题一/01 典型日计划购电策略/问题一 典型日计划购电策略.png',
     '问题一 分时电价_典型日最优购电计划.jpg'),
    ('figures/问题二/01 全年逐日购电结构/问题二 全年逐日购电结构.png',
     '问题二 七日滚动_全年购电结构.jpg'),
    ('figures/问题三/03 指定日期四阶段轨迹/问题三 指定日期四阶段轨迹.png',
     '问题三 四预报时点_指定日期计划调整.jpg'),
    ('figures/问题四/03 一周电价预测对照/问题四 一周电价预测对照.png',
     '问题四 实时电价_一周预测与实测对照.jpg'),
]


def main():
    dst_dir = os.path.join(ROOT, 'deliver')
    os.makedirs(dst_dir, exist_ok=True)
    bad = 0
    for src, dst in PICKS:
        src_p = os.path.join(ROOT, src)
        if not os.path.exists(src_p):
            print('  [警告] 缺少源图 %s' % src, file=sys.stderr)
            bad += 1
            continue
        # 有人工修证稿就用它——那才是写进论文的图
        edited = os.path.join(os.path.dirname(src_p), '改.png')
        if os.path.exists(edited):
            src_p = edited
        im = Image.open(src_p).convert('RGB')
        out = os.path.join(dst_dir, dst)
        im.save(out, 'JPEG', quality=95, dpi=(300, 300), optimize=True)
        print('  %-40s %s  %.1f MB' % (dst, im.size, os.path.getsize(out) / 1e6))
    print('顶层关键结果图 %d/%d 张已写入 deliver/' % (len(PICKS) - bad, len(PICKS)))


if __name__ == '__main__':
    main()
