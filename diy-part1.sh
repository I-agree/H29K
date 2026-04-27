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

# 1. 下载U-Boot补丁到指定目录
# 2. 下载内核DTS文件到指定目录

echo "============================================="
echo " 开始下载 HINLINK H29K 设备补丁（U-Boot）"
echo "============================================="

# ==========================
# 1. 下载补丁到你指定的正确位置
# ==========================
mkdir -p package/boot/uboot-rockchip/patches/
wget -O package/boot/uboot-rockchip/patches/108-board-rockchip-add-HINLINK-H29K.patch \
https://raw.githubusercontent.com/I-agree/H29K/main/108-board-rockchip-add-HINLINK-H29K.patch

# ==========================
# 2. 直接下载 DTS 给内核用
# ==========================
echo "============================================="
echo " 下载内核设备树 DTS 文件"
echo "============================================="
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_DIR"
wget -O "$DTS_DIR/rk3528-opc-h29k.dts" \
https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts

# 校验
if [ -f "$DTS_DIR/rk3528-opc-h29k.dts" ]; then
    echo "✅ DTS 文件已下载到内核正确路径"
else
    echo "❌ DTS 下载失败"
    exit 1
fi

echo "============================================="
echo " 补丁 + DTS 全部处理完成！"
echo "============================================="

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
