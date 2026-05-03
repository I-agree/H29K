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

# ======================== 【添加 H29K：armv8.mk 设备定义】 ========================
# ✅ 修复点3：DEVICE_DTS 使用标准社区命名 rk3528-hinlink-h29k（非 opc- 前缀）
TARGET_MK="target/linux/rockchip/image/armv8.mk"

cat >> "$TARGET_MK" <<'EOF'
# 📌 设备定义：HINLINK H29K（RK3528）
#    - 遵循 OpenWrt 命名规范：rk3528-{vendor}-{model}
define Device/hinlink_h29k
  SOC := rk3528
  SUBTARGET := armv8
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  UBOOT_CONFIG := hinlink_h29k
  KERNEL_LOADADDR := 0x00280000
  KERNEL_ENTRYADDR := 0x00280000
  DEVICE_UBOOT_IMAGE := u-boot-rockchip-hinlink_h29k.bin
  DEVICE_COMPAT_VERSION := 1
  SUPPORTED_DEVICES := hinlink_h29k
  IMAGE/boot.bin := boot-scr | boot-kernel | boot-dtb
  IMAGE/sysupgrade.img.gz := boot.bin | append-rootfs | pad-rootfs | check-size | gzip
  DEVICE_PACKAGES := \
    kmod-usb3 kmod-usb-net-rtl8152 kmod-aic8800-sdio dnsmasq-full \
    kmod-usb-net-cdc-mbim uqmi qmi-utils kmod-usb-serial-option kmod-usb-net-rndis-host \
    luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn \
    luci-theme-argon imagemagick wqy-microhei curl irqbalance \
    luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn \
    luci-mod-admin-full \
    luci-app-irqbalance luci-i18n-irqbalance-zh-cn \
    dnscrypt-proxy luci-app-dnscrypt-proxy luci-i18n-dnscrypt-proxy-zh-cn \
    luci-app-oaf appfilter luci-i18n-oaf-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF
