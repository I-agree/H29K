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
  ATF:=rk3528_bl31_v1.17.elf
  TPL:=rk3528_ddr_1056MHz_v1.10.bin
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

# 新增 -j1 单线程 + V=s 详细日志，仅作用于U-Boot内部编译，用于核查TPL/SPL/idbloader/u-boot.itb打包日志
UBOOT_MAKE_FLAGS += \
	-j1 \
	V=s \
	PKG_CONFIG=pkg-config \
	PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig" \
	BINMAN_ALLOW_MISSING=0 \
	BINMAN_INTRUSIVE_AS_NEEDED=1 \
	BL31=$(STAGING_DIR_IMAGE)/$(ATF) \
	$(if $(TPL),ROCKCHIP_TPL=$(STAGING_DIR_IMAGE)/$(TPL)) \
	EXTRA_CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=int-to-pointer-cast -Wno-error=pointer-to-int-cast -Wno-error=int-conversion"

# 🚀 【现代主线化全面适配】彻底打通 U-Boot 2025+ 原生 OF_UPSTREAM 设备树目录
define Build/Prepare
	$(call Build/Prepare/Default)
	# 1. 复制自定义 H29K defconfig 到 U-Boot 基础配置目录
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig $(PKG_BUILD_DIR)/configs/
	
	# 2. 🛠️ 核心修正：适配现代 U-Boot 规范，直接放入真正的 upstream 源码根目录
	mkdir -p $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k-u-boot.dtsi $(PKG_BUILD_DIR)/dts/upstream/src/arm64/rockchip/
	
	# 3. 完整复制hinlink板级全套文件（新版U-Boot规范）
	mkdir -p $(PKG_BUILD_DIR)/board/hinlink/h29k/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink/Kconfig $(PKG_BUILD_DIR)/board/hinlink/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink/h29k/Makefile $(PKG_BUILD_DIR)/board/hinlink/h29k/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink/h29k/Kconfig $(PKG_BUILD_DIR)/board/hinlink/h29k/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink/h29k/board.c $(PKG_BUILD_DIR)/board/hinlink/h29k/
	$(CP) $(TOPDIR)/package/boot/uboot-rockchip/configs/hinlink/h29k/h29k.env $(PKG_BUILD_DIR)/board/hinlink/h29k/
	ls $(PKG_BUILD_DIR)/board/hinlink/h29k/
	
	# ========== 关键修复：注入板子Kconfig到arm顶层，让BOARDDIR正常赋值 ==========
	grep -q 'source "board/hinlink/Kconfig"' $(PKG_BUILD_DIR)/arch/Kconfig || \
	echo 'source "board/hinlink/Kconfig"' >> $(PKG_BUILD_DIR)/arch/Kconfig
	
	# ========== 关键修复：修复 environment.h 生成时 $< 被展开为 FORCE 的问题 ==========
	# cmd_gen_envt 中的 $< 为明确的文件路径 include/generated/env.in
	# FORCE 被意外插入到依赖列表最前面，而awk 必须要正确读取 env.in 文件
	$(TOPDIR)/package/boot/uboot-rockchip/scripts/fix_env_h.sh $(PKG_BUILD_DIR)/Makefile
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(CP) $(PKG_BUILD_DIR)/u-boot-rockchip.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot-rockchip.bin
endef

define Package/u-boot/install/default
endef

$(eval $(call BuildPackage/U-Boot))
