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
PKG_RELEASE:=3

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
# 插件的安装目录与 D-Bus 策略目录都钉死：默认值靠 pkg-config 的 libdir/datadir
# 变量推导，跨编译环境下不稳定（本次就出现插件没落到 /usr/lib/alsa-lib）。
# 同时 OpenWrt 的 dbus 只读 /etc/dbus-1/system.d，不可能用上游默认的 /usr/share。
CONFIGURE_ARGS += \
	--with-alsaplugindir=/usr/lib/alsa-lib \
	--with-dbusconfdir=/etc/dbus-1/system.d \
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

	# ALSA 插件：先用 install 出来的，没有再退回 build 目录。
	# 不同 pkg-config 布局下 make install 的落点不一定是 /usr/lib/alsa-lib，
	# 所以这里不写死单一来源，最后统一断言两个 .so 都在。
	$(INSTALL_DIR) $(1)/usr/lib/alsa-lib
	for f in \
		$(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so \
		$(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so \
		$(PKG_BUILD_DIR)/src/asound/.libs/libasound_module_pcm_bluealsa.so \
		$(PKG_BUILD_DIR)/src/asound/.libs/libasound_module_ctl_bluealsa.so; do \
		[ -f "$$f" ] && $(CP) "$$f" $(1)/usr/lib/alsa-lib/; \
	done; \
	for m in pcm ctl; do \
		[ -f $(1)/usr/lib/alsa-lib/libasound_module_$${m}_bluealsa.so ] || { \
			echo "bluez-alsa: 缺少 libasound_module_$${m}_bluealsa.so"; exit 1; }; \
	done

	# pcm.bluealsa / ctl.bluealsa 定义。OpenWrt 的 alsa-lib 是上游原版 alsa.conf，
	# 只加载 /etc/alsa/conf.d（不读 /usr/share/alsa/alsa.conf.d，那是 Debian 的补丁）。
	$(INSTALL_DIR) $(1)/etc/alsa/conf.d
	for f in \
		$(PKG_INSTALL_DIR)/etc/alsa/conf.d/20-bluealsa.conf \
		$(PKG_INSTALL_DIR)/usr/share/alsa/alsa.conf.d/20-bluealsa.conf \
		$(PKG_BUILD_DIR)/src/asound/20-bluealsa.conf; do \
		[ -f "$$f" ] && { $(INSTALL_DATA) "$$f" $(1)/etc/alsa/conf.d/20-bluealsa.conf; break; }; \
	done; \
	[ -f $(1)/etc/alsa/conf.d/20-bluealsa.conf ] || { \
		echo "bluez-alsa: 缺少 20-bluealsa.conf"; exit 1; }

	# D-Bus 策略：允许 bluealsad 注册 org.bluealsa（OpenWrt 的 dbus 读 /etc/dbus-1/system.d）
	$(INSTALL_DIR) $(1)/etc/dbus-1/system.d
	for f in \
		$(PKG_INSTALL_DIR)/etc/dbus-1/system.d/org.bluealsa.conf \
		$(PKG_INSTALL_DIR)/usr/share/dbus-1/system.d/org.bluealsa.conf \
		$(PKG_BUILD_DIR)/src/org.bluealsa.conf; do \
		[ -f "$$f" ] && { $(INSTALL_DATA) "$$f" $(1)/etc/dbus-1/system.d/org.bluealsa.conf; break; }; \
	done; \
	[ -f $(1)/etc/dbus-1/system.d/org.bluealsa.conf ] || { \
		echo "bluez-alsa: 缺少 org.bluealsa.conf"; exit 1; }

	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d
	$(INSTALL_CONF) ./files/bluealsa.config $(1)/etc/config/bluealsa
	$(INSTALL_BIN) ./files/bluealsa.init $(1)/etc/init.d/bluealsa
endef

$(eval $(call BuildPackage,bluez-alsa))
