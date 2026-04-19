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
# 1. 自动定位正确的 Makefile (优先查找 rk35xx.mk)
TARGET_MK=$(find target/linux/rockchip/image -name "rk35xx.mk" -o -name "armv8.mk" | head -n 1)

if [ -n "$TARGET_MK" ]; then
    echo "发现目标 Makefile: $TARGET_MK"
    
    # 检查是否已经注册过，避免重复追加导致编译失败
    if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
        echo "正在注册 H29K 设备..."
        # 必须使用 'EOF' 带单引号，防止 Shell 错误解析 Makefile 语法
        cat >> "$TARGET_MK" <<'EOF'

define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_ALT0_VENDOR := LinkStar
  DEVICE_ALT0_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink-h29k
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-drm-rockchip kmod-console-font \
    kmod-usb3 kmod-usb-dwc3-rockchip kmod-usb-serial-option uqmi \
    luci-i18n-base-zh-cn luci-i18n-qmodem-next-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF
    else
        echo "H29K 设备已存在，跳过注册。"
    fi
else
    echo "错误: 找不到 rockchip 镜像 Makefile，请检查源码目录结构。"
fi

# 开启 MHI 总线支持，这是很多 5G 模块（如移远 RM500Q）的依赖
echo "CONFIG_MHI_BUS=y" >> target/linux/rockchip/config-default
echo "CONFIG_MHI_BUS_PCI_GENERIC=y" >> target/linux/rockchip/config-default
