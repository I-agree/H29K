#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_VERSION:=2025.10
PKG_RELEASE:=1
PKG_HASH:=b4f032848e56cc8f213ad59f9132c084dbbb632bc29176d024e58220e0efdf4a

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
  DEPENDS:=+trusted-firmware-a-rk3528
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
  $(if $(TPL),ROCKCHIP_TPL=$(STAGING_DIR_IMAGE)/$(TPL))

# 🚀 【核心修正】内嵌 LEDE 核心 dtsi 强行注入与文件重组机制
define Build/Prepare
	$(call Build/Prepare/Default)
	# 1. 复制自定义 defconfig 和基础 DTS 文件
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig $(PKG_BUILD_DIR)/configs/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts $(PKG_BUILD_DIR)/arch/arm/dts/
	# 2. 强行将内核下载并验证通过的全新 LEDE 核心 dtsi 组件同步注入 U-Boot 源码树
	$(CP) $(TOPDIR)/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528*.dtsi $(PKG_BUILD_DIR)/arch/arm/dts/
	$(CP) $(TOPDIR)/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rockchip-pinconf.dtsi $(PKG_BUILD_DIR)/arch/arm/dts/
	# 3. 将新设备树追加到 U-Boot 编译名录
	echo 'dtb-y += rk3528-hinlink-h29k.dtb' >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile
endef

define Package/u-boot/install/default
	$(CP) $(PKG_BUILD_DIR)/u-boot-rockchip.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot-rockchip.bin
endef

$(eval $(call BuildPackage/U-Boot))
