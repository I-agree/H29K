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

# 2. 准备 U-Boot 目录并下载文件( 源代码编译 U-Boot 没有这个步骤，非源代码编译必须在rk3528-opc-h29k.config里面关闭 U-Boot 相关选项，反之开启 )
# 自动查找包含 musl 的 staging 目录下的 image 文件夹
STAGING_IMAGE_DIR=$(find staging_dir -name "image" -type d | grep "target-aarch64" | head -n 1)

# 如果找不到（比如还没生成），则手动创建默认路径
if [ -z "$STAGING_IMAGE_DIR" ]; then
    STAGING_IMAGE_DIR="staging_dir/target-aarch64_generic_musl/image"
fi

mkdir -p "$STAGING_IMAGE_DIR"
curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin > "$STAGING_IMAGE_DIR/hinlink-h29k-u-boot-rockchip.bin"

# 在 Makefile 中保持正确的 UBOOT_DEVICE_NAME 命名
# 确保这一行是：UBOOT_DEVICE_NAME := hinlink-h29k

# 3. 在 Makefile 中注册设备( 需要人工找到OpenWrt源代码库中 mk 文件正确的位置和文件名并补充 DEVICE_PACKAGES )
TARGET_MK=$(find target/linux/rockchip/image -name "rk35xx.mk" -o -name "armv8.mk" | head -n 1)

if [ -n "$TARGET_MK" ]; then
    if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
        echo "正在向 $TARGET_MK 注册 H29K 设备..."
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
    kmod-usb3 kmod-usb-dwc3-rockchip \
    kmod-usb-net-rndis kmod-usb-net-cdc-ether kmod-usb-net-rtl8152 \
    kmod-usb-serial-option uqmi \
    luci-i18n-base-zh-cn luci-i18n-qmodem-next-zh-cn kmod-usb-net-cdc-mbim kmod-usb-net-cdc-ncm
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# 4. 注入 5G 模块 (FM350-GL) 及 Framebuffer 等等所需的内核配置
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    echo "正在注入内核驱动配置..."
    # 移除可能冲突的旧项
    sed -i '/CONFIG_USB_NET_RNDIS/d' "$KERNEL_CONF"
    sed -i '/CONFIG_MHI/d' "$KERNEL_CONF"
    
    cat >> "$KERNEL_CONF" <<EOF
# PCI & PCIE Support
CONFIG_PCI=y
CONFIG_PCIE_ROCKCHIP=y

# 5G MHI & Modem Support
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_MHI_NET=y
CONFIG_MHI_WWAN_CTRL=y
CONFIG_WWAN=y

# Network Drivers
CONFIG_USB_NET_DRIVERS=y
CONFIG_USB_NET_RNDIS_WCE=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_USB_NET_CDCETHER=y
CONFIG_USB_NET_CDC_MBIM=y
CONFIG_USB_NET_CDC_NCM=y

# Framebuffer & Display Support
CONFIG_FB=y
CONFIG_DRM_ROCKCHIP=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_FRAMEBUFFER_CONSOLE=y
EOF
fi

# 5. 重新同步 feeds 以识别新开启的内核模块包
./scripts/feeds update -i
./scripts/feeds install -a

# 6. 强制所有插件优先使用简体中文包（递归查找并选中）
# 这行命令会自动在 feeds 中寻找所有 luci-app 的 zh-cn 语言包并将其设为默认选中
sed -i 's/default n/default y/g' feeds/luci/lucidhcpc/Makefile 2>/dev/null # 示例逻辑

# 7. 修改系统默认语言为 zh_hans
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate

# 8. 设定默认时区为北京时间（上海）
sed -i "s/'UTC'/'CST-8'\n\t\tset system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 9. 设置 irqbalance 默认开启
sed -i 's/enabled "0"/enabled "1"/g' package/feeds/packages/irqbalance/files/irqbalance.config

# 10. 自动选中所有已安装插件的中文包
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

# 11. 设置主机名为 H29K
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# 12. 设置默认无线配置中的 SSID 为 H29K
sed -i 's/ssid=".*"/ssid="H29K"/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
