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

#!/bin/sh
# ============================================================
# ✅ diy-part1.sh（终极精准版｜2026-05-01）
# 功能：原样注入你提供的 define Device/hinlink_h29k（含全部换行/缩进/反斜杠/中文包名）
# 严格遵循：不修改任何字符、不添加空行、不删除空格、不转义反斜杠
# ============================================================

set -e

# 🔹 路径配置（请按实际调整）
ARMV8_MK="target/linux/rockchip/image/armv8.mk"
DEVICE_NAME="hinlink_h29k"

# 🔹 【核心】你提供的完整 define Device 块（一字不差，用单引号 EOF 保护）
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

# 🔹 步骤 1：校验 armv8.mk 存在
if [ ! -f "$ARMV8_MK" ]; then
  echo "❌ FATAL: $ARMV8_MK not found. Please check OpenWrt version and path."
  exit 1
fi

# 🔹 步骤 2：检查是否已存在（用固定字符串匹配，避免正则干扰）
if grep -Fq "$DEVICE_BLOCK" "$ARMV8_MK"; then
  echo "✅ define Device/hinlink_h29k already exists in $ARMV8_MK (skipped)"
else
  echo "➕ Injecting define Device/hinlink_h29k into $ARMV8_MK..."
  # 使用 printf %b 安全写入（保持 \n 和空格原样）
  printf '%b\n' "$DEVICE_BLOCK" >> "$ARMV8_MK"
  echo "✅ Injection completed."
fi

# 🔹 步骤 3：锁定 armv8.mk（仅当文件存在且可写）
if [ -w "$ARMV8_MK" ]; then
  if command -v sudo >/dev/null 2>&1 && command -v lsattr >/dev/null 2>&1; then
    if ! lsattr "$ARMV8_MK" 2>/dev/null | grep -q "i"; then
      sudo chattr +i "$ARMV8_MK" 2>/dev/null
      if lsattr "$ARMV8_MK" 2>/dev/null | grep -q "i"; then
        echo "🔒 Locked: $ARMV8_MK (immutable)"
      else
        echo "⚠️  Warning: Failed to lock $ARMV8_MK. Will proceed anyway."
      fi
    else
      echo "🔒 Already locked: $ARMV8_MK"
    fi
  else
    echo "⚠️  sudo or lsattr not available. Skipping lock."
  fi
else
  echo "⚠️  $ARMV8_MK is not writable. Skipping lock."
fi

echo "🎯 diy-part1.sh done. Your exact define Device block is now in $ARMV8_MK."

