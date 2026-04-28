#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# ======================== 【终极智能清理：自动识别内核版本，清空全部补丁，只保留 H29K】 ========================
# 自动获取当前使用的内核补丁目录（支持 6.12 / 6.13 / 6.14 ... 任意版本）
PATCH_DIR=$(find target/linux/rockchip -name "patches-*" -type d | head -n 1)

# 清空内核补丁目录：删除所有.patch文件，彻底干净
rm -f "${PATCH_DIR}"/*.patch

# 清空 U-Boot 补丁目录：删除所有.patch文件，彻底干净
rm -f package/boot/uboot-rockchip/patches/*.patch

# 创建必需目录
mkdir -p package/boot/uboot-rockchip/patches/
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
mkdir -p "${PATCH_DIR}"

# UBOOT 补丁
wget -O package/boot/uboot-rockchip/patches/001-add-h29k-uboot-target.patch \
https://raw.githubusercontent.com/I-agree/H29K/main/001-add-h29k-uboot-target.patch

# 内核补丁（✅ 核心！自动把 DTB 加入内核 Makefile 编译）
wget -O "${PATCH_DIR}/108-board-rockchip-add-HINLINK-H29K.patch" \
https://raw.githubusercontent.com/I-agree/H29K/main/108-board-rockchip-add-HINLINK-H29K.patch

# DTS 设备树文件
wget -O target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts \
https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts

# ======================== 【✅ 关键：只编译 H29K，清空所有官方设备】 ========================
sed -i '/^TARGET_DEVICES +=/d' target/linux/rockchip/image/armv8.mk

# ======================== 【feeds 源配置（保持官方标准格式）】 ========================
# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default
# 无线网卡驱动
echo 'src-git aic8800 https://github.com/radxa-pkg/aic8800.git;main' >> feeds.conf.default
# 添加 Argon 主题源
echo 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' >> feeds.conf.default
# 添加 Argon 配置插件源
echo 'src-git jerrykuku https://github.com/jerrykuku/luci-app-argon-config.git;master' >> feeds.conf.default
