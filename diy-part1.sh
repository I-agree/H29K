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
# 添加 OpenAppFilter 插件源
echo 'src-git OpenAppFilter https://github.com/destan19/OpenAppFilter.git;master' >> feeds.conf.default

# ============================================================
# ✅ diy-part1.sh（精简纯净版｜2026-05-01｜严格遵循你的原始逻辑）
# 功能：
#   1. 向 armv8.mk 注入 define Device/hinlink_h29k（原样）
#   2. 向 uboot-rockchip/Makefile 执行你指定的两个 sed 命令（零添加）
#   3. 双文件存在性校验 + 双文件 chattr +i 锁定
# ============================================================

set -e

ARMV8_MK="target/linux/rockchip/image/armv8.mk"
UBOOT_MK="package/boot/uboot-rockchip/Makefile"
DEVICE_NAME="hinlink_h29k"

# 🔹 define Device/hinlink_h29k（你提供的原始内容，一字不差）
DEVICE_BLOCK='define Device/hinlink_h29k
  SOC := rk3528
  SUBTARGET := armv8
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  UBOOT_CONFIG := hinlink_h29k
  DEVICE_UBOOT_IMAGE := u-boot-rockchip-hinlink_h29k.bin
  IMAGE/boot.bin := boot-scr | boot-kernel | boot-dtb
  IMAGE/sysupgrade.img.gz := boot.bin | append-rootfs | pad-rootfs | check-size | gzip
  DEVICE_PACKAGES := \
    kmod-usb3 kmod-usb-net-rtl8152 kmod-r8169 kmod-aic8800-sdio wpad-openssl dnsmasq-full \
    kmod-mtk_t7xx kmod-usb-net-cdc-mbim uqmi kmod-usb-net-rndis-host kmod-usb-serial-option \
    kmod-h29k-fb-st7789v \
    luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn \
    luci-theme-argon fbv imagemagick wqy-microhei curl irqbalance \
    luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn \
    luci-mod-admin-full \
    luci-app-irqbalance luci-i18n-irqbalance-zh-cn \
    dnscrypt-proxy luci-app-dnscrypt-proxy luci-i18n-dnscrypt-proxy-zh-cn \
    luci-app-oaf appfilter luci-i18n-oaf-zh-cn
endef
TARGET_DEVICES += hinlink_h29k'

# 🔹 步骤 1：校验 armv8.mk
if [ ! -f "$ARMV8_MK" ]; then
  echo "❌ FATAL: $ARMV8_MK not found."
  exit 1
fi

# 🔹 步骤 2：注入 Device（幂等）
if grep -Fq "$DEVICE_BLOCK" "$ARMV8_MK"; then
  echo "✅ define Device/$DEVICE_NAME already exists in $ARMV8_MK (skipped)"
else
  printf '%b\n' "$DEVICE_BLOCK" >> "$ARMV8_MK"
  echo "✅ Device injected into $ARMV8_MK"
fi

# 🔹 步骤 3：校验 uboot-rockchip/Makefile
if [ ! -f "$UBOOT_MK" ]; then
  echo "❌ FATAL: $UBOOT_MK not found. Please ensure your OpenWrt fork includes it."
  exit 1
fi

# 🔹 步骤 4：执行你指定的两个 sed 命令（POSIX 安全版）
echo "🔧 Applying your exact sed patches to $UBOOT_MK..."

# 1️⃣ 追加 UBOOT_TARGETS
if ! grep -q "hinlink-h29k-rk3528" "$UBOOT_MK"; then
  sed -i "/hinlink-h28k-rk3528/a hinlink-h29k-rk3528" "$UBOOT_MK"
  echo "✅ Added 'hinlink-h29k-rk3528' to UBOOT_TARGETS"
else
  echo "✅ 'hinlink-h29k-rk3528' already in UBOOT_TARGETS (skipped)"
fi

# 2️⃣ 插入 define U-Boot/hinlink-h29k-rk3528
if ! grep -q "define U-Boot/hinlink-h29k-rk3528" "$UBOOT_MK"; then
  sed -i '/define U-Boot\/hinlink-h28k-rk3528/a\
define U-Boot/hinlink-h29k-rk3528\n  $(U-Boot/rk3528/Default)\n  UBOOT_CONFIG:=hinlink_h29k\n  NAME:=HINLINK_H29K\n  BUILD_DEVICES:=hinlink_h29k\nendef
' "$UBOOT_MK"
  echo "✅ Inserted 'define U-Boot/hinlink-h29k-rk3528'"
else
  echo "✅ 'define U-Boot/hinlink-h29k-rk3528' already exists (skipped)"
fi

# 🔹 步骤 5：双文件锁定
for FILE in "$ARMV8_MK" "$UBOOT_MK"; do
  if [ -w "$FILE" ]; then
    if command -v sudo >/dev/null 2>&1 && command -v lsattr >/dev/null 2>&1; then
      if ! lsattr "$FILE" 2>/dev/null | grep -q "i"; then
        sudo chattr +i "$FILE" 2>/dev/null
        if lsattr "$FILE" 2>/dev/null | grep -q "i"; then
          echo "🔒 Locked: $FILE"
        else
          echo "⚠️  Warning: Failed to lock $FILE"
        fi
      else
        echo "🔒 Already locked: $FILE"
      fi
    fi
  fi
done

echo "🎯 diy-part1.sh done. Your exact logic is now applied."
