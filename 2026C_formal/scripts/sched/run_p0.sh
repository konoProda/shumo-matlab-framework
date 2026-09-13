#!/usr/bin/env bash
# run_p0.sh —— 只补问题四的评价性对照（P0 消融 + 完美价格信息基准），跑完即止。
#
#   为什么单独一个脚本：main_q4 一次调用会把**它自己的全部剩余任务**跑完才退出，
#   包括排在最后的 K=8 稳定性。本阶段要让 P0/Ideal 尽快齐备、稳定性让路，
#   故只给它一个"跑主口径与评价性对照"的窗口，稳定性另行调度。
#
#   用法：setsid nohup bash scripts/sched/run_p0.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
L4=outputs/log_q4_run.txt
echo "=== [P0] main_q4 起，上限 6000s  $(date '+%F %T') ===" >> "$L4"
timeout 6000 matlab -batch "addpath(genpath('src')); main_q4" >> "$L4" 2>&1
echo "=== [P0] main_q4 止（exit=$?）$(date '+%F %T') ===" >> "$L4"
