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

# ======================== 安全清理：只删冲突补丁 ========================
# 清理内核里所有 RK3588 / Rock5 系列冲突补丁（不碰 RK3528/H28K）
rm -vf target/linux/rockchip/patches-6.12/001-*
rm -vf target/linux/rockchip/patches-6.12/002-*
rm -vf target/linux/rockchip/patches-6.12/*rk3588*.patch
rm -vf target/linux/rockchip/patches-6.12/*rock-5*.patch
rm -vf target/linux/rockchip/patches-6.12/*firefly*.patch
rm -vf target/linux/rockchip/patches-6.12/*odroid*.patch
rm -vf target/linux/rockchip/patches-6.12/*phytium*.patch

# 清理 U-Boot 里冲突补丁（严格保留 H28K/H66K/H68K）
rm -vf package/boot/uboot-rockchip/patches/*rk3588*.patch
rm -vf package/boot/uboot-rockchip/patches/*rock-5*.patch
rm -vf package/boot/uboot-rockchip/patches/*firefly*.patch
rm -vf package/boot/uboot-rockchip/patches/*odroid*.patch
rm -vf package/boot/uboot-rockchip/patches/*phytium*.patch
rm -vf package/boot/uboot-rockchip/patches/104*.patch
rm -vf package/boot/uboot-rockchip/patches/105*.patch
rm -vf package/boot/uboot-rockchip/patches/101*.patch
rm -vf package/boot/uboot-rockchip/patches/102*.patch
rm -vf package/boot/uboot-rockchip/patches/103*.patch

# U-Boot 补丁目录
mkdir -p package/boot/uboot-rockchip/patches/

# 下载 U-Boot 补丁
wget -O package/boot/uboot-rockchip/patches/001-add-h29k-uboot-target.patch \
https://raw.githubusercontent.com/I-agree/H29K/main/001-add-h29k-uboot-target.patch

wget -O package/boot/uboot-rockchip/patches/108-board-rockchip-add-HINLINK-H29K.patch \
https://raw.githubusercontent.com/I-agree/H29K/main/108-board-rockchip-add-HINLINK-H29K.patch

# 内核 DTS 文件
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
wget -O target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts \
https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts

# 内核 DTS Makefile 注册
echo "dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3528-opc-h29k.dtb" >> target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/Makefile

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
