#!/usr/bin/env bash
# run_q4k8.sh —— 只补问题四的 K=8 稳定性（问题三 S3k8 已于 2026-09-13 14:40 完成）
#
#   main_q4 一次调用会把本问全部剩余任务跑完才退出；Q4-2 / Q4-3 / P0 系列 / Ideal
#   都已完成，因此这里实际只会推进 Q4-2k8 与 Q4-3k8。断点续跑，打断即暂停。
#
#   用法：setsid nohup bash scripts/sched/run_q4k8.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
L4=outputs/log_q4_run.txt
echo "=== [Q4k8] 调度启动 $(date '+%F %T') ===" >> "$L4"
for i in $(seq 1 12); do
    echo "=== [Q4k8] main_q4 起，上限 3300s  $(date '+%F %T') ===" >> "$L4"
    timeout 3300 matlab -batch "addpath(genpath('src')); main_q4" >> "$L4" 2>&1
    echo "=== [Q4k8] main_q4 止（exit=$?）$(date '+%F %T') ===" >> "$L4"
done
echo "=== [Q4k8] 调度结束 $(date '+%F %T') ===" >> "$L4"
