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

# --- 第一部分：环境补丁 ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 第二部分：源码注入 (针对 OpenWrt 官方源) ---

TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_PATH"
curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts > "$DTS_PATH/rk3528-opc-h29k.dts"

if [ -n "$TARGET_MK" ]; then
    # 注入 Loader 逻辑
    curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin > dl/hinlink_h29k-u-boot-rockchip.bin
    if ! grep -q "hinlink_h29k-u-boot-rockchip.bin" "$TARGET_MK"; then
        echo '
$(STAGING_DIR_IMAGE)/hinlink_h29k-u-boot-rockchip.bin: dl/hinlink_h29k-u-boot-rockchip.bin
	mkdir -p $(dir $@)
	cp $< $@
' >> "$TARGET_MK"
    fi

    # 注入设备定义 (合并 LEDE 软件包配置)
    if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
        cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | pine64-img | gzip | append-metadata
  KERNEL_SIZE := 33554432
  BOARD_ROOTFS_PARTSIZE := 1024
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-drm-rockchip \\
    kmod-aic8800-sdio kmod-fb-tft-st7789v \\
    wpad-openssl -wpad-basic-mbedtls -wpad-basic -urngd \\
    kmod-usb3 kmod-usb-dwc3-rockchip kmod-usb-net-rtl8152 \\
    luci-i18n-base-zh-cn luci-theme-argon luci-app-turboacc
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# --- 第三部分：内核与系统优化 ---

KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    # 开启屏幕支持与 BBR
    cat >> "$KERNEL_CONF" <<EOF
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_DW_HDMI=y
EOF
fi

# 个性化
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# --- 第四部分：智能锁定 (解决报错的核心) ---

# 预写入配置
echo "CONFIG_TARGET_rockchip=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

make defconfig

# 智能检查：只要含有 hinlink_h29k 且为 y 即可，不强制完整字符串匹配
if ! grep -q "DEVICE_hinlink_h29k=y" .config; then
    echo "错误：Makefile 注入可能失败，.config 中找不到设备！"
    # 打印出相关的配置项方便排查
    grep "CONFIG_TARGET_rockchip_armv8_DEVICE" .config || true
    exit 1
fi

# 移除 JFFS2 并强制锁定分区大小
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config
sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/g' .config
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/g' .config

# 强制剔除其他设备并锁定架构
sed -i 's/CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_.*=y/# & is not set/g' .config
# 重新补回这一行，确保它是唯一的选中项
echo "CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config
sed -i 's/CONFIG_TARGET_ARCH_PACKAGES=.*/CONFIG_TARGET_ARCH_PACKAGES="aarch64_generic"/g' .config
