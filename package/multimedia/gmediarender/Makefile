#
# Copyright (C) 2020 coolsnowwolf@gmail.com
# Updated for HINLINK H29K (RK3528) / OpenWrt 25.12 / Kernel 6.18
# Features: master rolling branch + full soft-decode deps + procd init + HDMI preset
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gmediarender
PKG_VERSION:=git-master
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/hzeller/gmrender-resurrect.git
# 实时跟踪 master 分支，不固定 commit
PKG_SOURCE_VERSION:=master
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
# 跳过哈希校验，适配滚动更新
PKG_MIRROR_HASH:=skip

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
	# 所有依赖均为标准 feed 自带，无额外移植需求
	DEPENDS:= \
		+glib2 \
		+libupnp \
		+gstreamer1 \
		+libgstreamer1 \
		+gstreamer1-plugins-base \
		+gstreamer1-plugins-good \
		+gstreamer1-plugins-bad \
		+gstreamer1-plugins-ugly \
		+gstreamer1-libav \
		+avahi-daemon \
		+alsa-utils
endef

define Package/gmediarender/description
	Lightweight headless UPnP/DLNA media renderer, optimized for H29K RK3528 platform.
	Outputs video/audio directly to HDMI via KMS/DRM (kmssink), no desktop required.
	Pre-configured with HDMI-A-1 connector and HDMI audio device.
	Tracks upstream master branch.
endef

CONFIGURE_ARGS += \
	CFLAGS="$(TARGET_CFLAGS) -std=gnu99 -O2" \
	--with-build-cc="$(HOSTCC)" \
	--prefix=/usr \
	--disable-silent-rules

define Package/gmediarender/install
	# 主程序安装
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/$(PKG_NAME) $(1)/usr/bin/

	# 预装适配 H29K 的 procd 启动脚本，参数已硬件级精准匹配
	$(INSTALL_DIR) $(1)/etc/init.d
	( \
		echo '#!/bin/sh /etc/rc.common'; \
		echo ''; \
		echo 'START=99'; \
		echo 'USE_PROCD=1'; \
		echo ''; \
		echo 'PROG=/usr/bin/gmediarender'; \
		echo 'DEVICE_NAME="H29K-DLNA"'; \
		echo 'VIDEO_SINK="kmssink connector=HDMI-A-1"'; \
		echo 'AUDIO_SINK="alsasink"'; \
		echo 'AUDIO_DEVICE="hw:0,0"'; \
		echo ''; \
		echo 'start_service() {'; \
		echo '    procd_open_instance'; \
		echo '    procd_set_param command $$$$PROG \\'; \
		echo '        -f "$$$$DEVICE_NAME" \\'; \
		echo '        --gstout-videosink="$$$$VIDEO_SINK" \\'; \
		echo '        --gstout-audiosink="$$$$AUDIO_SINK" \\'; \
		echo '        --gstout-audiodevice="$$$$AUDIO_DEVICE" \\'; \
		echo '        --gstout-initial-volume-db=0 \\'; \
		echo '        -d'; \
		echo '    procd_set_param respawn threshold=3600 timeout=5 retry=5'; \
		echo '    procd_close_instance'; \
		echo '}'; \
		echo ''; \
		echo 'stop_service() {'; \
		echo '    killall gmediarender 2>/dev/null'; \
		echo '}'; \
	) > $(1)/etc/init.d/gmediarender
	chmod 0755 $(1)/etc/init.d/gmediarender

	# 附带上游示例脚本，仅作参考
	$(INSTALL_DIR) $(1)/usr/share/gmediarender
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/scripts/init.d/gmediarenderer $(1)/usr/share/gmediarender/
endef

$(eval $(call BuildPackage,gmediarender))
