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

# 1. UBOOT 补丁目录
mkdir -p package/boot/uboot-rockchip/patches/

# 2. 下载 UBOOT 补丁
wget -O package/boot/uboot-rockchip/patches/001-add-h29k-uboot-target.patch \
https://raw.githubusercontent.com/I-agree/H29K/main/001-add-h29k-uboot-target.patch

wget -O package/boot/uboot-rockchip/patches/108-board-rockchip-add-HINLINK-H29K.patch \
https://raw.githubusercontent.com/I-agree/H29K/main/108-board-rockchip-add-HINLINK-H29K.patch

# 3. 安装内核 DTS 文件（你已有的）
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
wget -O target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts \
https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts

# 4. ✅【最终修复】创建内核设备定义（这是你唯一缺的！）
mkdir -p target/linux/rockchip/image/
cat > target/linux/rockchip/image/armv8.mk <<EOF
define Device/hinlink_h29k
  \$(call Device/rk3528)
  DEVICE_TITLE := HINLINK H29K
  DEVICE_DTS := rk3528-opc-h29k
endef
TARGET_DEVICES += hinlink_h29k
EOF

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
