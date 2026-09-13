#!/usr/bin/env bash
# run_final.sh —— 收尾调度（2026-09-13 编程手裁定）
#
#   取代 run_tail.sh，只改**顺序**与**加入 S1 重解**：
#     ① 先重解问题三 S1 —— 修掉机器休眠造成的第 312 天未解到最优（详见 RETROSPECTIVE R18/R22）
#     ② 再补问题四的评价性对照（P0 消融 / 完美价格信息基准）
#     ③ 两项稳定性检验**都排最后**（编程手裁定：问题三、问题四的稳定性检验均放最后）
#
#   两个 main 脚本都会跳过已完成分组、并从各自断点续跑；全部完成后循环轮次空转秒退。
#
#   用法：setsid nohup bash scripts/sched/run_final.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
mkdir -p outputs
L3=outputs/log_q3b_run.txt
L4=outputs/log_q4_run.txt

run4() { echo "=== [收尾] main_q4 起，上限 ${1}s  $(date '+%F %T') ===" >> "$L4"
         timeout "$1" matlab -batch "addpath(genpath('src')); main_q4" >> "$L4" 2>&1
         echo "=== [收尾] main_q4 止（exit=$?）$(date '+%F %T') ===" >> "$L4"; }
run3() { echo "=== [收尾] main_q3b 起，上限 ${1}s  $(date '+%F %T') ===" >> "$L3"
         timeout "$1" matlab -batch "addpath(genpath('src')); main_q3b" >> "$L3" 2>&1
         echo "=== [收尾] main_q3b 止（exit=$?）$(date '+%F %T') ===" >> "$L3"; }

echo "=== run_final 启动 $(date '+%F %T') ===" >> "$L3"

# ① 问题三 S1 重解：机器休眠使第 312 天的 MaxTime 未按墙钟触发，留下 274 032 元间隙。
#    机器现已清醒，重解预期可解到最优（该组其余 729 次求解耗时均 ≤ 3.7 s）。
#    注意：环境变量必须写在 timeout 之前（函数调用形式的 `VAR=x func` 在 bash 下语义易混淆）。
echo "=== [收尾] main_q3b（强制重跑 S1）起，上限 3600s  $(date '+%F %T') ===" >> "$L3"
Q3B_FORCE=S1 timeout 3600 matlab -batch "addpath(genpath('src')); main_q3b" >> "$L3" 2>&1
echo "=== [收尾] main_q3b（S1 重解）止（exit=$?）$(date '+%F %T') ===" >> "$L3"

# ② 问题四：价格中心预测消融（P0）与完美价格信息基准（Ideal）——直接支撑论文评价段
run4 6000

# ③ 稳定性检验：两项均排最后（编程手 2026-09-13 裁定）
for i in $(seq 1 8); do run3 3000; done   # 问题三 S3k8
for i in $(seq 1 8); do run4 3000; done   # 问题四 K=8

echo "=== run_final 结束 $(date '+%F %T') ===" >> "$L3"
