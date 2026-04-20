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

# 1. 准备 DTS 目录并下载文件
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_PATH"
curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts > "$DTS_PATH/rk3528-opc-h29k.dts"

# 2. U-Boot 处理 (仅在 Makefile 注册中解耦)
# 注意：H29K这个设备是手动刷入U-Boot

# 3. 在 Makefile 中注册设备
# 修改点：移除 UBOOT_DEVICE_NAME，确保生成时不强制打包 Bootloader
TARGET_MK=$(find target/linux/rockchip/image -name "rk35xx.mk" | head -n 1)

if [ -n "$TARGET_MK" ]; then
    if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
        echo "正在向 $TARGET_MK 注册 H29K 设备 (无内嵌 U-Boot 模式)..."
        cat >> "$TARGET_MK" <<'EOF'

define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  # 关键修改：清空 UBOOT 变量，防止打包工具报错
  UBOOT_DEVICE_NAME := 
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-drm-rockchip kmod-console-font \
    kmod-usb3 kmod-usb-dwc3-rockchip \
    kmod-usb-net-rndis kmod-usb-net-cdc-ether kmod-usb-net-rtl8152 \
    kmod-usb-serial-option uqmi \
    luci-i18n-base-zh-cn luci-i18n-qmodem-next-zh-cn kmod-usb-net-cdc-mbim kmod-usb-net-cdc-ncm \
    luci-theme-argon luci-app-turboacc luci-app-sqm
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# 4. 注入内核配置 (确保 5G 模块正常工作)
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    sed -i '/CONFIG_USB_NET_RNDIS/d' "$KERNEL_CONF"
    sed -i '/CONFIG_MHI/d' "$KERNEL_CONF"
    cat >> "$KERNEL_CONF" <<EOF
# 5G & Kernel Optimizations
CONFIG_PCI=y
CONFIG_PCIE_ROCKCHIP=y
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_MHI_NET=y
CONFIG_MHI_WWAN_CTRL=y
CONFIG_WWAN=y
CONFIG_USB_NET_CDC_MBIM=y
CONFIG_USB_NET_CDC_NCM=y
# BBR & Network
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
EOF
fi

# 5. 系统初始化设置 (主机名/SSID/语言/时区)
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate
sed -i 's/ssid=".*"/ssid="H29K"/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i "s/'UTC'/'CST-8'\n\t\tset system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 6. 自动选中所有已安装插件的中文包
# 增强型语言包自动选中逻辑
if [ -f .config ]; then
    echo "正在自动选中所有已安装插件的简体中文语言包..."
    # 强制选中 base 语言包
    sed -i 's/CONFIG_LUCI_LANG_zh_Hans=y/CONFIG_LUCI_LANG_zh_Hans=y/g' .config 2>/dev/null || echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config
    
    # 扫描所有选中的 luci-app，并尝试选中对应的 i18n-zh-cn 包
    grep "=y" .config | grep "CONFIG_PACKAGE_luci-app-" | sed 's/CONFIG_PACKAGE_luci-app-//g;s/=y//g' | while read -r app; do
        if [ ! -z "$app" ]; then
            echo "CONFIG_PACKAGE_luci-i18n-$app-zh-cn=y" >> .config
        fi
    done
fi
