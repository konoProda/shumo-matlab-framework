#!/usr/bin/env bash
# 2026C_formal 问题二第三轮（7 日滚动 SAA 两阶段 MILP）一键运行脚本
# 单 MATLAB 会话内顺序执行六组运行（3 GB 环境，禁止并发）
#
# 本机 MATLAB 常驻约 0.8 GB、满载约 3 GB，而物理内存仅 3.9 GB，
# 高负载时会被内核 OOM 杀掉（实测 exit=137）。故：
#   ① 每组运行每 20 天存一次断点，被杀后自断点继续，不从头再来；
#   ② 本脚本自动重试，直至某一组成功退出；
#   ③ 连续两次重试均无断点写入（说明是代码错误或固定卡点，不是随机被杀）即停止。
# 用法：setsid nohup bash run_q2c.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")"
LOG=outputs/log_q2c_run.txt
mkdir -p outputs

MAX_TRY=${Q2C_MAX_TRY:-8}
echo "=== main_q2c 开始 $(date '+%F %T')（最多重试 ${MAX_TRY} 次，被杀后自断点续跑）===" >> "$LOG"

stall=0
for i in $(seq 1 "$MAX_TRY"); do
    t0=$(date +%s)
    matlab -batch "run('src/main_q2c.m')" >> "$LOG" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "=== main_q2c 第 ${i} 次尝试成功，exit=0 结束 $(date '+%F %T') ===" >> "$LOG"
        break
    fi
    sleep 2
    # 本次尝试内是否有断点写入（= 真的往前跑了）
    nprog=$(find outputs -name 'ckpt_q2c_*.mat' -newermt "@${t0}" 2>/dev/null | wc -l)
    if [ "$nprog" -eq 0 ]; then stall=$((stall+1)); else stall=0; fi
    echo "=== 第 ${i} 次尝试中断 exit=${rc}（137=内存不足被内核杀死）$(date '+%F %T')，本次写入断点 ${nprog} 个，自断点续跑 ===" >> "$LOG"
    if [ "$stall" -ge 2 ]; then
        echo "=== 连续两次无断点写入（疑似代码错误或固定卡点），停止重试 $(date '+%F %T') ===" >> "$LOG"
        break
    fi
    sleep 5
done
echo "完成，日志：$LOG"
