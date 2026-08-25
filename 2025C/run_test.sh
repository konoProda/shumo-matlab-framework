#!/usr/bin/env bash
# 一键运行 2025C 一致性测试（备用路径，组内产物）
cd "$(dirname "$0")"
/home/sck/matlab/bin/matlab -batch "run('tests/test_2025C.m')"
