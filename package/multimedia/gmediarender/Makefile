#
# gmediarender — UPnP/DLNA 媒体渲染器（gmrender-resurrect）
#
# 放置位置：package/multimedia/gmediarender/Makefile
#
# 上游：https://github.com/hzeller/gmrender-resurrect
# 分支：master（无 tag/release），取 2026-11-02 的快照
# 完整 SHA：8a99c64f5e7f29ca4107f4cf283251c1cfcec0d1
#
# 上游仓库不提交 configure 脚本，只有 autogen.sh（内容即 autoreconf -vfi），
# 因此用 OpenWrt 的 PKG_FIXUP:=autoreconf 在编译前自动生成 configure，
# 等价于 INSTALL.md 中的 ./autogen.sh。
#
# 目标设备：H29K（RK3528 / aarch64 / 内核 6.18.60 / OpenWrt SNAPSHOT）
# 该机器只有一张 HDMI 声卡（card0 = rockchiphdmi，有 pcmC0D0p），没有模拟输出，
# 所以「投屏」= 视频走 DRM/KMS 直接上屏 + 音频走 HDMI PCM。详见 README.md。
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gmediarender

# 上游 configure.ac 的 AC_INIT 版本是 0.3.1，master 上没有规范版本号，
# 所以用「0.3.1 + 快照日期」保证版本可比较
PKG_VERSION:=0.3.1+git20261102
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/hzeller/gmrender-resurrect.git
PKG_SOURCE_DATE:=2026-11-02
PKG_SOURCE_VERSION:=8a99c64f5e7f29ca4107f4cf283251c1cfcec0d1
PKG_MIRROR_HASH:=skip

# 提交到 feed 时改成实际维护者
#PKG_MAINTAINER:=Your Name <you@example.com>

PKG_LICENSE:=GPL-2.0-or-later
PKG_LICENSE_FILES:=COPYING

# 关键：仓库没有 configure，必须 autoreconf（= 上游 autogen.sh）
PKG_FIXUP:=autoreconf
PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1

