#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""insert_figures.py —— 复制 10 张定稿图并插入正文

做三件事：
  1. 把 figures/ 下的 10 张定稿 PNG 复制进 paper/figures/ 并**改 ASCII 名**
     （原文件名含中文与空格，部分 TeX Live 下 \\includegraphics 会 File not found）；
  2. 按规范"图前引导句 + 图 + 图后解释句"的格式把 figure 环境插到各章合适位置
     （规范的 图表规范 §四.2 明确要求这三件套，且解释句须与图件清单登记的支撑结论一致）；
  3. 图内已有人工修证的楷体标题，故 caption 写成**更完整的自解释句**（补变量与单位），
     不与图内标题逐字重复。

初稿把三组结果图占位放在各章开头（图会跑到上一章去），这里改放到各问的
"求解结果/结果分析"小节，与结论就近。

幂等：用 %FIG:BEGIN <key> / %FIG:END 注释包裹，重复运行整段替换。

用法：python3 insert_figures.py
"""
import os
import re
import shutil
import sys

# 本脚本在 scripts/paper_tools/ 下，产物一律写回 ../../paper/
HERE = os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), 'paper')
ROOT = os.path.dirname(HERE)
SRC_FIG = os.path.join(ROOT, 'figures')
DST_FIG = os.path.join(HERE, 'figures')

# (key, 源目录, ASCII 文件名, caption, label, 引导句, 解释句)
FIGS = [
    ('q1-day', '问题一/01 典型日计划购电策略', 'q1_day_plan.png',
     '典型日的分时电价与逐 10 min 计划购电量（电价单位：元/kWh，购电量单位：kWh）',
     'fig:q1-day',
     '典型日的分时电价与逐 10 min 计划购电量对照见图~\\ref{fig:q1-day}。',
     '计划购电量与电价呈反向分布，全天 144 个时段中有 58 个时段购电量为零，'
     '二者相关系数为 $-0.555$。若按 00:00—01:00 与 22:00—24:00 计谷段（占时长 12.5\\%），'
     '该段承担了 33.7\\% 的购电量，而 18:00—21:00 晚峰仅占 6.6\\%，'
     '可见储能把购电从高价时段搬到了低价时段。'),

    ('q1-soc', '问题一/02 储能充放电与储电量', 'q1_soc.png',
     '典型日储能充放电量与储电量（电量单位：kWh）', 'fig:q1-soc',
     '储能设备的充放电量与储电量变化见图~\\ref{fig:q1-soc}。',
     '全天充电量 20\\,740.67 kWh、放电量 16\\,799.94 kWh，储电量始终落在 '
     '$[1200,\\ 10800]$ kWh 的运行区间内。充电量大于放电量是充放电效率均为 0.90 '
     '的正常结果，并非计算误差。'),

    ('q2-year', '问题二/01 全年逐日购电结构', 'q2_year.png',
     '报送窗口内逐日购电结构（电量单位：kWh）', 'fig:q2-year',
     '报送窗口内逐日的购电结构见图~\\ref{fig:q2-year}。',
     '计划购电逐日平稳且季节性强，弃光、已购未用与紧急购电三者的量级都远小于计划购电，'
     '其峰值集中在夏秋两季。'),

    ('q2-soc', '问题二/02 日末储电量轨迹', 'q2_soc.png',
     '问题二报送窗口内日末储电量轨迹（电量单位：kWh）', 'fig:q2-soc',
     '日末储电量的全年轨迹见图~\\ref{fig:q2-soc}。',
     '报送窗口内日末储电量均值为 7\\,046 kWh，全年仅 1 天触到 1\\,200 kWh 的下限，'
     '说明 7 日滚动视野的终端价值设定有效，日末储电量没有被放空。'),

    ('q2-key', '问题二/03 指定日期_计划购电与紧急购电', 'q2_keydate.png',
     '问题二四个指定日期的计划购电与紧急购电（电量单位：kWh）', 'fig:q2-key',
     '四个指定日期的计划购电与紧急购电见图~\\ref{fig:q2-key}。',
     '四天中仅 09-23 触发紧急购电（5\\,351.69 kWh，分 08:20—10:00 与 19:50—22:00 两段），'
     '其余三天均为零，与表~\\ref{tab:7} 的逐日指标一致。'),

    ('q3-year', '问题三/01 逐日购电与调整结构', 'q3_year.png',
     '问题三逐日购电与调整结构（电量单位：kWh）', 'fig:q3-year',
     '问题三逐日的购电与调整结构见图~\\ref{fig:q3-year}。',
     '引入日内预报更新后，最终生效购电量仍逐日平稳，而调增与调减在大量日期发生：'
     '全年 339 天有调增、340 天有调减、225 天触发紧急购电，'
     '说明计划再调整已是常态机制而非个别现象。'
     '图中调减量以负值画在零线下方，属瀑布式堆叠约定，不代表负购电。'),

    ('q3-soc', '问题三/02 日末储电量轨迹', 'q3_soc.png',
     '问题三报送窗口内日末储电量轨迹（电量单位：kWh）', 'fig:q3-soc',
     '问题三日末储电量的全年轨迹见图~\\ref{fig:q3-soc}。',
     '报送窗口内日末储电量均值为 6\\,848 kWh，仅 4 天触及下限（问题二为 1 天）。'
     '触底天数增加是日内多次重优化的代价，但储能运行整体仍保持平稳。'),

    ('q3-stage', '问题三/03 指定日期四阶段轨迹', 'q3_stages.png',
     '问题三四个指定日期的四阶段计划轨迹与紧急购电（电量单位：kWh）', 'fig:q3-stage',
     '四个指定日期的四阶段计划轨迹见图~\\ref{fig:q3-stage}。',
     '再调整的方向与幅度逐日不同：03-20 与 06-21 为净调减，09-23 与 12-21 为净调增，'
     '说明模型确实在利用日内预报修正偏差，而不是单向动作。'
     '橙线（0:00 原计划）与蓝线（最终生效计划）在 0:00 时段重合，'
     '是该时段尚未发生调整的必然结果。'),

    ('q4-week', '问题四/03 一周电价预测对照', 'q4_price_week.png',
     '一周中心电价预测与实测电价对照（电价单位：元/kWh）', 'fig:q4-week',
     '中心预测与实测电价的逐时段对照（取 2025 年 7 月 14 日至 7 月 20 日）'
     '见图~\\ref{fig:q4-week}。',
     '中心预测能够刻画日内峰谷形态，高低价时段基本对齐，该周预测对实测的 '
     'MAE 为 0.0371 元/kWh；但峰谷出现的具体时刻仍有偏差。'
     '本图只画实际电价与中心预测两条线，不含情景带——情景带是 SAA 的内部构造，不可直接观测。'),

    ('q4-prof', '问题四/01 电价预测画像', 'q4_price_profile.png',
     '电价预测的逐小时误差画像（误差单位：元/kWh）', 'fig:q4-prof',
     '电价预测的逐小时误差画像见图~\\ref{fig:q4-prof}。',
     '经逐小时偏差校正后各小时误差普遍下降，整体 MAE 由 0.0489 降至 0.0432 元/kWh，'
     '改善 11.57\\%，校正后残余偏差最大仅 0.0122 元/kWh。'
     '误差的时段分布并不均匀，清晨与傍晚相对更大，逐时 MAE 的最大值出现在 10:00—11:00。'),
]

# 插入点：文件, 锚点（唯一行）, 锚点前还是后, 图 key 列表
JOBS = [
    ('sections/q1.tex', '%MANDATED:BEGIN', 'before', ['q1-day', 'q1-soc']),
    ('sections/q2.tex', '%MANDATED:BEGIN', 'before', ['q2-year', 'q2-soc']),
    ('sections/q2.tex', '%MANDATED:END', 'after', ['q2-key']),
    ('sections/q3.tex', '结果分析时应重点判断：新增预报是主要降低了紧急购电、降低了已购未用电，还是仅增加调整频率而没有产生足够经济收益。',
     'after', ['q3-year', 'q3-soc']),
    ('sections/q3.tex', '%MANDATED:END', 'after', ['q3-stage']),
    ('sections/q4.tex', r'RMSE_\pi', 'env-after', ['q4-week']),
    # after-env：插到该锚点所在的**整个浮动体之后**。
    # 早先写成 after，结果图被插在 \label{tab:12} 与 \end{table} 之间——
    # 浮动体套浮动体，编译报 "Not in outer par mode"。
    ('sections/q4.tex', r'\label{tab:12}', 'after-env', ['q4-prof']),
]


def block(key, lead, expl, cap, lab, fname):
    return '\n'.join([
        '%%FIG:BEGIN %s' % key,
        lead, '',
        r'\begin{figure}[htbp]',
        r'\centering',
        r'\includegraphics[width=0.86\textwidth]{figures/%s}' % fname,
        r'\caption{%s}' % cap,
        r'\label{%s}' % lab,
        r'\end{figure}', '',
        expl,
        '%%FIG:END %s' % key,
    ])


def main():
    by_key = {f[0]: f for f in FIGS}

    # ---- 1. 复制图件并改 ASCII 名 ----
    os.makedirs(DST_FIG, exist_ok=True)
    for key, srcdir, fname, *_ in FIGS:
        src = os.path.join(SRC_FIG, srcdir)
        pngs = [f for f in os.listdir(src) if f.lower().endswith('.png')]
        if len(pngs) != 1:
            print('  !! %s 下 PNG 不是唯一：%s' % (srcdir, pngs))
            return 1
        shutil.copy2(os.path.join(src, pngs[0]), os.path.join(DST_FIG, fname))
        print('  %-46s → figures/%s' % (srcdir, fname))

    # ---- 2. 插入正文 ----
    for fn, anchor, where, keys in JOBS:
        path = os.path.join(HERE, fn)
        lines = open(path, encoding='utf-8').read().split('\n')
        payload = []
        for k in keys:
            _, _, fname, cap, lab, lead, expl = by_key[k]
            payload += ['', block(k, lead, expl, cap, lab, fname)]

        # 幂等：先把已存在的同名块整段抹掉
        for k in keys:
            b, e = '%%FIG:BEGIN %s' % k, '%%FIG:END %s' % k
            if any(ln.strip() == b for ln in lines):
                i = next(j for j, ln in enumerate(lines) if ln.strip() == b)
                m = next(j for j, ln in enumerate(lines) if ln.strip() == e)
                del lines[i:m + 1]

        pos = next((j for j, ln in enumerate(lines) if ln.strip() == anchor), None)
        if pos is None:
            print('  !! 未找到锚点 %r in %s' % (anchor[:40], fn))
            return 1
        if where == 'before':
            ins = pos
        elif where == 'after':
            ins = pos + 1
        elif where == 'after-env':
            # 跳到锚点所在的**整个环境之后**（锚点可能是 \label{tab:12}，
            # 它后面还有 \end{table}——插在两者之间会让浮动体套浮动体，编译必报
            # "Not in outer par mode"）。按 \begin/\end 配对跳。
            # 锚点本身在环境**内部**，所以要等到"第一个把该环境关掉的 \end"之后。
            # 从锚点下一行开始走：遇到 \begin 加一层，遇到 \end 时若当前深度为 0
            # 说明关掉的就是锚点所在的那个环境，插到它后面。
            ins = pos + 1
            depth = 0
            while ins < len(lines):
                st = lines[ins].strip()
                if re.match(r'^\\begin\{', st):
                    depth += 1
                elif re.match(r'^\\end\{', st):
                    if depth == 0:
                        ins += 1
                        break
                    depth -= 1
                ins += 1
            else:
                print('  !! %s 中锚点 %r 之后未找到环境结束' % (fn, anchor[:30]))
                return 1
        else:                                   # env-after：跳到该公式环境之后
            # 编号公式收在 \end{equation}，不编号的收在 \]，两者都要认
            ins = pos
            while ins < len(lines) and lines[ins].strip() not in (r'\]', r'\end{equation}'):
                ins += 1
            ins += 1
        lines[ins:ins] = payload
        open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        print('  %-18s 插入 %s 于第 %d 行' % (fn, '+'.join(keys), ins + 1))

    # ---- 3. 复查 ----
    # 只数本文负责的 10 张（问题重述里的总体流程图不归本脚本管）
    n = 0
    for root, _, fs in os.walk(os.path.join(HERE, 'sections')):
        for x in fs:
            if x.endswith('.tex'):
                n += open(os.path.join(root, x), encoding='utf-8').read().count('%FIG:BEGIN')
    print('\n本文插入的结果图 %d 张（应为 %d）' % (n, len(FIGS)))
    return 0 if n == len(FIGS) else 1


if __name__ == '__main__':
    sys.exit(main())
