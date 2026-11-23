# SPDX-License-Identifier: MIT
#
# LuCI Bluetooth Manager for HINLINK H29K (AIC8800 SDIO + BT over UART)

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-btmanager
PKG_VERSION:=1.7
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=H29K <h29k@local>

LUCI_TITLE:=Bluetooth manager (scan / pair / connect / HID / auto-connect)
LUCI_DEPENDS:=+luci-base +bluez-daemon +bluez-utils +bluez-utils-extra +dbus +kmod-bluetooth

LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
