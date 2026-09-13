#!/usr/bin/env bash
# stop_after_ideal.sh —— 等 P0/Ideal 两组产物落地后，停掉调度与 MATLAB，把单会话让给后处理。
#
#   为什么需要它：main_q4 一次调用会把**它自己的全部剩余任务**跑完才退出
#   （P0 → Ideal → K=8 稳定性）。本阶段只想要前两者，故派一个廉价看门进程盯着，
#   产物一到就停 MATLAB，避免稳定性检验抢走后面要用的会话时间。
#
#   ⚠️ 杀进程一律用 **PID**，不用 `pkill -f <文本>`：
#      本轮已三次因杀进程模式串出现在**本进程自己的命令行里**而误杀自身
#      （bash 的 -c 参数会把整个脚本正文、包括 heredoc 正文，都放进 argv）。
#      这里只用 `pgrep -x MATLAB`（按进程名精确匹配），它不可能匹配到 bash。
#
#   用法：setsid nohup bash scripts/sched/stop_after_ideal.sh >/dev/null 2>&1 < /dev/null &
set -u
cd "$(dirname "$0")/../.."
for i in $(seq 1 320); do
    if [ -f outputs/final_results_q4_Q4-3P0.mat ] && [ -f outputs/final_results_q4_Q4-2Ideal.mat ]; then
        sleep 5                                   # 留给 MATLAB 落盘
        for p in $(pgrep -x MATLAB); do kill "$p" 2>/dev/null; done
        sleep 6
        for p in $(pgrep -x MATLAB); do kill -9 "$p" 2>/dev/null; done
        for p in $(pgrep -f 'run_p0'); do kill "$p" 2>/dev/null; done
        echo "P0/Ideal 已完成，MATLAB 与调度已停（等待 $((i*15))s）" >> outputs/log_q4_run.txt
        exit 0
    fi
    sleep 15
done
echo "stop_after_ideal 超时：未见 Q4-3P0 与 Q4-2Ideal 两个产物" >> outputs/log_q4_run.txt
