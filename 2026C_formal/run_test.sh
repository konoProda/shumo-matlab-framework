#!/usr/bin/env bash
# 问题一测试一键脚本（备用路径）
cd "$(dirname "$0")"
matlab -batch "run('tests/test_q1.m')"
