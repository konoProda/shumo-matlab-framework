#!/usr/bin/env bash
# 2026C_formal 问题三 正式运行一键脚本（后台串行，约 1 小时）
# 用法：bash run_q3_report.sh [main|nocorr|sens|all]   默认 all
# 顺序：正式口径 → 消融对照 → 预报使用策略对照（S0~S3）
set -u
cd "$(dirname "$0")"
which=${1:-all}
LOG=outputs/log_q3_run.txt
mkdir -p outputs

run_one () {
  local entry="$1"
  echo "=== $entry 开始 $(date '+%F %T') ===" >> "$LOG"
  matlab -batch "run('src/$entry.m')" >> "$LOG" 2>&1
  local rc=$?
  echo "=== $entry 结束 $(date '+%F %T')  exit=$rc ===" >> "$LOG"
  return $rc
}

case "$which" in
  main)   run_one main_q3 ;;
  nocorr) run_one main_q3_nocorr ;;
  sens)   run_one main_q3_sens ;;
  all)
    echo "=== 问题三 正式运行开始 $(date '+%F %T') ===" >> "$LOG"
    run_one main_q3
    run_one main_q3_nocorr
    run_one main_q3_sens
    echo "=== 全部完成 $(date '+%F %T') ===" >> "$LOG"
    ;;
  *) echo "用法：bash run_q3_report.sh [main|nocorr|sens|all]"; exit 1 ;;
esac
echo "日志：$LOG"
