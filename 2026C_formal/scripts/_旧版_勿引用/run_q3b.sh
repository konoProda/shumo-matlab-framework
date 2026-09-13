#!/usr/bin/env bash
# 2026C_formal 问题三第二版（多时点预报更新 + 多阶段滚动 SAA-MILP）一键运行脚本
# 单 MATLAB 会话内顺序执行五组（S0 / S3 / S2 / S1 / S3k8），3.9 GB 环境禁止并发
#
# 与前几轮同样的防护：每组每 10 天（K=8 每 5 天）存断点，被杀后自断点继续；
# 本脚本自动重试，连续两次无断点写入（疑似代码错误而非随机被杀）即停止。
# 用法：setsid nohup bash run_q3b.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
LOG=outputs/log_q3b_run.txt
mkdir -p outputs

MAX_TRY=${Q3B_MAX_TRY:-10}
echo "=== main_q3b 开始 $(date '+%F %T')（最多重试 ${MAX_TRY} 次，被杀后自断点续跑）===" >> "$LOG"

stall=0
for i in $(seq 1 "$MAX_TRY"); do
    t0=$(date +%s)
    matlab -batch "addpath(genpath('src')); main_q3b" >> "$LOG" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "=== main_q3b 第 ${i} 次尝试成功，exit=0 结束 $(date '+%F %T') ===" >> "$LOG"
        break
    fi
    sleep 3
    nprog=$(find outputs -name 'ckpt_q3b_*.mat' -newermt "@${t0}" 2>/dev/null | wc -l)
    if [ "$nprog" -eq 0 ]; then stall=$((stall+1)); else stall=0; fi
    echo "=== 第 ${i} 次尝试中断 exit=${rc}（137=内存不足被内核杀死）$(date '+%F %T')，本次写入断点 ${nprog} 个，自断点续跑 ===" >> "$LOG"
    if [ "$stall" -ge 2 ]; then
        echo "=== 连续两次无断点写入（疑似代码错误或固定卡点），停止重试 $(date '+%F %T') ===" >> "$LOG"
        break
    fi
    sleep 5
done
echo "完成，日志：$LOG"
