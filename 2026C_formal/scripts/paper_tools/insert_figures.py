#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""insert_figures.py —— 插入论文用图（已按 25 页目标精简到 4 张 + 总体流程图）

页面预算紧张，正文只保留**每问一张最能支撑结论**的图：
  · 问题重述：总体流程图（建模手提供，fig:flow，由本脚本之外的代码插入）
  · 问题一：典型日计划购电策略          fig:q1-day
  · 问题二：全年逐日购电结构            fig:q2-year
  · 问题三：指定日期四阶段轨迹          fig:q3-stage
  · 问题四：一周电价预测对照            fig:q4-week

其余 6 张定稿图（问题一储能轨迹、问题二日末储电量/指定日期、问题三日末储电量/逐日结构、
问题四逐时误差画像）结论已在正文与表格中给出，图件仍随交付附件提供，只是不再占正文版面。

规范要求"图前引导句 + 图 + 图后解释句"三件套，故每张图都带引导与解释。
幂等：用 %FIG:BEGIN <key> / %FIG:END 注释包裹，重复运行整段替换。

用法：python3 insert_figures.py
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PAPER = os.path.join(ROOT, 'paper')
SRC_FIG = os.path.join(ROOT, 'figures')
DST_FIG = os.path.join(PAPER, 'figures')

# (key, 源目录, ASCII 名, caption, label, 引导句, 解释句)
FIGS = [
    ('q1-day', '问题一/01 典型日计划购电策略', 'q1_day_plan.png',
     '典型日的分时电价与逐 10 min 计划购电量（电价单位：元/kWh，购电量单位：kWh）',
     'fig:q1-day',
     '典型日的分时电价与逐 10 min 计划购电量对照见图~\\ref{fig:q1-day}。',
     '计划购电量与电价呈反向分布，全天 144 个时段中有 58 个时段购电量为零，'
     '二者相关系数为 $-0.555$。若按 00:00—01:00 与 22:00—24:00 计谷段（占时长 12.5\\%），'
     '该段承担了 33.7\\% 的购电量，而 18:00—21:00 晚峰仅占 6.6\\%，'
     '可见储能把购电从高价时段搬到了低价时段。'),

    ('q2-year', '问题二/01 全年逐日购电结构', 'q2_year.png',
     '报送窗口内逐日购电结构（电量单位：kWh）', 'fig:q2-year',
     '报送窗口内逐日的购电结构见图~\\ref{fig:q2-year}。',
     '计划购电逐日平稳且季节性强，弃光、已购未用与紧急购电三者的量级都远小于计划购电，'
     '其峰值集中在夏秋两季。'),

    ('q1-soc', '问题一/02 储能充放电与储电量', 'q1_soc.png',
     '典型日储能充放电量与储电量（电量单位：kWh）', 'fig:q1-soc',
     '储能设备的充放电量与储电量变化见图~\\ref{fig:q1-soc}。',
     '全天充电量 20\\,740.67 kWh、放电量 16\\,799.94 kWh，储电量始终落在 '
     '$[1200,\\ 10800]$ kWh 的运行区间内。充电量大于放电量是充放电效率均为 0.90 '
     '的正常结果，并非计算误差。'),

    ('q2-soc', '问题二/02 日末储电量轨迹', 'q2_soc.png',
     '问题二报送窗口内日末储电量轨迹（电量单位：kWh）', 'fig:q2-soc',
     '日末储电量的全年轨迹见图~\\ref{fig:q2-soc}。',
     '报送窗口内日末储电量均值为 7\\,046 kWh，全年仅 1 天触到 1\\,200 kWh 的下限，'
     '说明 7 日滚动视野的终端价值设定有效，日末储电量没有被放空。'),

    ('q2-key', '问题二/03 指定日期_计划购电与紧急购电', 'q2_keydate.png',
     '问题二四个指定日期的计划购电与紧急购电（电量单位：kWh）', 'fig:q2-key',
     '四个指定日期的计划购电与紧急购电见图~\\ref{fig:q2-key}。',
     '四天中仅 09-23 触发紧急购电（5\\,351.69 kWh，分 08:20—10:00 与 19:50—22:00 两段），'
     '其余三天均为零。'),

    ('q3-year', '问题三/01 逐日购电与调整结构', 'q3_year.png',
     '问题三逐日购电与调整结构（电量单位：kWh）', 'fig:q3-year',
     '问题三逐日的购电与调整结构见图~\\ref{fig:q3-year}。',
     '引入日内预报更新后，最终生效购电量仍逐日平稳，而调增与调减在大量日期发生：'
     '全年 339 天有调增、340 天有调减、225 天触发紧急购电，说明计划再调整已是常态机制。'),

    ('q3-soc', '问题三/02 日末储电量轨迹', 'q3_soc.png',
     '问题三报送窗口内日末储电量轨迹（电量单位：kWh）', 'fig:q3-soc',
     '问题三日末储电量的全年轨迹见图~\\ref{fig:q3-soc}。',
     '报送窗口内日末储电量均值为 6\\,848 kWh，仅 4 天触及下限（问题二为 1 天）。'
     '触底天数增加是日内多次重优化的代价，但储能运行整体仍保持平稳。'),

    ('q4-prof', '问题四/01 电价预测画像', 'q4_price_profile.png',
     '电价预测的逐小时误差画像（误差单位：元/kWh）', 'fig:q4-prof',
     '电价预测的逐小时误差画像见图~\\ref{fig:q4-prof}。',
     '经逐小时偏差校正后各小时误差普遍下降，整体 MAE 由 0.0489 降至 0.0432 元/kWh，'
     '改善 11.57\\%，校正后残余偏差最大仅 0.0122 元/kWh。误差的时段分布并不均匀，'
     '清晨与傍晚相对更大，逐时 MAE 的最大值出现在 10:00—11:00。'),

    ('q3-stage', '问题三/03 指定日期四阶段轨迹', 'q3_stages.png',
     '问题三四个指定日期的四阶段计划轨迹与紧急购电（电量单位：kWh）', 'fig:q3-stage',
     '四个指定日期的四阶段计划轨迹见图~\\ref{fig:q3-stage}。',
     '再调整的方向与幅度逐日不同：03-20 与 06-21 为净调减，09-23 与 12-21 为净调增，'
     '说明模型确实在利用日内预报修正偏差，而不是单向动作。'),

    ('q4-week', '问题四/03 一周电价预测对照', 'q4_price_week.png',
     '一周中心电价预测与实测电价对照（电价单位：元/kWh）', 'fig:q4-week',
     '中心预测与实测电价的逐时段对照（取 2025 年 7 月 14 日至 7 月 20 日）'
     '见图~\\ref{fig:q4-week}。',
     '中心预测能够刻画日内峰谷形态，高低价时段基本对齐，该周预测对实测的 '
     'MAE 为 0.0371 元/kWh；但峰谷出现的具体时刻仍有偏差。'),
]

