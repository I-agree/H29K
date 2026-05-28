# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2020 Sarah Maedel

define Device/rk3528
  SOC := rk3528
  KERNEL_LOADADDR := 0x03000000
endef

define Device/hinlink_h29k
  SOC := rk3528
  SUBTARGET := armv8
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  UBOOT_CONFIG := hinlink-h29k-rk3528
  UBOOT_DEVICE_NAME := hinlink-h29k-rk3528
  KERNEL_LOADADDR := 0x03000000
  BOOT_SCRIPT := mmc
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | pine64-img | gzip | append-metadata
  DEVICE_PACKAGES := \
    kmod-usb3 kmod-aic8800-sdio dnsmasq-full \
    kmod-usb-net-cdc-mbim uqmi qmi-utils kmod-usb-serial-option kmod-usb-net-rndis-host \
    luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn \
    luci-theme-argon graphicsmagick curl \
    luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn \
    luci-app-bbr luci-i18n-bbr-zh-cn luci-mod-admin-full \
    dnscrypt-proxy luci-app-dnscrypt-proxy luci-i18n-dnscrypt-proxy-zh-cn \
    irqbalance luci-app-irqbalance luci-i18n-irqbalance-zh-cn u-boot-hinlink-h29k-rk3528
endef
TARGET_DEVICES += hinlink_h29k
