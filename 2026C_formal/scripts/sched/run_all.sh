#!/usr/bin/env bash
# 2026C_formal 第三、四问 统一调度器
#
# 为什么需要它：问题三与问题四各自的 main 脚本会把自己那一问全部跑完才轮到对方，
# 而两问都有"必须交付"的主口径。按价值序，应先把**四份主口径**都拿到手，再补分析与稳定性。
#
# 做法：给每次调用加时间上限，交替调度两个 main 脚本。
#   两个 main 脚本都会**跳过已完成的分组**、并从断点续跑，因此被 timeout 打断只是一次
#   正常的"暂停—恢复"，最多损失一个断点间隔（10 天 / K=8 时 5 天）的进度。
#
# 排序依据（decisions 系列 + 先行订对报告的机时计划）：
#   ① Q3b 的 S0（最便宜，且端到端验证管线）与 S3（问题三正式交付口径）
#   ② Q4-2 与 Q4-3（问题四两份正式交付）
#   ③ Q3b 的 S2 / S1（题目"是否需要其他时刻预报"的核心分析）
#   ④ Q4 的 P0 消融与完美价格基准（评价性计算）
#   ⑤ 三组 K=8 稳定性（放最后；机时不足则按实现报告如实记录未做范围）
#
# 用法：setsid nohup bash run_all.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
mkdir -p outputs
L3=outputs/log_q3b_run.txt
L4=outputs/log_q4_run.txt
STAMP=$(date '+%F %T')

run3() { echo "=== [调度] main_q3b 起，上限 ${1}s  $STAMP ===" >> "$L3"; timeout "$1" matlab -batch "addpath(genpath('src')); main_q3b" >> "$L3" 2>&1; echo "=== [调度] main_q3b 止（exit=$?）$(date '+%F %T') ===" >> "$L3"; }
run4() { echo "=== [调度] main_q4 起，上限 ${1}s  $(date '+%F %T') ===" >> "$L4"; timeout "$1" matlab -batch "addpath(genpath('src')); main_q4" >> "$L4" 2>&1; echo "=== [调度] main_q4 止（exit=$?）$(date '+%F %T') ===" >> "$L4"; }

echo "=== run_all 启动 $STAMP ===" >> "$L3"

# 第一轮：先把两问的主口径各拿到手
run3 6600      # Q3b：S0 + S3
run4 6000      # Q4：Q4-2 + Q4-3
run3 6600      # Q3b：S2 + S1
run4 3600      # Q4：Q4-2P0 + Q4-3P0 + Q4-2Ideal

# 第二轮起：稳定性与剩余项，交替推进直到全部完成或到点
for i in $(seq 1 20); do
    run3 2400
    run4 2400
done

echo "=== run_all 结束 $(date '+%F %T') ===" >> "$L3"
