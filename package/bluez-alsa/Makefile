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
# 上游是 automake 递归（src/Makefile.am：SUBDIRS = shared，然后 asound/bluealsactl/...），
# 生成的 src/Makefile 里 all 只递归一条链，子目录先后本身是有保证的；但 CI 上同一棵树
# world -j 编本包失败、隔 40 分钟 -j1 重跑又能过，且历史上出现过「bluealsad/bluealsactl
# 都有了、src/asound/.libs 里连 .so 都没有」。关掉包内并行去掉这层不确定性，代价几秒。
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
# 本机实测：src/shared 缺失时单独编 src/asound 会立刻报
#   No rule to make target '../shared/libshared.la'
# 所以这里在编译阶段先把 shared 编出来（已是最新时空转几毫秒），让失败点落在编译
# 阶段并带上确切原因；asound 再补一次 make，最后把产物查一遍，缺了直接 exit 1。
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

	# ALSA 插件（pcm + ctl）：只能用写死的静态路径，不写通配符或条件判断。
	# 原因：package-pack.mk 里 .pkgdir 那条规则中的 call Package/<name>/install，
	# 在 eval BuildPackage 阶段就被展开成字面命令；那时 build_dir 还不存在，
	# 通配符必然是空 —— 整条拷贝命令被吃成空行，只剩后面的 [ -f ] 守卫，
	# 于是必然报「缺少 .so」。源一律取 make install 落地到安装暂存目录的副本，
	# 编译阶段已由 Build/Compile 末尾的检查保证产物存在。
	$(INSTALL_DIR) $(1)/usr/lib/alsa-lib
	[ -f $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so ] || { \
		echo "bluez-alsa: 缺少 libasound_module_pcm_bluealsa.so"; \
		echo "  src/asound/.libs:"; ls -la $(PKG_BUILD_DIR)/src/asound/.libs 2>/dev/null; \
		echo "  ipkg-install/usr/lib/alsa-lib:"; ls -la $(PKG_INSTALL_DIR)/usr/lib/alsa-lib 2>/dev/null; \
		exit 1; }
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so $(1)/usr/lib/alsa-lib/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so $(1)/usr/lib/alsa-lib/
	[ -f $(1)/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so ] || { \
		echo "bluez-alsa: 缺少 libasound_module_ctl_bluealsa.so"; exit 1; }

	# pcm.bluealsa / ctl.bluealsa 定义。OpenWrt 的 alsa-lib 是上游原版 alsa.conf，
	# 只加载 /etc/alsa/conf.d（不读 /usr/share/alsa/alsa.conf.d，那是 Debian 的补丁）。
	# 上游 install 会在 /etc/alsa/conf.d 建一条指向 /usr/share 的符号链接，在 DESTDIR
	# 下是断链，所以只取源码树里那份真实文件，装成普通文件。
	$(INSTALL_DIR) $(1)/etc/alsa/conf.d
	[ -f $(PKG_BUILD_DIR)/src/asound/20-bluealsa.conf ] || { \
		echo "bluez-alsa: 缺少 20-bluealsa.conf"; exit 1; }
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/asound/20-bluealsa.conf $(1)/etc/alsa/conf.d/20-bluealsa.conf

	# D-Bus 策略：允许 bluealsad 注册 org.bluealsa（OpenWrt 的 dbus 读 /etc/dbus-1/system.d）
	$(INSTALL_DIR) $(1)/etc/dbus-1/system.d
	[ -f $(PKG_INSTALL_DIR)/etc/dbus-1/system.d/org.bluealsa.conf ] || { \
		echo "bluez-alsa: 缺少 org.bluealsa.conf"; exit 1; }
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/etc/dbus-1/system.d/org.bluealsa.conf $(1)/etc/dbus-1/system.d/org.bluealsa.conf

	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d
	$(INSTALL_CONF) ./files/bluealsa.config $(1)/etc/config/bluealsa
	$(INSTALL_BIN) ./files/bluealsa.init $(1)/etc/init.d/bluealsa
endef

$(eval $(call BuildPackage,bluez-alsa))
