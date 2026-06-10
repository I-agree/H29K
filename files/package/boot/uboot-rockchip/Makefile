#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_VERSION:=2026.04
PKG_RELEASE:=1
PKG_HASH:=skip

PKG_MAINTAINER:=Sarah Maedel <openwrt@tbspace.de>

UBOOT_USE_BINMAN:=1
UBOOT_USE_INTREE_DTC:=1

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=rockchip
  UENV:=default
  HIDDEN:=1
endef

# RK3528 boards

define U-Boot/rk3528/Default
  BUILD_SUBTARGET:=armv8
  DEPENDS:=+PACKAGE_u-boot-$(1):trusted-firmware-a-rk3528
  ATF:=rk3528_bl31_v1.20.elf
  TPL:=rk3528_ddr_1056MHz_v1.11.bin
endef

define U-Boot/hinlink-h29k-rk3528
  $(U-Boot/rk3528/Default)
  NAME:=HINLINK H29K
  BUILD_DEVICES:= \
    hinlink_h29k
endef

UBOOT_TARGETS := hinlink-h29k-rk3528

UBOOT_CONFIGURE_VARS += USE_PRIVATE_LIBGCC=yes

UBOOT_CUSTOMIZE_CONFIG := \
	--disable TOOLS_MKEFICAPSULE \
	--set-str MKIMAGE_DTC_PATH $(PKG_BUILD_DIR)/scripts/dtc/dtc

UBOOT_MAKE_FLAGS += \
	BL31=$(STAGING_DIR_IMAGE)/$(ATF) \
	$(if $(TPL),ROCKCHIP_TPL=$(STAGING_DIR_IMAGE)/$(TPL)) \
	HOSTLDLIBS_dtc="-lyaml"

# 🚀 【现代主线化】仅注入 H29K 独有配置，其余完全借用 U-Boot 官方原生 DTSI
define Build/Prepare
	$(call Build/Prepare/Default)
	# 1. 复制自定义 H29K defconfig 到 U-Boot 基础配置目录
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig $(PKG_BUILD_DIR)/configs/
	
	# 2. 确保主线标准的 rockchip 源码设备树目录存在
	mkdir -p $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
	
	# 3. 仅将你的 H29K 独立板级 DTS 放入该目录，它会自动 include 官方原生的 rk3528.dtsi
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(CP) $(PKG_BUILD_DIR)/u-boot-rockchip.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot-rockchip.bin
endef

define Package/u-boot/install/default
endef

$(eval $(call BuildPackage/U-Boot))
