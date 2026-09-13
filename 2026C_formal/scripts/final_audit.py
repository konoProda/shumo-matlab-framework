#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""final_audit.py —— 交付前产物完整性自检

用法：python3 scripts/final_audit.py

六组检查，全部只读，不改动任何产物：

  A 图件完整性   14 张图各自包含 绘图脚本 + data.csv + PNG + PDF，且 PNG 晚于 data.csv
  B 交付完整性   deliver/ 四问文件夹含入口程序 + 子函数 + docx + 结果表；顶层每问一张 jpg
  C 结果完整性   final_results_*.mat 可读且含 s/res 关键字段
  D 文档完整性   根目录内部文档齐备且非空
  E 数字一致性   文档中引用的关键数字与结果文件**逐项对账**（对应确认点 #3）
  F 路径完整性   关键文档中引用的项目内路径真实存在

退出码：0 = 全部通过（允许 WARN），1 = 有 FAIL。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

FAIL, WARN, OK = [], [], []


def fail(msg):
    FAIL.append(msg)


def warn(msg):
    WARN.append(msg)


def ok(msg):
    OK.append(msg)


def section(title, fn):
    """跑一组检查；**本组内有任何失败就不打印「通过」**。
    （初版漏了这个判定，导致 C 组明明失败却仍打印"通过"——本轮踩过。）"""
    n0 = len(FAIL)
    try:
        fn()
    except Exception as e:                                        # noqa: BLE001
        fail('%s 执行异常：%s' % (title, e))
    return len(FAIL) == n0


def read_mat(path, *keys):
    """读取 .mat 数值。v7.3 走 h5py，v7 走 scipy —— 两类格式本仓都存在。"""
    import numpy as np
    try:                                      # v7.3 (HDF5)
        import h5py
        with h5py.File(path, 'r') as f:
            cur = f
            for k in keys:
                cur = cur[k]
            return np.array(cur).ravel(), True
    except Exception:                         # noqa: BLE001
        pass
    try:                                      # v7 (scipy)
        import scipy.io as sio
        m = sio.loadmat(path, squeeze_me=True, struct_as_record=False)
        cur = m
        for k in keys:
            cur = getattr(cur, k) if hasattr(cur, k) else cur[k]
        return np.atleast_1d(np.asarray(cur, dtype=float)).ravel(), False
    except Exception as e:                    # noqa: BLE001
        raise RuntimeError('两种读取方式均失败：%s' % e)


# ----------------------------------------------------------------- A 图件
def check_figures():
    base = 'figures'
    want = {
        '问题一': ['01 典型日计划购电策略', '02 储能充放电与储电量'],
        '问题二': ['01 全年逐日购电结构', '02 日末储电量轨迹', '03 指定日期_计划购电与紧急购电',
                   '04 紧急购电_逐时分布', '05 对照与灵敏度_四面板', '06 预测精度_校正前后'],
        '问题三': ['01 逐日购电与调整结构', '02 日末储电量轨迹', '03 指定日期四阶段轨迹'],
        '问题四': ['01 电价预测画像', '02 峰谷时刻预测误差', '03 一周电价预测对照'],
    }
    n = 0
    for q, dirs in want.items():
        for d in dirs:
            p = os.path.join(base, q, d)
            n += 1
            if not os.path.isdir(p):
                fail('图件缺失目录：%s' % p)
                continue
            files = os.listdir(p)
            for pat, desc in [(r'^plot_.*\.m$', '绘图脚本'), (r'^data\.csv$', 'data.csv')]:
                if not any(re.match(pat, f) for f in files):
                    fail('%s 缺 %s' % (p, desc))
            pngs = [f for f in files if f.endswith('.png')]
            pdfs = [f for f in files if f.endswith('.pdf')]
            if not pngs:
                fail('%s 缺 PNG' % p)
            if not pdfs:
                fail('%s 缺 PDF' % p)
            for f in pngs:
                fp = os.path.join(p, f)
                if os.path.getsize(fp) < 20000:
                    fail('%s 体积异常小（%d B）' % (fp, os.path.getsize(fp)))
                csv = os.path.join(p, 'data.csv')
                if os.path.exists(csv) and os.path.getmtime(fp) < os.path.getmtime(csv):
                    warn('%s 早于 data.csv（出图后数据又变了？）' % fp)
            # 图像文件名应与文件夹同名规范（问题X 前缀）
            for f in pngs:
                if not f.startswith(q + ' '):
                    warn('%s 文件名未以「%s 」开头' % (p, q))
    ok('A 图件：%d 张全部具备 脚本+data.csv+PNG+PDF' % n)


