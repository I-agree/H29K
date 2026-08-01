#
# Copyright (C) 2026 Hinlink
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=axs5106
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/axs5106
  SUBMENU:=Input modules
  TITLE:=ChipOne AXS5106 touchscreen driver
  DEPENDS:=+kmod-i2c-core +kmod-input-core
  KCONFIG:=CONFIG_TOUCHSCREEN_CHIPONE_AXS5106
  FILES:=$(PKG_BUILD_DIR)/chipone_axs5106.ko
  AUTOLOAD:=$(call AutoProbe,chipone_axs5106)
  DEFAULT:=y
endef

define KernelPackage/axs5106/description
  ChipOne / AXS Technology AXS5106L capacitive touch controller
  I2C driver (address 0x63, 8-bit register, 2-point multitouch).
endef

define Build/Prepare
    mkdir -p $(PKG_BUILD_DIR)
    $(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
    $(KERNEL_MAKE) M=$(PKG_BUILD_DIR) modules
endef

$(eval $(call KernelPackage,axs5106))
