#!/usr/bin/env bash
# run_test.sh — 2023c 测试一键脚本（/test 备用路径）
# 用法: bash run_test.sh   （在任意目录执行均可, 脚本自动定位题目目录）
cd "$(dirname "$0")"
matlab -batch "run('tests/test_vegetable.m')"
