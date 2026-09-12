#!/usr/bin/env bash
# 2026C_formal 问题二第三轮（预测层偏差校正）一键运行脚本
# 顺序：中间基线 M1 → 四方案 B0~B3（单 MATLAB 会话内顺序执行，禁并发）
# 用法：bash run_q2b.sh [m1|b|all]   默认 all
set -u
cd "$(dirname "$0")"
which=${1:-all}
LOG=outputs/log_q2b_run.txt
mkdir -p outputs

run_one () {
  echo "=== $1 开始 $(date '+%F %T') ===" >> "$LOG"
  matlab -batch "run('$1')" >> "$LOG" 2>&1
  echo "=== $1 exit=$? 结束 $(date '+%F %T') ===" >> "$LOG"
}

if [ "$which" = "m1" ] || [ "$which" = "all" ]; then
  run_one "scripts/cmp_q2_timefix.m"
fi

if [ "$which" = "b" ] || [ "$which" = "all" ]; then
  run_one "src/main_q2b.m"
fi

echo "完成，日志：$LOG"
