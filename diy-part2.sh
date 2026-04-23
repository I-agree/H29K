#!/bin/bash

# --- 1. 环境基础修复 ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 2. 硬件支持文件下载 ---
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_BIN_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"

mkdir -p "$DTS_PATH"
curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts" || exit 1
curl -fsSL "$BOOT_BIN_URL" > hinlink_h29k-u-boot-rockchip.bin || exit 1
mkdir -p bin/targets/rockchip/armv8
cp hinlink_h29k-u-boot-rockchip.bin bin/targets/rockchip/armv8/

# --- 3. 动态注入 video.mk (定义静态驱动包) ---
VIDEO_MK="package/kernel/linux/modules/video.mk"
sed -i '/KernelPackage\/h29k-fb-st7789v/,/eval $(call KernelPackage,h29k-fb-st7789v)/d' "$VIDEO_MK"
cat >> "$VIDEO_MK" <<EOF
define KernelPackage/h29k-fb-st7789v
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=ST7789V LCD support (Built-in)
  DEPENDS:=+kmod-fb +kmod-fb-cfb-fillrect +kmod-fb-cfb-copyarea +kmod-fb-cfb-imgblt
  KCONFIG:=CONFIG_FB_TFT=y CONFIG_FB_TFT_ST7789V=y
  FILES:=
  AUTOLOAD:=
endef
\$(eval \$(call KernelPackage,h29k-fb-st7789v))
EOF

# --- 4. 强制内核配置 (全静态编译驱动 & BBR & 5G 物理支持) ---
find target/linux/rockchip/armv8/ -name "config-*" | while read CONF; do
    sed -i '/CONFIG_STAGING/d' "$CONF"
    sed -i '/CONFIG_FB_TFT/d' "$CONF"
    sed -i '/CONFIG_TCP_CONG/d' "$CONF"
    {
        echo "CONFIG_STAGING=y"
        echo "CONFIG_FB=y"
        echo "CONFIG_FB_TFT=y"
        echo "CONFIG_FB_TFT_ST7789V=y"
        echo "CONFIG_SPI=y"
        echo "CONFIG_TCP_CONG_ADVANCED=y"
        echo "CONFIG_TCP_CONG_BBR=y"
        echo "CONFIG_DEFAULT_BBR=y"
        echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\""
        # FM350-GL 物理层支持
        echo "CONFIG_MTK_T7XX=m"
        echo "CONFIG_USB_NET_CDC_MBIM=m"
        echo "CONFIG_USB_NET_RNDIS_HOST=m"
        echo "CONFIG_USB_SERIAL_OPTION=m"
    } >> "$CONF"
done

# --- 5. 注册 H29K 设备并补全依赖 (基于 H28K 逻辑) ---
TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
if [ -n "$TARGET_MK" ]; then
    cat >> "$TARGET_MK" <<EOF
define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  DEVICE_DTS_DIR := \$(LINUX_DIR)/arch/arm64/boot/dts/rockchip
  UBOOT_DEVICE_NAME := hinlink_h29k
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | rockchip-img | gzip | append-metadata
  KERNEL_SIZE := 32768k
  BOARD_ROOTFS_PARTSIZE := 1024
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-usb-net-rtl8152 kmod-r8169 \\
	kmod-aic8800-sdio wpad-openssl -wpad-basic -wpad-mini -wpad -urngd \\
	dnsmasq-full -dnsmasq \\
	kmod-mtk_t7xx kmod-usb-net-cdc-mbim kmod-usb-net-qmi-wwan uqmi \\
	kmod-usb-net-rndis-host kmod-usb-serial-option kmod-usb-serial-qualcomm \\
	kmod-fb kmod-fb-cfb-fillrect kmod-fb-cfb-copyarea kmod-fb-cfb-imgblt \\
	kmod-h29k-fb-st7789v \\
	irqbalance luci-app-irqbalance luci-i18n-irqbalance-zh-cn \\
	luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn -luci-app-qmodem \\
	-modemmanager -libmbim -libqmi \\
	luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-theme-argon
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# --- 6. 注入官方 H28K 种子配置并“克隆”为 H29K ---
cat > .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k=y
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_h29k=y
# 满血包选中
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_luci-app-qmodem-next=y
CONFIG_PACKAGE_luci-i18n-qmodem-next-zh-cn=y
CONFIG_PACKAGE_kmod-h29k-fb-st7789v=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

# --- 7. 系统默认值与冲突预警 ---
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k-custom <<EOF
#!/bin/sh
/etc/init.d/modemmanager stop 2>/dev/null
/etc/init.d/modemmanager disable 2>/dev/null
uci set luci.main.mediaurlbase='/luci-static/argon'
uci set luci.main.lang='zh_hans'
uci set system.@system[0].hostname='H29K'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set wireless.default_radio0.disabled='0'
uci commit
exit 0
EOF

# --- 8. 暴力锁定与配置刷新 ---
make defconfig
# 抹除所有 h28k 的痕迹，确保文件名正确
sed -i 's/hinlink_h28k/hinlink_h29k/g' .config
sed -i 's/h28k/h29k/g' .config

# 再次清理可能被 defconfig 重新勾选的冲突包
sed -i '/CONFIG_PACKAGE_wpad-basic/d' .config
sed -i '/CONFIG_PACKAGE_dnsmasq=/d' .config
sed -i '/CONFIG_PACKAGE_modemmanager/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-qmodem=/d' .config
{
    echo "# CONFIG_PACKAGE_wpad-basic is not set"
    echo "# CONFIG_PACKAGE_dnsmasq is not set"
    echo "# CONFIG_PACKAGE_modemmanager is not set"
    echo "CONFIG_PACKAGE_wpad-openssl=y"
    echo "CONFIG_PACKAGE_dnsmasq-full=y"
} >> .config

# 锁定单机型编译，杀掉 armsom_sige7 等
sed -i 's/CONFIG_TARGET_rockchip_armv8_DEVICE_.*=y/# & is not set/' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

# 分区校准
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

make defconfig