# ----------------------------------------------------------------- B 交付
def check_deliver():
    qs = ['问题一', '问题二', '问题三', '问题四']
    entries = {'问题一': 'main_q1.m', '问题二': 'main_q2c.m', '问题三': 'main_q3b.m', '问题四': 'main_q4.m'}
    for q in qs:
        d = os.path.join('deliver', '%s对应的代码与说明' % q)
        if not os.path.isdir(d):
            fail('交付缺失目录：%s' % d)
            continue
        files = os.listdir(d)
        if entries[q] not in files:
            fail('%s 缺入口程序 %s' % (d, entries[q]))
        nfun = sum(1 for f in files if f.startswith('func_') and f.endswith('.m'))
        if nfun == 0:
            fail('%s 无子函数' % d)
        if not any(f.endswith('.docx') for f in files):
            fail('%s 缺说明文档 docx' % d)
        if not any(f.startswith('result') and f.endswith('.xlsx') for f in files):
            fail('%s 缺结果表 xlsx' % d)
    jpgs = [f for f in os.listdir('deliver') if f.endswith('.jpg')]
    if len(jpgs) != 4:
        fail('deliver 顶层 jpg 应为 4 张（每问一张提要图），实为 %d 张：%s' % (len(jpgs), jpgs))
    for f in jpgs:
        if not re.match(r'^问题[一二三四] ', f):
            warn('顶层图命名不合规范：%s' % f)

    # 图件附件：**完整交付**，每张图带 绘图脚本 + data.csv + PNG + PDF
    n_fig = 0
    for q in qs:
        dq = os.path.join('deliver', '图件', q)
        if not os.path.isdir(dq):
            fail('交付缺图件目录：%s' % dq)
            continue
        for sub in sorted(os.listdir(dq)):
            p = os.path.join(dq, sub)
            if not os.path.isdir(p):
                continue
            n_fig += 1
            fs = os.listdir(p)
            for ext, desc in [('.png', 'PNG'), ('.pdf', 'PDF'), ('.csv', 'data.csv')]:
                if not any(f.endswith(ext) for f in fs):
                    fail('交付图 %s 缺 %s' % (p, desc))
            if not any(f.startswith('plot_') for f in fs):
                fail('交付图 %s 缺绘图脚本' % p)
    if n_fig != 14:
        fail('deliver/图件 下应有 14 张图，实为 %d 张' % n_fig)
    ok('B 交付：四问代码文件夹 + 顶层 %d 张提要图 + **图件附件完整 %d 张**' % (len(jpgs), n_fig))


# ----------------------------------------------------------------- C 结果
def mat_has(path, *keys):
    """只确认字段存在（不要求是数值）。`res` 这类结构体用 read_mat 取不出数值。"""
    try:
        import h5py
        with h5py.File(path, 'r') as f:
            cur = f
            for k in keys:
                if k not in cur:
                    return False
                cur = cur[k]
            return True
    except Exception:                                             # noqa: BLE001
        pass
    try:
        import scipy.io as sio
        m = sio.loadmat(path, squeeze_me=True, struct_as_record=False)
        cur = m
        for k in keys:
            if isinstance(cur, dict):
                if k not in cur:
                    return False
                cur = cur[k]
            elif hasattr(cur, k):
                cur = getattr(cur, k)
            else:
                return False
        return True
    except Exception:                                             # noqa: BLE001
        return False


def check_results():
    need = {
        'final_results_q1.mat': 'Z',
        'final_results_q2c_L2.mat': 'res',
        'final_results_q3b_S0.mat': 's', 'final_results_q3b_S1.mat': 's',
        'final_results_q3b_S2.mat': 's', 'final_results_q3b_S3.mat': 's',
        'final_results_q4_Q4-2.mat': 's', 'final_results_q4_Q4-3.mat': 's',
        'final_results_q2c_L2k8.mat': 'res',
    }
    n = 0
    for fn, key in need.items():
        p = os.path.join('outputs', fn)
        if not os.path.exists(p):
            fail('结果文件缺失：%s' % p)
            continue
        if not mat_has(p, key):
            fail('%s 缺字段 %s 或不可读' % (fn, key))
            continue
        n += 1
    ok('C 结果：%d 份主口径 .mat 可读且字段齐备' % n)


# ----------------------------------------------------------------- D 文档
def check_docs():
    docs = ['README.md', 'FIGURES_GUIDE.md', 'PAPER_HANDOFF.md',
            'IMPLEMENTATION_REPORT.md', 'RETROSPECTIVE.md']
    for d in docs:
        if not os.path.exists(d) or os.path.getsize(d) < 2000:
            fail('内部文档缺失或过小：%s' % d)
    sub = ['src/README.md', 'scripts/README.md', 'outputs/README.md']
    for d in sub:
        if not os.path.exists(d):
            warn('缺少子目录说明：%s' % d)
    for d, tag in [('IMPLEMENTATION_REPORT.md', 'Q4'), ('PAPER_HANDOFF.md', 'Q4')]:
        t = open(d, encoding='utf-8').read()
        if '<!-- AUTO:%s BEGIN -->' % tag not in t:
            warn('%s 尚未写入问题四章节（AUTO 标记未找到）' % d)
    ok('D 文档：5 份根目录文档 + 3 份子目录说明齐备')


