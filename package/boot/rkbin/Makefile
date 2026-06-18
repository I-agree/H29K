# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2021-2023 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=rkbin
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/rockchip-linux/rkbin.git
PKG_SOURCE_DATE:=2025-06-13
PKG_SOURCE_VERSION:=74213af1e952c4683d2e35952507133b61394862
PKG_MIRROR_HASH:=4b801b1301ae297f660340617b5f398b23a3f0b43bc7f0ef42c21f0f43eb8990

PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/trusted-firmware-a.mk
include $(INCLUDE_DIR)/package.mk

define Trusted-Firmware-A/Default
  NAME:=Rockchip $(1) SoCs
  BUILD_TARGET:=rockchip
endef

define Trusted-Firmware-A/rk3528
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3528_bl31_v1.20.elf
  TPL:=rk35/rk3528_ddr_1056MHz_v1.11.bin
endef

TFA_TARGETS:=rk3528

define Build/Compile
endef

define Package/trusted-firmware-a/install
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)

ifneq ($(ATF),)
	$(CP) $(PKG_BUILD_DIR)/bin/$(ATF) $(STAGING_DIR_IMAGE)/
endif
	$(CP) $(PKG_BUILD_DIR)/bin/$(TPL) $(STAGING_DIR_IMAGE)/
endef

$(eval $(call BuildPackage/Trusted-Firmware-A))
