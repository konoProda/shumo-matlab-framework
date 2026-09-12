#!/usr/bin/env bash
# 2026C_formal 测试一键脚本（备用路径）
# 用法：bash run_test.sh [q1|q2|all]   默认 q2
set -u
cd "$(dirname "$0")"
which=${1:-q2}
case "$which" in
  q1)  matlab -batch "run('tests/test_q1.m')" ;;
  q2)  matlab -batch "run('tests/test_q2.m')" ;;
  all) matlab -batch "run('tests/test_q1.m')"; matlab -batch "run('tests/test_q2.m')" ;;
  *)   echo "用法：bash run_test.sh [q1|q2|all]"; exit 1 ;;
esac
