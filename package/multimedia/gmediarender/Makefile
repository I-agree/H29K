#
# Copyright (C) 2020 coolsnowwolf@gmail.com
# Updated for HINLINK H29K (RK3528) / OpenWrt 25.12 / Kernel 6.18
# Secure Single-File Build with Inline Procd Init Script
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gmediarender
PKG_SOURCE_VERSION:=master
PKG_VERSION:=git-$(shell echo $(PKG_SOURCE_VERSION) | cut -c1-8)
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/hzeller/gmrender-resurrect.git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz

PKG_FIXUP:=autoreconf
PKG_INSTALL:=1
PKG_REMOVE_FILES:=autogen.sh aclocal.m4

PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING
PKG_MAINTAINER:=Community

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/nls.mk

define Package/gmediarender
	SECTION:=multimedia
	CATEGORY:=Multimedia
	TITLE:=UPnP/DLNA Media Renderer for H29K HDMI Output
	URL:=https://github.com/hzeller/gmrender-resurrect
	DEPENDS:= \
		+glib2 \
		+libupnp \
		+gstreamer1 \
		+gstreamer1-plugins-base \
		+gstreamer1-plugins-good \
		+gstreamer1-plugins-bad \
		+gstreamer1-plugins-ugly \
		+gstreamer1-libav \
		+alsa-lib
endef

define Package/gmediarender/description
	Lightweight headless UPnP/DLNA media renderer, optimized for H29K RK3528 platform.
	Outputs video/audio directly to HDMI via KMS/DRM (kmssink), no desktop required.
	Integrated with OpenWrt 25.12 procd service manager.
endef

TARGET_CFLAGS += -std=gnu99

CONFIGURE_ARGS += \
	--with-build-cc="$(HOSTCC)" \
	--prefix=/usr \
	--disable-silent-rules

define Package/gmediarender/install
	# 1. 安装主程序
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/$(PKG_NAME) $(1)/usr/bin/

	# 2. 预装适配 H29K 的 procd 启动脚本
	$(INSTALL_DIR) $(1)/etc/init.d
	cat << 'EOF' > $(1)/etc/init.d/gmediarender
#!/bin/sh /etc/rc.common
# Optimized for HINLINK H29K (RK3528) / OpenWrt 25.12

START=99
STOP=10
USE_PROCD=1

PROG=/usr/bin/gmediarender
DEVICE_NAME="H29K-DLNA"
VIDEO_SINK="kmssink connector=HDMI-A-1"
AUDIO_SINK="alsasink"
AUDIO_DEVICE="hw:0,0"

start_service() {
	procd_open_instance
	procd_set_param command "$$PROG" \
		-f "$$DEVICE_NAME" \
		--gstout-videosink="$$VIDEO_SINK" \
		--gstout-audiosink="$$AUDIO_SINK" \
		--gstout-audiodevice="$$AUDIO_DEVICE" \
		--gstout-initial-volume-db=0 \
		-d

	procd_set_param netdev
	procd_set_param stdout 1
	procd_set_param stderr 1
	procd_set_param respawn 3600 5 5
	procd_close_instance
}

EOF
	chmod 0755 $(1)/etc/init.d/gmediarender

	# 3. 附带上游示例脚本，仅作参考
	$(INSTALL_DIR) $(1)/usr/share/gmediarender
	if [ -f $(PKG_BUILD_DIR)/scripts/init.d/gmediarenderer ]; then \
		$(INSTALL_DATA) $(PKG_BUILD_DIR)/scripts/init.d/gmediarenderer $(1)/usr/share/gmediarender/; \
	fi
endef

$(eval $(call BuildPackage,gmediarender))
