#!/usr/bin/env bash
# 2026C_formal 问题三 图件批量生成脚本
# 用法：bash run_q3_figures.sh [data|plots|all]   默认 all
set -u
cd "$(dirname "$0")"
which=${1:-all}
LOG=outputs/log_q3_fig.txt
mkdir -p outputs

run_one () {
  echo "=== $1 开始 $(date '+%F %T') ===" >> "$LOG"
  matlab -batch "run('$1')" >> "$LOG" 2>&1
  echo "=== $1 exit=$? ===" >> "$LOG"
}

if [ "$which" = "data" ] || [ "$which" = "all" ]; then
  for s in data_q3_skill data_q3_bias data_q3_tariff data_q3_cost data_q3_days \
           data_q3_adj data_q3_em data_q3_soc data_q3_stage data_q3_sens; do
    run_one "scripts/$s.m"
  done
fi

if [ "$which" = "plots" ] || [ "$which" = "all" ]; then
  for p in "01 光伏预报的精度画像/plot_q3_skill" "02 预报的系统性形状偏差/plot_q3_bias" \
           "10 结算的分段线性费用结构/plot_q3_tariff" "03 全年费用的三项分解/plot_q3_cost" \
           "04 指定日期的四阶段轨迹/plot_q3_days" "05 调整量的逐日演化/plot_q3_adj" \
           "06 紧急购电的逐时分布/plot_q3_em" "07 储能储电量轨迹与日末分布/plot_q3_soc" \
           "08 策略对照与边际收益/plot_q3_sens" "09 策略间的费用结构变化/plot_q3_sens2" \
           "11 四阶段锁定与拼接/plot_q3_stage"; do
    run_one "figures/问题三/$p.m"
  done
fi
echo "图件脚本执行完毕 $(date '+%F %T')" >> "$LOG"
