#!/bin/bash
# $1 是传入的 Makefile 路径
TARGET_MAKEFILE="$1"

if grep -q 'env_h): include/generated/env.in FORCE' "$TARGET_MAKEFILE"; then
    echo "FORCE already present, skipping."
else
    # 在 shell 脚本中，您可以随意使用 $、单引号、双引号，不用担心 Make 解析
    sed -i '/env_h): include\/generated\/env\.in/s/$/ FORCE/' "$TARGET_MAKEFILE"
fi

# 验证
if ! grep -q 'env_h): include/generated/env.in FORCE' "$TARGET_MAKEFILE"; then
    echo "ERROR: Failed to patch env_h dependency!"
    exit 1
fi
