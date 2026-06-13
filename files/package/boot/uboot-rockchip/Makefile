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

# 🚀 【现代主线化】彻底打通 U-Boot 原生设备树目录
define Build/Prepare
	$(call Build/Prepare/Default)
	# 1. 复制自定义 H29K defconfig 到 U-Boot 基础配置目录
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig $(PKG_BUILD_DIR)/configs/
	
	# 2. 🛠️ 核心修正：直接放入 arch/arm/dts/ 根目录
	# 这样才能与 U-Boot 官方自带的 rk3528.dtsi 处于同级目录，正确完成 #include 展开
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts $(PKG_BUILD_DIR)/arch/arm/dts/
	
	# 3. 🛠️ 核心补丁：将 dtb 目标无条件注册进 U-Boot 设备树 Makefile，防止报 No rule to make target 错误
	echo 'dtb-y += rk3528-hinlink-h29k.dtb' >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile
endef

define Build/Configure
	$(call Build/Configure/U-Boot)

ifneq ($(filter %rk3576,$(BUILD_VARIANT)),)
	$(TARGET_CC) -nostdlib -ffreestanding -Os -S -o $(PKG_BUILD_DIR)/rk3576-boost.S $(PKG_BUILD_DIR)/rk3576-boost.c
	$(TARGET_CROSS)as -o $(PKG_BUILD_DIR)/rk3576-boost.o $(PKG_BUILD_DIR)/rk3576-boost.S
	$(TARGET_CROSS)objcopy -O binary -j .text $(PKG_BUILD_DIR)/rk3576-boost.o $(PKG_BUILD_DIR)/rk3576-boost.bin
endif
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(CP) $(PKG_BUILD_DIR)/u-boot-rockchip.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot-rockchip.bin
endef

define Package/u-boot/install/default
endef

$(eval $(call BuildPackage/U-Boot))