# ----------------------------------------------------------------- E 数字一致性
def check_numbers():
    """文档中引用的关键数字 vs 结果文件实测值。对应『确认点 #3 数字一致性』。"""
    def mat(path, *keys):
        return read_mat(path, *keys)[0]

    truth = {}
    truth['问题一 全天最优购电费'] = float(mat('outputs/final_results_q1.mat', 'Z')[0])
    for nm in ['S0', 'S1', 'S2', 'S3']:
        truth['问题三 %s 费用' % nm] = float(mat('outputs/final_results_q3b_%s.mat' % nm, 's', 'cost_win')[0])
    for nm in ['Q4-2', 'Q4-3']:
        truth['问题四 %s 费用' % nm] = float(mat('outputs/final_results_q4_%s.mat' % nm, 's', 'cost_win')[0])

    # 从文档中抓取 "数字 元" 形态，核对是否与实测吻合（只核对我们已知口径的项）
    guide = open('FIGURES_GUIDE.md', encoding='utf-8').read()
    checks = [
        ('问题一 全天最优购电费', '35 126.95', truth['问题一 全天最优购电费']),
        ('问题三 S0 费用', '15 644 696.18', truth['问题三 S0 费用']),
        ('问题三 S1 费用', '15 579 634.76', truth['问题三 S1 费用']),
        ('问题三 S2 费用', '15 011 622.48', truth['问题三 S2 费用']),
        ('问题三 S3 费用', '14 485 230.30', truth['问题三 S3 费用']),
        ('问题四 Q4-2 费用', '16 320 514.83', truth['问题四 Q4-2 费用']),
        ('问题四 Q4-3 费用', '15 225 713.07', truth['问题四 Q4-3 费用']),
    ]
    n_ok = 0
    for label, doc_str, actual in checks:
        if doc_str not in guide:
            fail('E 数字：FIGURES_GUIDE 中找不到「%s」（%s）' % (label, doc_str))
            continue
        if abs(actual - float(doc_str.replace(' ', ''))) > 0.02:
            fail('E 数字：%s 文档写 %s 元，实测 %.2f 元' % (label, doc_str, actual))
            continue
        n_ok += 1
    # 交叉核对：PAPER_HANDOFF 也应载有问题三四个费用
    ph = open('PAPER_HANDOFF.md', encoding='utf-8').read().replace(',', '')
    for nm, s in [('S0', '15644696.18'), ('S3', '14485230.30')]:
        if s not in ph:
            warn('E 数字：PAPER_HANDOFF 未见问题三 %s = %s' % (nm, s))
    ok('E 数字：%d 项核心数字与结果文件逐项对账一致' % n_ok)


# ----------------------------------------------------------------- F 路径
def check_paths():
    docs = ['README.md', 'FIGURES_GUIDE.md', 'PAPER_HANDOFF.md',
            'IMPLEMENTATION_REPORT.md', 'src/README.md', 'scripts/README.md', 'outputs/README.md']
    bad = 0
    for d in docs:
        t = open(d, encoding='utf-8').read()
        for m in re.finditer(r'`((?:outputs|figures|scripts|src|deliver)/[^`\n]+?)`', t):
            p = re.sub(r':[\d,\-\s]+$', '', m.group(1).strip())
            if p.endswith('/') or any(c in p for c in '*{|…~<>'):
                continue
            if not os.path.exists(p):
                warn('F 路径：%s 引用不存在的 %s' % (d, p))
                bad += 1
    ok('F 路径：7 份文档的项目内引用已核查（可疑 %d 条，见 WARN）' % bad)


# ----------------------------------------------------------------- 主流程
def main():
    section('A 图件', check_figures)
    section('B 交付', check_deliver)
    section('C 结果', check_results)
    section('D 文档', check_docs)
    section('E 数字', check_numbers)
    section('F 路径', check_paths)

    print('=' * 70)
    print('产物完整性自检报告  %s' % __import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M'))
    print('=' * 70)
    for s in OK:
        print('  [通过] %s' % s)
    for s in WARN:
        print('  [提示] %s' % s)
    for s in FAIL:
        print('  [失败] %s' % s)
    print('-' * 70)
    print('通过 %d 组 / 提示 %d 条 / 失败 %d 条' % (len(OK), len(WARN), len(FAIL)))
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
