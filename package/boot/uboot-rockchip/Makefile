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
	PKG_CONFIG=pkg-config \
	PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig" \
	BINMAN_ALLOW_MISSING=0 \
	BINMAN_INTRUSIVE_AS_NEEDED=1 \
	BL31=$(STAGING_DIR_IMAGE)/$(ATF) \
	$(if $(TPL),ROCKCHIP_TPL=$(STAGING_DIR_IMAGE)/$(TPL)) \
	EXTRA_CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=int-to-pointer-cast -Wno-error=pointer-to-int-cast -Wno-error=int-conversion"

# 🚀 【现代主线化全面适配】彻底打通 U-Boot 2026+ 原生 OF_UPSTREAM 设备树目录
define Build/Prepare
	$(call Build/Prepare/Default)
	# 1. 复制自定义 H29K defconfig 到 U-Boot 基础配置目录
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig $(PKG_BUILD_DIR)/configs/
	
	# 2. 🛠️ 核心修正：适配现代 U-Boot 规范，直接放入真正的 upstream 源码根目录
	mkdir -p $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k-u-boot.dtsi $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(CP) $(PKG_BUILD_DIR)/u-boot-rockchip.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot-rockchip.bin

	# 单独导出 TPL / SPL / idbloader / u-boot.itb 用于校验
	$(CP) $(PKG_BUILD_DIR)/tpl/u-boot-tpl.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-tpl.bin
	$(CP) $(PKG_BUILD_DIR)/spl/u-boot-spl.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-spl.bin
	$(CP) $(PKG_BUILD_DIR)/idbloader.img $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-idbloader.img
	$(CP) $(PKG_BUILD_DIR)/u-boot.itb $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot.itb

	# ===================== 四组件完整强制校验 =====================
	@echo "============================================="
	@echo "【UBoot 引导组件校验：$(BUILD_VARIANT)】"
	# 校验TPL存在且非空
	@if [ ! -f "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-tpl.bin" ] || [ ! -s "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-tpl.bin" ]; then \
		echo "ERROR: TPL DDR初始化二进制缺失/为空！检查 CONFIG_SUPPORT_TPL=y CONFIG_TPL=y"; \
		exit 1; \
	fi
	# 校验SPL存在且非空
	@if [ ! -f "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-spl.bin" ] || [ ! -s "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-spl.bin" ]; then \
		echo "ERROR: SPL二级引导二进制缺失/为空！检查 CONFIG_SUPPORT_SPL=y CONFIG_SPL=y"; \
		exit 1; \
	fi
	# 校验 idbloader.img 存在且非空
	@if [ ! -f "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-idbloader.img" ] || [ ! -s "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-idbloader.img" ]; then \
		echo "ERROR: idbloader 合并引导镜像缺失/为空！"; \
		exit 1; \
	fi
	# 校验 u-boot.itb (ATF+主U-Boot FIT) 存在且非空
	@if [ ! -f "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot.itb" ] || [ ! -s "$(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot.itb" ]; then \
		echo "ERROR: u-boot.itb FIT镜像(含ATF BL31)缺失/为空！"; \
		exit 1; \
	fi
	@echo "✅ TPL + SPL + idbloader + u-boot.itb 全部校验通过"
	@echo "============================================="
endef

define Package/u-boot/install/default
endef

$(eval $(call BuildPackage/U-Boot))
