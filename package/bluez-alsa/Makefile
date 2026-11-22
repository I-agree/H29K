#
# bluez-alsa — 给蓝牙音频（A2DP source）提供 ALSA 后端
#
# 作用：BlueZ 只负责蓝牙协议，自己不发声。没有进程去"消费"A2DP 音频流，
#       远端耳机/音箱在连上后几秒内就会主动断开（甚至删掉配对信息）。
#       bluealsad 通过 BlueZ Media API 注册 A2DP source 端点，并把流暴露成
#       ALSA PCM "bluealsa"，任何 ALSA 程序（aplay / gmediarender …）都能往
#       蓝牙设备推流。
#
# 不绑定固定 MAC：ALSA 设备名 bluealsa 的默认 DEV 是 00:00:00:00:00:00，
#       含义是"当前最近连接的那台 A2DP 设备"，web 上哪个耳机/音箱连上就发给谁。
#

include $(TOPDIR)/rules.mk

PKG_NAME:=bluez-alsa
PKG_VERSION:=5.0.0
PKG_RELEASE:=2

# 上游最新的 tag 就是 v5.0.0（2026-08-27），之后没有新 tag；
# 这里钉的是 master 上最新的提交（2026-10-26），比 tag 多两个月的修复。
# 想退回正式的 v5.0.0 版本，把 PKG_SOURCE_VERSION 换成 tag 提交
# 1935d6dcb8975f2d7a51aaafe61538d157224623 即可，其余不用改。
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/Arkq/bluez-alsa.git
PKG_SOURCE_VERSION:=8bac18dbcbe55139d873dc6e8dbaf6ba95de60b8
PKG_MIRROR_HASH:=skip

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=H29K

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1
PKG_FIXUP:=autoreconf

# configure.ac 要求 gdbus-codegen；由 glib2 的 host 包提供
PKG_BUILD_DEPENDS:=glib2/host

include $(INCLUDE_DIR)/package.mk

define Package/bluez-alsa
  SECTION:=sound
  CATEGORY:=Sound
  TITLE:=Bluetooth Audio ALSA backend (A2DP source)
  URL:=https://github.com/Arkq/bluez-alsa
  DEPENDS:=+alsa-lib +bluez-libs +libdbus +glib2 +sbc +dbus
endef

define Package/bluez-alsa/description
 BlueALSA：把蓝牙音频设备变成普通 ALSA PCM。
 只带 A2DP source（本机当播放端，推流给耳机/音箱）+ 必选 SBC 编解码，
 不带 AAC/aptX/LDAC/HFP（HFP 需要 oFono，本机用不到）。
 安装后在 /etc/config/bluealsa 里开关，ALSA 设备名为 bluealsa。
endef

# 只保留 A2DP source 需要的东西：SBC 是强制的，其余可选编解码全部关掉；
# HFP/HSP 走 oFono，本机没有，也关掉；man/tcl 界面/工具一律不装。
CONFIGURE_ARGS += \
	--disable-aac \
	--disable-aptx \
	--disable-aptx-hd \
	--disable-asha \
	--disable-faststream \
	--disable-lc3plus \
	--disable-lc3-swb \
	--disable-ldac \
	--disable-lhdc \
	--disable-midi \
	--disable-mp3lame \
	--disable-mpg123 \
	--disable-msbc \
	--disable-opus \
	--disable-ofono \
	--disable-systemd \
	--disable-upower \
	--disable-manpages \
	--disable-test \
	--disable-rfcomm \
	--disable-a2dpconf \
	--disable-hcitop \
	--disable-aplay

define Package/bluez-alsa/conffiles
/etc/config/bluealsa
endef

define Package/bluez-alsa/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/bluealsad $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/bluealsactl $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/usr/lib/alsa-lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so $(1)/usr/lib/alsa-lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so $(1)/usr/lib/alsa-lib/

	# pcm.bluealsa / ctl.bluealsa 的 ALSA 配置，alsa-lib 会自动读取 conf.d
	$(INSTALL_DIR) $(1)/usr/share/alsa/alsa.conf.d
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/share/alsa/alsa.conf.d/20-bluealsa.conf $(1)/usr/share/alsa/alsa.conf.d/

	# 允许 bluealsa 在系统 D-Bus 上注册 org.bluealsa 服务
	$(INSTALL_DIR) $(1)/usr/share/dbus-1/system.d
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/share/dbus-1/system.d/org.bluealsa.conf $(1)/usr/share/dbus-1/system.d/

	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d
	$(INSTALL_CONF) ./files/bluealsa.config $(1)/etc/config/bluealsa
	$(INSTALL_BIN) ./files/bluealsa.init $(1)/etc/init.d/bluealsa
endef

$(eval $(call BuildPackage,bluez-alsa))
