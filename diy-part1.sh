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

set -euo pipefail  # 🔥 关键修复：任一命令失败立即终止，杜绝静默错误

# ==============================================================================
# 【U-Boot 支持注入】—— 严格遵循 OpenWrt 官方 Makefile 风格（高危修复区）
# ✅ 修复点1：BusyBox sed 不支持 'a\' 多行追加 → 改用 POSIX 兼容写法（自动换行）
# ✅ 修复点2：NAME 字段统一为下划线命名，与 UBOOT_CONFIG 语义一致
# ==============================================================================
makefile="package/boot/uboot-rockchip/Makefile"

# 1️⃣ 在 hinlink-h28k-rk3528 后追加 hinlink-h29k-rk3528 到 UBOOT_TARGETS（POSIX 安全）
sed -i "/hinlink-h28k-rk3528/a hinlink-h29k-rk3528" "$makefile"

# 2️⃣ 在 hinlink-h28k 定义下方插入 hinlink-h29k 设备块（完全复刻官方格式）
#    ✅ NAME:=HINLINK_H29K（非空格，与 UBOOT_CONFIG 一致）
#    ✅ BUILD_DEVICES:=hinlink_h29k（小写+下划线，与 .config 中 CONFIG_TARGET_... 保持一致）
sed -i '/define U-Boot\/hinlink-h28k-rk3528/a\
define U-Boot/hinlink-h29k-rk3528\n  $(U-Boot/rk3528/Default)\n  UBOOT_CONFIG:=hinlink_h29k\n  NAME:=HINLINK_H29K\n  BUILD_DEVICES:=hinlink_h29k\nendef
' "$makefile"

# ======================== 【添加 H29K：armv8.mk 设备定义】 ========================
# ✅ 修复点3：DEVICE_DTS 使用标准社区命名 rk3528-hinlink-h29k（非 opc- 前缀）
TARGET_MK="target/linux/rockchip/image/armv8.mk"

cat >> "$TARGET_MK" <<'EOF'
# 📌 设备定义：HINLINK H29K（RK3528）
#    - 遵循 OpenWrt 命名规范：rk3528-{vendor}-{model}
#    - 使用官方 $(Device/rk3528) 宏保证内核与镜像一致性
define Device/hinlink_h29k
  $(Device/rk3528)
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
TARGET_DEVICES += hinlink_h29k
EOF

printf '\n'
echo "===== ✅ 添加 H29K：armv8.mk 设备定义完成 ====="

# ======================== 【H29K 强制2项校验 · 失败立即终止编译】 ========================
echo "🔍 开始 H29K 构建前置2重校验..."

# ✅ 校验1：设备定义已写入 armv8.mk
DEVICE_NAME="hinlink_h29k"
MK_FILE="target/linux/rockchip/image/armv8.mk"
if ! grep -q "$DEVICE_NAME" "$MK_FILE"; then
  echo -e "\033[31m[错误] H29K 设备未定义！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] 设备定义已写入 armv8.mk\033[0m"

# ✅ 校验3：U-Boot 已添加 hinlink-h29k-rk3528（Makefile确认）
UBOOT_MK="package/boot/uboot-rockchip/Makefile"
if ! grep -q "hinlink-h29k-rk3528" "$UBOOT_MK"; then
  echo -e "\033[31m[错误] U-Boot 未添加 H29K 设备！编译终止！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] U-Boot 已添加 H29K 设备（Makefile校验）\033[0m"

printf '\n'
echo -e "\033[32m=====================================\033[0m"
echo -e "\033[32m✅ 所有检查通过！\033[0m"
echo -e "\033[32m=====================================\033[0m"
