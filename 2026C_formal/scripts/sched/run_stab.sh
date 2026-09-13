#!/usr/bin/env bash
# run_stab.sh —— 稳定性检验专用调度（两项都排在最后，2026-09-13 编程手裁定）
#
#   ① 问题三 S3k8（四个时点全用 × 8 情景）
#   ② 问题四 Q4-2k8 / Q4-3k8
#
#   本阶段**交付面已经定稿**，稳定性只影响论文"稳健性"章节的措辞，
#   不改变任何已交付数字。两个 main 脚本会跳过已完成分组、断点续跑，
#   全部完成后循环轮次空转秒退。
#
#   用法：setsid nohup bash scripts/sched/run_stab.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
L3=outputs/log_q3b_run.txt
L4=outputs/log_q4_run.txt

run3() { echo "=== [稳定性] main_q3b 起，上限 ${1}s  $(date '+%F %T') ===" >> "$L3"
         timeout "$1" matlab -batch "addpath(genpath('src')); main_q3b" >> "$L3" 2>&1
         echo "=== [稳定性] main_q3b 止（exit=$?）$(date '+%F %T') ===" >> "$L3"; }
run4() { echo "=== [稳定性] main_q4 起，上限 ${1}s  $(date '+%F %T') ===" >> "$L4"
         timeout "$1" matlab -batch "addpath(genpath('src')); main_q4" >> "$L4" 2>&1
         echo "=== [稳定性] main_q4 止（exit=$?）$(date '+%F %T') ===" >> "$L4"; }

echo "=== run_stab 启动 $(date '+%F %T') ===" >> "$L3"
for i in $(seq 1 10); do
    run3 3300      # 问题三 S3k8
    run4 3300      # 问题四 Q4-2k8 / Q4-3k8
done
echo "=== run_stab 结束 $(date '+%F %T') ===" >> "$L3"
