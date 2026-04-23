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

# --- 3. 动态注入 video.mk (ST7789V 静态内核包) ---
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

# --- 4. 内核配置硬修改 (针对 FM350-GL USB 优化) ---
find target/linux/rockchip/armv8/ -name "config-*" | while read CONF; do
    sed -i '/CONFIG_STAGING/d' "$CONF"
    sed -i '/CONFIG_FB_TFT/d' "$CONF"
    sed -i '/CONFIG_TCP_CONG/d' "$CONF"
    {
        # 屏幕与 BBR
        echo "CONFIG_STAGING=y"
        echo "CONFIG_FB=y"
        echo "CONFIG_FB_TFT=y"
        echo "CONFIG_FB_TFT_ST7789V=y"
        echo "CONFIG_SPI=y"
        echo "CONFIG_TCP_CONG_BBR=y"
        echo "CONFIG_DEFAULT_BBR=y"
        echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\""
        # 5G USB 模式核心驱动：MBIM 是 FM350 在 USB 下的灵魂
        echo "CONFIG_USB_NET_CDC_MBIM=m"
        echo "CONFIG_USB_NET_CDC_NCM=m"
        echo "CONFIG_USB_NET_RNDIS_HOST=m"
        echo "CONFIG_USB_SERIAL_OPTION=m"
        echo "CONFIG_MTK_T7XX=m"
    } >> "$CONF"
done

# --- 5. 注册 H29K 设备 (继承 H28K 特性并叠加 USB 网络包) ---
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

# --- 6. 注入官方 H28K 种子并克隆 ---
cat > .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k=y
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_h29k=y
# 核心网络功能
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_dnsmasq-full=y
# 强制 USB 拨号组件
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_uqmi=y
# Qmodem-Next
CONFIG_PACKAGE_luci-app-qmodem-next=y
CONFIG_PACKAGE_luci-i18n-qmodem-next-zh-cn=y
CONFIG_PACKAGE_kmod-h29k-fb-st7789v=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

# --- 7. 系统默认值 (静默处理) ---
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

# --- 8. 暴力锁定与配置刷新 (解决冲突 & 锁定文件名) ---
make defconfig

# A. 身份替换：继承 H28K 地基给 H29K
sed -i 's/hinlink_h28k/hinlink_h29k/g' .config
sed -i 's/h28k/h29k/g' .config

# B. 精确打击：屏蔽除 H29K 以外的所有机型，确保文件名产出正确
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k/! s/CONFIG_TARGET_rockchip_armv8_DEVICE_.*=y/# & is not set/' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

# C. 彻底清理冲突包
sed -i '/CONFIG_PACKAGE_wpad-basic/d' .config
sed -i '/CONFIG_PACKAGE_dnsmasq=/d' .config
sed -i '/CONFIG_PACKAGE_modemmanager/d' .config
{
    echo "# CONFIG_PACKAGE_wpad-basic is not set"
    echo "# CONFIG_PACKAGE_dnsmasq is not set"
    echo "# CONFIG_PACKAGE_modemmanager is not set"
    echo "CONFIG_PACKAGE_wpad-openssl=y"
    echo "CONFIG_PACKAGE_dnsmasq-full=y"
} >> .config

# D. 分区调整
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

make defconfig
