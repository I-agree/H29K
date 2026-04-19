#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# 1. 创建目标目录（如果不存在）
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/

# 2. 下载 H29K 的设备树文件 (DTS)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
curl -fsSL https://raw.githubusercontent.com/aaaol/OpenWrt/master/Files/LEDE/HinLink_H29K/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts > target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts

# 3. 在 Makefile 中注册 H29K 设备
# 定义文件路径
armv8_MK="target/linux/rockchip/image/armv8.mk"

# 检查文件是否存在，防止路径变更导致报错
if [ -f "$armv8_MK" ]; then
    echo "正在向 $armv8_MK 注册 H29K 设备..."
    cat >> "$armv8_MK" <<EOF

define Device/hinlink_h29k
  DEVICE_VENDOR := HinLink
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
endef
TARGET_DEVICES += hinlink_h29k
EOF
else
    echo "错误: 找不到 $armv8_MK，请确认官方源码的 RK3528 路径是否正确。"
fi
