# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2021-2023 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=rkbin
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/rockchip-linux/rkbin.git
PKG_SOURCE_DATE:=2024-10-18
PKG_SOURCE_VERSION:=12660714c81be85350a4092542e2ff599aa5adcb
PKG_MIRROR_HASH:=30f8ba3ca250dac4c60d1b642e7b3436daf091ace67f600a3bfdd5983bfa98a6

PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/trusted-firmware-a.mk
include $(INCLUDE_DIR)/package.mk

define Trusted-Firmware-A/Default
  NAME:=Rockchip $(1) SoCs
  BUILD_TARGET:=rockchip
endef

define Trusted-Firmware-A/rk3308
  BUILD_SUBTARGET:=armv8
  ATF:=rk33/rk3308_bl31_v2.27.elf
  TPL:=rk33/rk3308_ddr_589MHz_uart2_m1_v2.10.bin
endef

define Trusted-Firmware-A/rk3308-tpl-rock-pi-s
  NAME:=Radxa ROCK Pi S board
  BUILD_SUBTARGET:=armv8
  TPL:=rk33/rk3308_ddr_589MHz_uart0_m0_v2.10.bin
endef

define Trusted-Firmware-A/rk3528
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3528_bl31_v1.17.elf
  TPL:=rk35/rk3528_ddr_1056MHz_v1.10.bin
endef

define Trusted-Firmware-A/rk3566
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3568_bl31_v1.45.elf
  TPL:=rk35/rk3566_ddr_1056MHz_v1.23.bin
endef

define Trusted-Firmware-A/rk3568
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3568_bl31_v1.45.elf
  TPL:=rk35/rk3568_ddr_1560MHz_v1.23.bin
endef

define Trusted-Firmware-A/rk3568-tpl-e25
  NAME:=Radxa E25 board
  BUILD_SUBTARGET:=armv8
  TPL:=rk35/rk3568_ddr_1560MHz_uart2_m0_115200_v1.23.bin
endef

define Trusted-Firmware-A/rk3576-tpl
  NAME:=Rockchip RK3576 SoCs
  BUILD_SUBTARGET:=armv8
  TPL:=rk35/rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.09.bin
endef

define Trusted-Firmware-A/rk3588-tpl
  NAME:=Rockchip RK3588 SoCs
  BUILD_SUBTARGET:=armv8
  TPL:=rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin
endef

TFA_TARGETS:= \
	rk3308 \
	rk3308-tpl-rock-pi-s \
	rk3528 \
	rk3566 \
	rk3568 \
	rk3568-tpl-e25 \
	rk3576-tpl \
	rk3588-tpl

ifeq ($(BUILD_VARIANT),rk3308-tpl-rock-pi-s)
  define Download/rk3308-tpl-rock-pi-s
    FILE:=$(notdir $(TPL))
    URL_FILE:=$(TPL)
    URL:=https://github.com/radxa/rkbin/raw/2b54df9d062ef91a9fffbc85472b070c9220c4cf/bin/
    HASH:=45af030ed2cb322cc5a91c32350130fc1f1ea9508794fa4b5d309eadf70e3d04
  endef

  define Build/Prepare
	$(eval $(call Download,rk3308-tpl-rock-pi-s))
	$(call Build/Prepare/Default)

	$(CP) $(DL_DIR)/$(notdir $(TPL)) $(PKG_BUILD_DIR)/bin/$(TPL)
  endef
endif

ifeq ($(BUILD_VARIANT),rk3568-tpl-e25)
  define Download/rk3568-tpl-e25
    FILE:=$(notdir $(TPL))
    URL_FILE:=$(TPL)
    URL:=https://github.com/radxa/rkbin/raw/2e77c53ab0279585b09ecdaa54fe3e2bf80f9475/bin/
    HASH:=1bb9f92a6515a70b91c0f8bd3aa4dc31432afc4317b9408f82c43ca63cb10ab6
  endef

  define Build/Prepare
	$(eval $(call Download,rk3568-tpl-e25))
	$(call Build/Prepare/Default)

	$(CP) $(DL_DIR)/$(notdir $(TPL)) $(PKG_BUILD_DIR)/bin/$(TPL)
  endef
endif

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
