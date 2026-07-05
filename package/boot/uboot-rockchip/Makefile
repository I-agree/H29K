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
  BL31=$(STAGING_DIR_IMAGE)/$(ATF) \
  $(if $(TPL),ROCKCHIP_TPL=$(STAGING_DIR_IMAGE)/$(TPL))

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(CP) $(PKG_BUILD_DIR)/u-boot-rockchip.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot-rockchip.bin
endef

define Package/u-boot/install/default
endef

# ===== BEGIN BINMAN DIAGNOSTICS HOOK =====
define Build/U-Boot/DiagnoseBinman
	@echo "========== [DIAG] Dumping binman nodes from DTB ==========" | tee $(PKG_BUILD_DIR)/binman_diag.log
	@dtc -I dtb -O dts \
		$(PKG_BUILD_DIR)/arch/arm/dts/rk3528-hinlink-h29k.dtb \
		2>/dev/null | grep -B2 -A15 'binman\|rockchip-tpl\|atf-bl31\|simple-bin\|u-boot-spl' \
		>> $(PKG_BUILD_DIR)/binman_diag.log 2>&1 || true

	@echo "========== [DIAG] Running binman manually ==========" | tee -a $(PKG_BUILD_DIR)/binman_diag.log
	@cd $(PKG_BUILD_DIR) && python3 tools/binman/binman \
		--toolpath $(STAGING_DIR_HOST)/bin \
		-D arch/arm/dts/rk3528-hinlink-h29k.dtb \
		-a bl31=$(STAGING_DIR_IMAGE)/$(ATF) \
		-a rockchip-tpl=$(STAGING_DIR_IMAGE)/$(TPL) \
		build u-boot-rockchip.bin \
		>> $(PKG_BUILD_DIR)/binman_diag.log 2>&1 || true

	@echo "========== [DIAG] Full log below =========="
	@cat $(PKG_BUILD_DIR)/binman_diag.log
endef

# 将诊断钩子挂载到 U-Boot 编译步骤之前
# 注意：这里复用了你 Makefile 中已定义的 $(ATF) 和 $(TPL) 变量
HOOKS_TARGET := U-Boot/Compile/Pre
$(eval $(call Build/U-Boot/DiagnoseBinman))
# ===== END BINMAN DIAGNOSTICS HOOK =====

$(eval $(call BuildPackage/U-Boot))
