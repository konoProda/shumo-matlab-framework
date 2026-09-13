#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""collect_values.py —— 从 outputs/ 的最终结果文件汇总论文所需数字

输出 paper/values.json（供 fill_gaps.py 填【待补】用）与一份可读清单，
每个数字都带**出处文件名**，便于确认点 #3 逐条对账。

数值零虚构：本脚本只读取真实的 .mat / .xlsx，不做任何推算或补估。
"""
import json
import os
import numpy as np
import h5py
import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'outputs')
V = {}


def S(tag):
    """读某个任务的 summary 结构体（final_results_*_<任务>.mat 的 s 字段）。

    结果文件有两种存法（v7.3 HDF5 与 v7），逐个试，任一可读即可。
    """
    p = os.path.join(OUT, 'final_results_%s.mat' % tag)
    if not os.path.exists(p):
        return None
    s = None
    try:
        with h5py.File(p, 'r') as f:
            s = f['s'] if 's' in f else None
            if s is not None:
                return {k: float(np.array(s[k]).ravel()[0]) for k in s.keys()
                        if np.array(s[k]).size == 1}
    except OSError:
        pass
    import scipy.io as sio
    d = sio.loadmat(p, squeeze_me=True, struct_as_record=True)
    if 's' not in d:
        return None
    st = d['s']
    out = {}
    for k in st.dtype.names or []:
        a = np.ravel(st[k][()])
        if a.size == 1:
            out[k] = float(a[0])
    return out


def xl(path, sheet):
    ws = openpyxl.load_workbook(os.path.join(OUT, path), read_only=True)[sheet]
    return [r for r in ws.iter_rows(values_only=True)]


# ---- 各任务的 summary（Q3 四策略 / Q4 四口径 / 两个 K=8）----
TAGS = ['q3b_S0', 'q3b_S1', 'q3b_S2', 'q3b_S3', 'q3b_S3k8',
        'q4_Q4-2', 'q4_Q4-3', 'q4_Q4-2k8', 'q4_Q4-3k8',
        'q4_Q4-2Ideal', 'q4_Q4-2P0', 'q4_Q4-3P0', 'q2c_L2', 'q2c_L2k8']
for t in TAGS:
    d = S(t)
    if d:
        V[t] = d

# ---- 问题二（结构不同，逐日量按 334 天窗口汇总）----
p2 = os.path.join(OUT, 'final_results_q2c_L2.mat')
if os.path.exists(p2):
    import scipy.io as sio
    d = sio.loadmat(p2, squeeze_me=True, struct_as_record=True)
    prm, res = d['prm'], d['res']
    dt = float(np.ravel(prm['dt'])[0])
    # 该文件为全部 365 天各算一遍，只有掩码标记的 334 天属于报送窗口；
    # 论文口径一律按报送窗口汇总，故先取掩码再算。
    #
    # 单位已核（对照 Q3 汇总结构体的 em_win/curt_win/waste_win 三值，比值恰为 1.0000）：
    # em_m / curt_m / waste_m / chg_m / dis_m 均已是**每时段 kWh**，不再乘 dt。
    ok = np.ravel(res['ok'][()]).astype(bool)
    pick = lambda k: np.ravel(res[k][()])[ok]
    em_m = res['em_m'][()][ok]                       # (334,144)
    V['q2'] = {
        'dt': dt,
        'n_day': int(ok.sum()),
        'day0': int(np.flatnonzero(ok)[0]) + 1,
        'Z': float(np.nansum(pick('cost'))),
        'cost_plan': float(np.nansum(pick('cost_plan'))),
        'cost_em': float(np.nansum(pick('cost_em'))),
        'em_win': float(np.nansum(em_m)),
        'curt_win': float(np.nansum(res['curt_m'][()][ok])),
        'waste_win': float(np.nansum(res['waste_m'][()][ok])),
        'chg_win': float(np.nansum(res['chg_m'][()][ok])),
        'Eend_mean': float(np.mean(res['Eend_m'][()][ok][:, -1])),
        'max_viol': float(np.nanmax(pick('viol'))),
        'max_gap': float(np.nanmax(pick('gap'))),
        'em_days': int(np.sum(em_m.sum(1) > 1e-6)),
    }

# ---- 问题四的价格预测精度（在 Q4-3 的 prc 结构里）----
#
# ⚠️ 口径提醒：outputs/测试记录/preprocess_log_q4.txt 里另有一套命中率
#    （38.8% / 34.1%，MAE 0.0480），那是**开工前探针**用早期预测法算的，不是生产口径。
#    论文一律引用此处由生产运行的中心预测 pi_hat0 重算的值。
p4 = os.path.join(OUT, 'final_results_q4_Q4-3.mat')
if os.path.exists(p4):
    with h5py.File(p4, 'r') as f:
        if 'prc' in f:
            prc = f['prc']
            ok = np.array(prc['ok']).ravel().astype(bool)
            hat = np.array(prc['pi_hat0'])[:, ok]          # 中心预测（生产运行）
            act = np.array(prc['price_act'])[:, ok]        # 实际价格
            base = np.array(prc['pi_base'])[:, ok]         # 基准：附件 1 典型日曲线
            ip_h, ip_a = hat.argmax(0), act.argmax(0)
            iv_h, iv_a = hat.argmin(0), act.argmin(0)
            sph, spa = hat.max(0) - hat.min(0), act.max(0) - act.min(0)
            V['price'] = {
                'n_day': int(ok.sum()),
                'MAE': float(np.mean(np.abs(hat - act))),
                'MAE_base': float(np.mean(np.abs(base - act))),
                'RMSE': float(np.sqrt(np.mean((hat - act) ** 2))),
                'peak_hit': float(np.mean(ip_h == ip_a)),
                'valley_hit': float(np.mean(iv_h == iv_a)),
                'peak_hit_1h': float(np.mean(np.abs(ip_h - ip_a) <= 6)),
                'valley_hit_1h': float(np.mean(np.abs(iv_h - iv_a) <= 6)),
                'spread_MAE': float(np.mean(np.abs(sph - spa))),
                'spread_act_mean': float(spa.mean()),
            }

json.dump(V, open(os.path.join(HERE, 'values.json'), 'w'), indent=1, sort_keys=True,
          default=float)

# ---- 可读清单 ----
KEY = ['cost_win', 'cost_normal_win', 'cost_em_win', 'em_win', 'em_days',
       'adj_up', 'adj_dn', 'curt_win', 'waste_win', 'charge_win',
       'Eend_mean', 'max_viol', 'max_gap', 'max_replay', 'K', 'time_min']
print('%-14s %s' % ('任务', ' '.join('%12s' % k[:12] for k in KEY)))
for t in TAGS:
    if t not in V:
        print('%-14s <缺>' % t)
        continue
    print('%-14s %s' % (t, ' '.join('%12.4f' % V[t].get(k, float('nan')) for k in KEY)))
if 'price' in V:
    print('价格精度: %s' % V['price'])
print('\n已写 paper/values.json')
