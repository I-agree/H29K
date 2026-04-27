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

# 功能：自动下载 HINLINK H29K 设备完整补丁（内置DTS+设备配置）
# 无需单独处理 DTS 文件，补丁全包
#

#==================== 下载 H29K 完整补丁 ====================
echo "============================================="
echo " 开始下载 HINLINK H29K 设备补丁（内置DTS）"
echo "============================================="

# 替换为你补丁的真实 Raw 地址（GitHub 打开补丁 → 点 Raw → 复制链接）
wget -O 108-board-rockchip-add-HINLINK-H29K.patch \
https://raw.githubusercontent.com/I-agree/H29K/main/108-board-rockchip-add-HINLINK-H29K.patch

# 校验下载结果
if [ -f "108-board-rockchip-add-HINLINK-H29K.patch" ]; then
    echo "✅ 补丁下载成功，准备应用"
else
    echo "❌ 补丁下载失败，请检查下载地址"
    exit 1
fi

echo "======================================================="
echo " 下载108-board-rockchip-add-HINLINK-H29K.patch行完成"
echo "======================================================="

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
