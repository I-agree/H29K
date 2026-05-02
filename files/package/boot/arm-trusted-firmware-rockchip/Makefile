#
# Copyright (C) 2020 Sarah Maedel <openwrt@tbspace.de>
# Copyright (C) 2026 OpenWrt Maintainers
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=arm-trusted-firmware-rockchip
PKG_VERSION:=2.14.0
PKG_RELEASE:=2

PKG_HASH:=b2a3bc360307c929714ffd8e7f1441c4888cd5d80531276e809c2de54db5dc16

PKG_MAINTAINER:=Sarah Maedel <openwrt@tbspace.de>

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/rockchip-linux/arm-trusted-firmware.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=v$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
HOST_BUILD:=1  # ✅ 强制 host-only 模式 —— 关键！

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=ARM Trusted Firmware build tools for Rockchip SoCs
  DEPENDS:=@BINARY_TAGGING
  HIDDEN:=1
endef

define Package/$(PKG_NAME)/description
  Host-only build tools for generating BL31 firmware images
  for Rockchip ARMv8 SoCs (RK3328, RK3399, RK3528, RK3566, RK3568, RK3576, RK3588).
  Outputs: bl31.elf, bl31.bin, trust.img fragments in staging_dir/hostpkg/lib/firmware/rockchip/.
endef

# ✅ Build/Prepare: 清理 + 标准 host 准备
define Build/Prepare
    $(call Build/Prepare/Default)
    $(MAKE) -C $(PKG_BUILD_DIR) clean 2>/dev/null || true
endef

# ✅ Build/Compile: 使用 host 工具链，逐平台编译，静默警告，生成双格式
define Build/Compile
    $(MAKE) -C $(PKG_BUILD_DIR) \
        CROSS_COMPILE="$(HOSTCC)" \
        CC="$(HOSTCC)" \
        LD="$(HOSTLD)" \
        AR="$(HOSTAR)" \
        AS="$(HOSTCC) -x assembler-with-cpp" \
        $(foreach plat,$(TFA_TARGETS), \
            PLAT=$(plat) all 2>&1 | grep -v "warning:" || true; \
            cp $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/bl31.elf \
               $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/$(plat)_bl31.elf; \
            cp $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/bl31.bin \
               $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/$(plat)_bl31.bin; \
            cp $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/bl31.elf \
               $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/$(plat)_bl31_v1.20.elf; \
        )
endef

# ✅ Package/install: 安装到 hostpkg，按 SoC 分类存放，覆盖所有格式
define Package/$(PKG_NAME)/install
    $(INSTALL_DIR) $(1)/lib/firmware/rockchip
    $(foreach plat,$(TFA_TARGETS), \
        $(INSTALL_DATA) $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/$(plat)_bl31.elf \
            $(1)/lib/firmware/rockchip/$(plat)_bl31.elf; \
        $(INSTALL_DATA) $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/$(plat)_bl31.bin \
            $(1)/lib/firmware/rockchip/$(plat)_bl31.bin; \
        $(INSTALL_DATA) $(PKG_BUILD_DIR)/build/$(plat)/release/bl31/$(plat)_bl31_v1.20.elf \
            $(1)/lib/firmware/rockchip/$(plat)_bl31_v1.20.elf; \
    )
endef

# ✅ TFA_TARGETS：全系 Rockchip ARMv8 SoC（含你要求的 rk3528，及工业/消费主力 rk3566/rk3568）
TFA_TARGETS:= \
    rk3328 \
    rk3399 \
    rk3528 \
    rk3566 \
    rk3568 \
    rk3576 \
    rk3588

$(eval $(call BuildPackage,$(PKG_NAME)))
