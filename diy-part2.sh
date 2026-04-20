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
STAGING_IMAGE_DIR="staging_dir/target-aarch64_generic_musl/image"
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
    luci-i18n-base-zh-cn luci-i18n-qmodem-next-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# 4. 注入 5G 模块 (FM350-GL) 及 Framebuffer 所需的内核配置
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    echo "正在注入内核驱动配置..."
    # 移除可能重复的配置项 (去重)
    sed -i '/CONFIG_USB_NET_RNDIS/d' "$KERNEL_CONF"
    
    cat >> "$KERNEL_CONF" <<EOF
# 5G MHI & RNDIS Support
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_USB_NET_DRIVERS=y
CONFIG_USB_NET_RNDIS_WCE=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_USB_NET_CDCETHER=y
# Framebuffer Support
CONFIG_FB=y
CONFIG_DRM_ROCKCHIP=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_FRAMEBUFFER_CONSOLE=y
EOF
fi

# 5. 重新同步 feeds 以识别新开启的内核模块包
./scripts/feeds update -i
./scripts/feeds install -a
