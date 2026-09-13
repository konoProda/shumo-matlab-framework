#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prep_appendix_code.py —— 为附录 B 准备代码副本（**完整收录每一问的全部代码**）

编程手要求（2026-09-13）：
  · 完整展示每一问的所有代码，不截断、不节选；
  · 只排除绘图脚本（规范 §七.3：绘图代码不进附录），绘图脚本随支撑材料提交。

组织方式：按「共用 → 问题一 → 问题二 → 问题三 → 问题四」分组，
每组内先主程序后子函数，每个文件一个 \\subsection 小标题。

代码自 ../src/ **原样复制，一字不改**；超宽行交给排版侧用 fvextra 的
breaklines 软折行，保证附录与支撑材料是同一份文本，便于评审核对。

用法：python3 prep_appendix_code.py       # --dry 只列清单不写盘
"""
import os
import shutil
import sys

# 本脚本在 scripts/paper_tools/ 下，产物一律写回 ../../paper/
HERE = os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), 'paper')
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'src')
DST = os.path.join(HERE, 'code')

# (组标题, [(来源相对路径, 输出名, 文件说明)])
GROUPS = [
    ('共用函数（四问依赖）', [
        ('共用/func_read_q2.m',     'func_read_q2.m',     '读取附件 2 的负荷与光伏数据'),
        ('共用/func_forecast_q2.m', 'func_forecast_q2.m', '负荷与光伏的中心预测'),
        ('共用/func_resid_q2.m',    'func_resid_q2.m',    '历史预测残差库'),
        ('共用/func_bias_q2.m',     'func_bias_q2.m',     '按小时偏差校正'),
        ('共用/func_write_q2.m',    'func_write_q2.m',    '写结果表 result*.xlsx'),
    ]),
    ('问题一', [
        ('问题一/main_q1.m',        'main_q1.m',        '入口：装配、求解、校验与落盘'),
        ('问题一/func_read_q1.m',   'func_read_q1.m',   '读取附件 1 的电价、负荷与光伏'),
        ('问题一/func_build_q1.m',  'func_build_q1.m',  '显式分流 MILP 的变量、目标与约束'),
        ('问题一/func_check_q1.m',  'func_check_q1.m',  '能量平衡与储能递推校验'),
        ('问题一/func_write_q1.m',  'func_write_q1.m',  '写 result1.xlsx 与表 1、表 2 数值'),
    ]),
    ('问题二', [
        ('问题二/main_q2c.m',       'main_q2c.m',       '入口：运行清单与逐日滚动'),
        ('问题二/func_roll_q2c.m',  'func_roll_q2c.m',  '7 日滚动主循环与断点续跑'),
        ('问题二/func_build_q2c.m', 'func_build_q2c.m', '两阶段 SAA-MILP 的变量、目标与约束'),
        ('问题二/func_scen_q2c.m',  'func_scen_q2c.m',  '联合误差情景抽样'),
        ('问题二/func_exec_q2c.m',  'func_exec_q2c.m',  '按真实数据执行并结算'),
    ]),
    ('问题三', [
        ('问题三/main_q3b.m',       'main_q3b.m',       '入口：四阶段策略运行'),
        ('问题三/func_roll_q3b.m',  'func_roll_q3b.m',  '日内多阶段滚动主循环'),
        ('问题三/func_build_q3b.m', 'func_build_q3b.m', '阶段调整与结算的 MILP 装配'),
        ('问题三/func_scen_q3b.m',  'func_scen_q3b.m',  '分阶段情景抽样'),
        ('问题三/func_exec_q3b.m',  'func_exec_q3b.m',  '阶段执行与拼接重放'),
        ('问题三/func_resid_q3b.m', 'func_resid_q3b.m', '分阶段残差库'),
        ('问题三/func_interp_q3b.m', 'func_interp_q3b.m', '附件 3 整点预报插值到 10 min'),
        ('问题三/func_read_q3b.m',  'func_read_q3b.m',  '读取附件 3 的分阶段预报'),
    ]),
    ('问题四', [
        ('问题四/main_q4.m',        'main_q4.m',        '入口：四种口径运行'),
        ('问题四/func_roll_q4.m',   'func_roll_q4.m',   '联合不确定性的滚动主循环'),
        ('问题四/func_price_q4.m',  'func_price_q4.m',  '电价中心预测与价格残差库'),
        ('问题四/func_scen_q4.m',   'func_scen_q4.m',   '价格与负荷光伏的联合情景'),
        ('问题四/func_forecast_q4.m', 'func_forecast_q4.m', '电价预测入口'),
    ]),
]

# 绘图脚本不进附录（规范 §七.3）
EXCLUDE = r'_fig_'


def main():
    dry = '--dry' in sys.argv
    if not dry:
        os.makedirs(DST, exist_ok=True)
    tex = ['% 本文件由 paper/prep_appendix_code.py 生成，勿手改', '']
    total = 0
    for gname, files in GROUPS:
        tex.append(r'\begingroup\noindent\textbf{%s}\par\endgroup' % gname)
        tex.append('')
        for src_rel, out, desc in files:
            if EXCLUDE in out:
                continue
            p = os.path.join(SRC, src_rel)
            lines = open(p, encoding='utf-8').read().split('\n')
            while lines and lines[-1] == '':
                lines.pop()
            n = len(lines)
            total += n
            if not dry:
                shutil.copy2(p, os.path.join(DST, out))
            tex += [r'\subsection{%s（\texttt{%s}，%d 行）}' % (desc, out, n),
                    r'\VerbatimInput{code/%s}' % out, '']
            print('  %-22s ← src/%-22s %4d 行  %s' % (out, src_rel, n, desc))
    if not dry:
        open(os.path.join(HERE, 'code_manifest.tex'), 'w', encoding='utf-8').write(
            '\n'.join(tex))
    # \zihao{6} 下每页约 88 行
    print('\n附录 B 代码合计 %d 行 → 约 %.1f 页（\\zihao{6}，按 88 行/页估）'
          % (total, total / 88.0))
    return 0


if __name__ == '__main__':
    sys.exit(main())
