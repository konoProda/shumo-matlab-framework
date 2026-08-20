#!/bin/bash
# 2024C 一致性测试一键脚本（/test 备用路径）
# 用法: bash run_test.sh
cd "$(dirname "$0")"
matlab -batch "run('tests/test_planting.m')"
