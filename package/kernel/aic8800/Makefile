# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (c) 2025 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=aic8800
PKG_RELEASE:=5

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/radxa-pkg/aic8800.git
PKG_SOURCE_DATE:=2026-03-10
PKG_SOURCE_VERSION:=89f865b80f5f2ba6c0711c560e1d0191e87a1bf0

PKG_CONFIG_DEPENDS:=CONFIG_AIC8800_SDIO_BT_SUPPORT
PKG_FLAGS:=nonshared

# =================================================================
# 🔒【核心银弹】强制声明编译期依赖包名 mac80211
# 迫使总攻的 make -j$(nproc) 必须对两者进行串行排队，彻底粉碎并发冲突
# =================================================================
PKG_BUILD_DEPENDS:=mac80211

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define Package/aic8800-sdio-firmware
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=Aicsemi aic8800 SDIO firmware
endef

define KernelPackage/aic8800-sdio
  SUBMENU:=Wireless Drivers
  TITLE:=Aicsemi aic8800 Wi-Fi SDIO support
  DEPENDS:=+kmod-mac80211 +kmod-cfg80211 +@DRIVER_11N_SUPPORT +@DRIVER_11AC_SUPPORT \
    +@DRIVER_11AX_SUPPORT +aic8800-sdio-firmware +kmod-mmc +CONFIG_AIC8800_SDIO_BT_SUPPORT:kmod-bluetooth
  FILES:= \
	$(PKG_BUILD_DIR)/src/SDIO/driver_fw/driver/aic8800/aic8800_bsp/aic8800_bsp.ko \
	$(PKG_BUILD_DIR)/src/SDIO/driver_fw/driver/aic8800/aic8800_fdrv/aic8800_fdrv.ko
  AUTOLOAD:=$(call AutoProbe,aic8800_bsp aic8800_fdrv)
endef

define KernelPackage/aic8800-sdio/config
  if PACKAGE_kmod-aic8800-sdio
	config AIC8800_SDIO_BT_SUPPORT
		bool "Enable Bluetooth support"
		default y
  endif
endef

NOSTDINC_FLAGS:= \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(PKG_BUILD_DIR) \
	-I$(PKG_BUILD_DIR)/include \
	-I$(STAGING_DIR)/usr/include/mac80211-backport \
	-I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211 \
	-I$(STAGING_DIR)/usr/include/mac80211/uapi \
	-include backport/autoconf.h \
	-include backport/backport.h \
	-DBUILD_OPENWRT -Wno-missing-prototypes -Wno-error=missing-prototypes -Wno-expansion-to-defined -Wno-error=expansion-to-defined -Wno-attribute-warning -Wno-error=attribute-warning -Wno-unused-function -Wno-error=unused-function -Wno-incompatible-pointer-types -Wno-error=incompatible-pointer-types -Wno-implicit-function-declaration -Wno-error=implicit-function-declaration

define Build/Compile
	if [ -n "$(CONFIG_PACKAGE_kmod-aic8800-sdio)" ]; then \
		$(KERNEL_MAKE) \
			M="$(PKG_BUILD_DIR)/src/SDIO/driver_fw/driver/aic8800" \
			NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
			CONFIG_AIC_FW_PATH="/lib/firmware/aic8800/sdio" \
			CONFIG_AIC8800_BTLPM_SUPPORT=n \
			CONFIG_SDIO_BT=$(if $(CONFIG_AIC8800_SDIO_BT_SUPPORT),y,n) \
			modules; \
	fi
endef

define Package/aic8800-sdio-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/aic8800/sdio
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800D80/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800D80N/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800D80X2/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800DC/* \
		$(1)/lib/firmware/aic8800/sdio/
endef

$(eval $(call BuildPackage,aic8800-sdio-firmware))
$(eval $(call KernelPackage,aic8800-sdio))
