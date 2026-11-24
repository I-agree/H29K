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
PKG_RELEASE:=5

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
# 上游是手写 Makefile（不是 automake 递归），src/asound 的插件要链 src/shared 的
# libbluealsa，-j 下两边的先后没有保证：CI 上就是这样「bluealsad/bluealsactl 都有了、
# src/asound/.libs 里连 .so 都没有」，world 并行那轮直接失败，隔 40 分钟 -j1 重跑又能过。
# 这里关掉包内并行，连带 world 里的这一包也变成串行，代价几秒钟，换确定性。
PKG_BUILD_PARALLEL:=0
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
	--enable-shared --disable-static \
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

# 上游的 all 里 src/asound 属于 SUBDIRS，理论上一定会编；但 CI 上实际出现过
# bluealsad/bluealsactl 都在、src/asound/.libs 里连 .so 都没有的情况，
# 结果一路拖到打包阶段才报一句 cp: cannot stat，完全看不出原因。
# 这里在编译阶段先把 shared 和 asound 各 make 一次（已是最新时空转），
# 然后把产物查一遍：缺了就在 compile 阶段报错，并列出目录内容。
define Build/Compile
	# 先把 src/shared 单独编出来：bluealsad / bluealsactl / asound 插件都链它
	$(MAKE) -C $(PKG_BUILD_DIR)/src/shared $(MAKE_FLAGS)
	$(call Build/Compile/Default)
	$(MAKE) -C $(PKG_BUILD_DIR)/src/asound $(MAKE_FLAGS)
	@[ -f $(PKG_BUILD_DIR)/src/asound/.libs/libasound_module_pcm_bluealsa.so ] || { \
		echo "bluez-alsa: src/asound 没能生成 libasound_module_pcm_bluealsa.so"; \
		echo "  src/asound/:"; ls -la $(PKG_BUILD_DIR)/src/asound/ 2>/dev/null | head -20; \
		echo "  src/asound/.libs/:"; ls -la $(PKG_BUILD_DIR)/src/asound/.libs/ 2>/dev/null | head -20; \
		echo "  全树匹配 asound_module 的文件:"; find $(PKG_BUILD_DIR) -name '*asound_module*' 2>/dev/null | head -20; \
		exit 1; }
endef

define Package/bluez-alsa/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/bluealsad $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/bluealsactl $(1)/usr/bin/

	# ALSA 插件：源文件用 make 层的 $(wildcard) 选，优先取构建目录里的共享模块，
	# 其次取 make install 落地的副本。整段 recipe 里不出现 shell 变量，
	# 免得 $$ 在多级展开中被吃掉、命令变成空字符串。
	$(INSTALL_DIR) $(1)/usr/lib/alsa-lib
	$(if $(firstword $(wildcard $(PKG_BUILD_DIR)/src/asound/.libs/libasound_module_pcm_bluealsa.so $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so)), \
		$(CP) $(firstword $(wildcard $(PKG_BUILD_DIR)/src/asound/.libs/libasound_module_pcm_bluealsa.so $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so)) $(1)/usr/lib/alsa-lib/,)
	$(if $(firstword $(wildcard $(PKG_BUILD_DIR)/src/asound/.libs/libasound_module_ctl_bluealsa.so $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so)), \
		$(CP) $(firstword $(wildcard $(PKG_BUILD_DIR)/src/asound/.libs/libasound_module_ctl_bluealsa.so $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so)) $(1)/usr/lib/alsa-lib/,)
	[ -f $(1)/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so ] || { \
		echo "bluez-alsa: 缺少 libasound_module_pcm_bluealsa.so"; \
		echo "  构建目录 src/asound/.libs:"; ls -la $(PKG_BUILD_DIR)/src/asound/.libs 2>/dev/null; \
		echo "  安装目录 usr/lib/alsa-lib:"; ls -la $(PKG_INSTALL_DIR)/usr/lib/alsa-lib 2>/dev/null; \
		exit 1; }
	[ -f $(1)/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so ] || { \
		echo "bluez-alsa: 缺少 libasound_module_ctl_bluealsa.so"; exit 1; }

	# pcm.bluealsa / ctl.bluealsa 定义。OpenWrt 的 alsa-lib 是上游原版 alsa.conf，
	# 只加载 /etc/alsa/conf.d（不读 /usr/share/alsa/alsa.conf.d，那是 Debian 的补丁）。
	# 注意上游 install 会在 /etc/alsa/conf.d 建一条指向 /usr/share 的符号链接，
	# 在 $${DESTDIR} 下是断链，所以这里只取真实文件再装成普通文件。
	$(INSTALL_DIR) $(1)/etc/alsa/conf.d
	$(if $(firstword $(wildcard $(PKG_BUILD_DIR)/src/asound/20-bluealsa.conf $(PKG_INSTALL_DIR)/usr/share/alsa/alsa.conf.d/20-bluealsa.conf)), \
		$(INSTALL_DATA) $(firstword $(wildcard $(PKG_BUILD_DIR)/src/asound/20-bluealsa.conf $(PKG_INSTALL_DIR)/usr/share/alsa/alsa.conf.d/20-bluealsa.conf)) $(1)/etc/alsa/conf.d/20-bluealsa.conf,)
	[ -f $(1)/etc/alsa/conf.d/20-bluealsa.conf ] || { \
		echo "bluez-alsa: 缺少 20-bluealsa.conf"; exit 1; }

	# D-Bus 策略：允许 bluealsad 注册 org.bluealsa（OpenWrt 的 dbus 读 /etc/dbus-1/system.d）
	$(INSTALL_DIR) $(1)/etc/dbus-1/system.d
	$(if $(firstword $(wildcard $(PKG_INSTALL_DIR)/etc/dbus-1/system.d/org.bluealsa.conf $(PKG_BUILD_DIR)/src/org.bluealsa.conf)), \
		$(INSTALL_DATA) $(firstword $(wildcard $(PKG_INSTALL_DIR)/etc/dbus-1/system.d/org.bluealsa.conf $(PKG_BUILD_DIR)/src/org.bluealsa.conf)) $(1)/etc/dbus-1/system.d/org.bluealsa.conf,)
	[ -f $(1)/etc/dbus-1/system.d/org.bluealsa.conf ] || { \
		echo "bluez-alsa: 缺少 org.bluealsa.conf"; exit 1; }

	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d
	$(INSTALL_CONF) ./files/bluealsa.config $(1)/etc/config/bluealsa
	$(INSTALL_BIN) ./files/bluealsa.init $(1)/etc/init.d/bluealsa
endef

$(eval $(call BuildPackage,bluez-alsa))
