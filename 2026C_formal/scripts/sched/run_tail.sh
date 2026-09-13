#!/usr/bin/env bash
# run_tail.sh —— 收尾调度（2026-09-13 编程手裁定：问题三稳定性检验排最后）
#
#   与 run_all.sh 的差别只有一处**顺序**：run_all 先跑 Q3b 再跑 Q4，而问题三的 S3k8
#   稳定性检验会被排到最前面；现按裁定改成"先补问题四的评价性对照与稳定性，
#   问题三的稳定性放到全部工作之后"。
#
#   两个 main 脚本都会跳过已完成分组、并从各自断点续跑，因此被 timeout 打断
#   只是一次"暂停—恢复"，最多损失一个断点间隔的进度；全部完成后循环轮次会空转秒退。
#
#   用法：setsid nohup bash scripts/sched/run_tail.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
mkdir -p outputs
L3=outputs/log_q3b_run.txt
L4=outputs/log_q4_run.txt

run4() { echo "=== [收尾调度] main_q4 起，上限 ${1}s  $(date '+%F %T') ===" >> "$L4"
         timeout "$1" matlab -batch "addpath(genpath('src')); main_q4" >> "$L4" 2>&1
         echo "=== [收尾调度] main_q4 止（exit=$?）$(date '+%F %T') ===" >> "$L4"; }
run3() { echo "=== [收尾调度] main_q3b 起，上限 ${1}s  $(date '+%F %T') ===" >> "$L3"
         timeout "$1" matlab -batch "addpath(genpath('src')); main_q3b" >> "$L3" 2>&1
         echo "=== [收尾调度] main_q3b 止（exit=$?）$(date '+%F %T') ===" >> "$L3"; }

echo "=== run_tail 启动 $(date '+%F %T') ===" >> "$L3"

# ① 问题四：价格中心预测消融（P0）与完美价格信息基准（Ideal）——直接支撑论文评价段
run4 6000

# ② 问题四：K=8 稳定性
for i in $(seq 1 6); do run4 3000; done

# ③ 最后：问题三 K=8 稳定性（S3k8）
for i in $(seq 1 8); do run3 3000; done

echo "=== run_tail 结束 $(date '+%F %T') ===" >> "$L3"