# 视频 sink：kmssink（DRM 直接送显示平面），必须搭配
#   extras/0001-gst1-plugins-bad-enable-kmssink.patch（OpenWrt 默认把 kms 关掉了）
#
# 为什么不是 fbdevsink：本机内核没开 DRM fbdev 模拟，没有 /dev/fb0、也没有 /proc/fb，
# fbdevsink 无处可写。kmssink 走 /dev/dri/card0（= rockchip-drm：vop@ff840000 +
# dwhdmi@ff8d0000，connector card0-HDMI-A-1），这就是唯一的出图路径。
#
# 硬件解码：靠 kernel-patches/vdec-v2 里的 997g + 998 + 1000 打出来的 /dev/video0
# （rkvdec 驱动 + RK3528 MMU 双 bank + clk_hevc_cabac），再由 gst1-mod-v4l2codecs
# 提供 v4l2slh264dec / v4l2slh265dec（stateless 解码器，playbin 自动优先选硬件）。
#
# 为什么 gst1-mod-v4l2codecs 必须写进 DEPENDS（不能只写在 .config 里）：
#   feeds 里所有 gst1-mod-* 都是 GstBuildPlugin 生成的包，宏里固定写了 HIDDEN:=1，
#   scripts/package-metadata.pl 遇到 hidden 会把 Kconfig title 置空 → 生成的符号没有 prompt，
#   make defconfig 会直接丢掉手写的 CONFIG_PACKAGE_gst1-mod-v4l2codecs=y。
#   隐藏符号只能被"可见包"的 DEPENDS 里的 + 号（= Kconfig select）带进来。
#   gmediarender 本身就是可见包，所以把需要的能力全部写在这里，
#   .config 里只写 CONFIG_PACKAGE_gmediarender=y 就够了，不需要额外造元包。
#
# 只做音频 / 只想先让包编过时，把 KMS_DEPS 清空并把 videosink 设空即可（会退回 autovideosink）。
#
# 注意 gst1-mod-kms 这个包名只有在 feeds 的 gst1-plugins-bad/Makefile 打了
# extras/0001-gst1-plugins-bad-enable-kmssink.patch 之后才存在（GstBuildPlugin,kms,...）；
# 没打补丁时直接写死 +gst1-mod-kms 会让整个构建报 "dependency on 'gst1-mod-kms',
# which does not exist"，所以这里探测一下再决定要不要硬依赖。
GST_BAD_MK:=$(firstword $(wildcard $(TOPDIR)/feeds/*/multimedia/gst1-plugins-bad/Makefile))
KMS_PATCHED:=$(shell grep -l "GstBuildPlugin,kms" $(GST_BAD_MK) 2>/dev/null)
KMS_DEPS:=+libgst1allocators +libgst1video +libdrm $(if $(KMS_PATCHED),+gst1-mod-kms)

include $(INCLUDE_DIR)/package.mk

# 依赖换算（对照 INSTALL.md）：
#   libupnp-dev                  -> libupnp（configure 要求 libupnp >= 1.6.0）
#   glib-2.0 / gthread-2.0       -> glib2
#   libgstreamer1.0-dev          -> libgstreamer1（缺了会在编译阶段直接 #error）
#   gstreamer1.0-alsa + plugins  -> gst1-mod-alsa 等，见下面 DEPENDS
#
# 音频链路：playbin -> audioconvert/audioresample -> alsasink(device=plughw:0,0)
# 视频链路：playbin -> videoconvert/videoscale -> kmssink
#   playbin 内部会自动插 videoconvert/videoscale，所以必须带 gst1-mod-videoconvertscale，
#   否则视频 sink 协商不到格式：表现为有声音、画面黑屏，或报 not-negotiated。
#
# 解码：H.264/H.265/AAC/MP3 等交给 gst1-libav（体积较大，但这台机器是视频投屏，
#   需要它；只做纯音频可去掉 gst1-libav、matroska、mpegtsdemux、videoparsersbad）。
#
# 注意 libupnp 的隐藏前提：上游 upnp_device.c 直接 #include <upnptools.h>，
# 该头文件只有 libupnp 编译时打开 helper API（cmake -Dtools=ON / UPNP_ENABLE_HELPER_API_TOOLS=ON）
# 才会安装。OpenWrt packages feed 的 libupnp 默认就是 -Dtools=ON，正常无需处理。

define Package/gmediarender
  SECTION:=multimedia
  CATEGORY:=Multimedia
  TITLE:=UPnP/DLNA media renderer (gmrender-resurrect)
  URL:=https://github.com/hzeller/gmrender-resurrect
  DEPENDS:=+libupnp +glib2 +libgstreamer1 \
	+gst1-mod-playback \
	+gst1-mod-alsa \
	+gst1-mod-audioconvert \
	+gst1-mod-audioresample \
	+gst1-mod-volume \
	+gst1-mod-typefindfunctions \
	+gst1-mod-pbtypes \
	+gst1-mod-videoconvertscale \
	+gst1-mod-soup \
	+gst1-mod-audioparsers \
	+gst1-mod-videoparsersbad \
	+gst1-mod-v4l2codecs \
	+gst1-mod-mpegpsdemux \
	+gst1-mod-avi \
	+gst1-mod-ogg \
	+gst1-mod-vorbis \
	+gst1-mod-opus \
	+gst1-mod-theora \
	+gst1-mod-vpx \
	+gst1-mod-id3demux \
	+gst1-mod-autodetect \
	+gst1-mod-isomp4 \
	+gst1-mod-matroska \
	+gst1-mod-mpegtsdemux \
	+gst1-mod-mpg123 \
	+gst1-mod-flac \
	+gst1-mod-faad \
	+gst1-mod-wavparse \
	+gst1-libav \
	$(KMS_DEPS)
endef

define Package/gmediarender/description
 gmediarender is a headless UPnP/DLNA media renderer: it advertises itself on the
 network and plays audio/video pushed by a UPnP/DLNA control point, decoding and
 rendering through GStreamer. On boards without any display stack (H29K/RK3528)
 it renders video straight to the DRM/KMS plane and audio to the HDMI PCM.
endef

define Package/gmediarender/conffiles
/etc/config/gmediarender
endef

# 上游 make install 的实际产物（已实测）：
#   $(bindir)/gmediarender
#   $(datadir)/gmediarender/grender-64x64.png、grender-128x128.png
# 后者是 webserver 给控制器返回封面时的兜底图标，按 PKG_DATADIR 去 stat，不能漏装。
define Package/gmediarender/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/gmediarender $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/usr/share/gmediarender
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/share/gmediarender/*.png \
		$(1)/usr/share/gmediarender/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/gmediarender.init $(1)/etc/init.d/gmediarender

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/gmediarender.config $(1)/etc/config/gmediarender
endef

$(eval $(call BuildPackage,gmediarender))
