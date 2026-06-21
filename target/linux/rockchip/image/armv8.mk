# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2020 Sarah Maedel

define Device/rk3528
  SOC := rk3528
  KERNEL_LOADADDR := 0x03000000
endef

define Device/hinlink_h29k
  $(Device/rk3528)
  SUBTARGET := armv8
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  UBOOT_CONFIG := hinlink-h29k-rk3528
  UBOOT_DEVICE_NAME := hinlink-h29k-rk3528
  KERNEL_LOADADDR := 0x03000000
  IMAGES := factory.img.gz
  IMAGE/factory.img.gz := boot-common | boot-script | pine64-img | gzip | append-metadata
  DEVICE_PACKAGES := \
    kmod-usb3 kmod-aic8800-sdio -dnsmasq dnsmasq-full \
    kmod-usb-net-cdc-mbim uqmi qmi-utils kmod-usb-serial-option kmod-usb-net-rndis-host \
    kmod-usb-net-cdc-ether kmod-usb-wdm u-boot-hinlink-h29k-rk3528
endef
TARGET_DEVICES += hinlink_h29k