# (文件, 锚点, 锚点前/后, 图 key)
JOBS = [
    ('sections/q1.tex', '%MANDATED:BEGIN', 'before', ['q1-day', 'q1-soc']),
    ('sections/q2.tex', '%MANDATED:BEGIN', 'before', ['q2-year', 'q2-soc']),
    ('sections/q2.tex', '%MANDATED:END', 'after', ['q2-key']),
    ('sections/q3.tex', '%MANDATED:END', 'after', ['q3-stage', 'q3-soc']),
    ('sections/q3.tex', '%MANDATED:BEGIN', 'before', ['q3-year']),
    ('sections/q4.tex', r'RMSE_\pi', 'env-after', ['q4-week']),
    ('sections/q4.tex', r'\label{tab:12}', 'after-env', ['q4-prof']),
]

# 正文不再使用的图件（结论已在正文与表格中给出，图仍在交付附件里）
DROP = []


def block(key, lead, expl, cap, lab, fname):
    return '\n'.join([
        '%%FIG:BEGIN %s' % key,
        lead, '',
        r'\begin{figure}[htbp]',
        r'\centering',
        r'\includegraphics[width=0.78\textwidth,height=0.26\textheight,keepaspectratio]{figures/%s}' % fname,
        r'\caption{%s}' % cap,
        r'\label{%s}' % lab,
        r'\end{figure}', '',
        expl,
        '%%FIG:END %s' % key,
    ])


def strip_block(text, key):
    b, e = '%%FIG:BEGIN %s' % key, '%%FIG:END %s' % key
    while b in text:
        i = text.index(b)
        j = text.index(e, i) + len(e)
        text = text[:i] + text[j:]
    return text


def main():
    by_key = {f[0]: f for f in FIGS}

    os.makedirs(DST_FIG, exist_ok=True)
    for key, srcdir, fname, *_ in FIGS:
        src = os.path.join(SRC_FIG, srcdir)
        pngs = [f for f in os.listdir(src) if f.lower().endswith('.png')]
        if len(pngs) != 1:
            print('  !! %s 下 PNG 不是唯一：%s' % (srcdir, pngs))
            return 1
        shutil.copy2(os.path.join(src, pngs[0]), os.path.join(DST_FIG, fname))
        print('  %-44s → figures/%s' % (srcdir, fname))

    for fn, anchor, where, keys in JOBS:
        path = os.path.join(PAPER, fn)
        lines = open(path, encoding='utf-8').read().split('\n')
        text = '\n'.join(lines)
        for k in keys + DROP:                       # 幂等：先抹掉旧块（含已废弃的图）
            text = strip_block(text, k)
        lines = text.split('\n')

        payload = []
        for k in keys:
            _, _, fname, cap, lab, lead, expl = by_key[k]
            payload += ['', block(k, lead, expl, cap, lab, fname)]

        pos = next((j for j, ln in enumerate(lines) if ln.strip() == anchor), None)
        if pos is None:
            print('  !! 未找到锚点 %r in %s' % (anchor[:40], fn))
            return 1
        if where == 'before':
            ins = pos
        elif where == 'after':
            ins = pos + 1
        else:                                        # env-after：跳到该公式环境之后
            ins = pos
            while ins < len(lines) and lines[ins].strip() not in (r'\]', r'\end{equation}'):
                ins += 1
            ins += 1
        lines[ins:ins] = payload
        open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        print('  %-18s 插入 %s' % (fn, '+'.join(keys)))

    # 复查：正文里只剩本脚本负责的 4 张 + 问题重述的总体流程图
    n_own = sum(open(os.path.join(PAPER, 'sections', f), encoding='utf-8').read()
                .count('%FIG:BEGIN') for f in os.listdir(os.path.join(PAPER, 'sections')))
    print('\n正文结果图 %d 张（应为 %d），另有总体流程图 1 张' % (n_own, len(FIGS)))
    return 0 if n_own == len(FIGS) else 1


if __name__ == '__main__':
    sys.exit(main())
