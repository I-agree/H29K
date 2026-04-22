#!/bin/bash

# --- 1. 环境与底层基础修复 ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 2. 硬件支持文件下载与强制断言 ---
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_BIN_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"

mkdir -p "$DTS_PATH"
echo "正在下载 H29K 硬件支持文件..."
curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts" || { echo "DTS下载失败"; exit 1; }
curl -fsSL "$BOOT_BIN_URL" > hinlink_h29k-u-boot-rockchip.bin || { echo "Boot下载失败"; exit 1; }

mkdir -p bin/targets/rockchip/armv8
cp hinlink_h29k-u-boot-rockchip.bin bin/targets/rockchip/armv8/

# --- 3. 动态注入 video.mk (静态编译驱动定义) ---
VIDEO_MK="package/kernel/linux/modules/video.mk"
sed -i '/KernelPackage\/h29k-fb-st7789v/,/eval $(call KernelPackage,h29k-fb-st7789v)/d' "$VIDEO_MK"

echo "正在注入 ST7789V 静态驱动定义..."
cat >> "$VIDEO_MK" <<EOF

define KernelPackage/h29k-fb-st7789v
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=ST7789V LCD display support (Built-in)
  DEPENDS:=+kmod-fb +kmod-fb-cfb-fillrect +kmod-fb-cfb-copyarea +kmod-fb-cfb-imgblt
  KCONFIG:=CONFIG_FB_TFT=y CONFIG_FB_TFT_ST7789V=y
  FILES:=
  AUTOLOAD:=
endef
\$(eval \$(call KernelPackage,h29k-fb-st7789v))
EOF

# --- 4. 自动修补所有内核配置 (全静态驱动 & BBR) ---
find target/linux/rockchip/armv8/ -name "config-*" | while read CONF; do
    sed -i '/CONFIG_STAGING/d' "$CONF"
    sed -i '/CONFIG_FB_TFT/d' "$CONF"
    sed -i '/CONFIG_TCP_CONG/d' "$CONF"
    sed -i '/CONFIG_DEFAULT_TCP_CONG/d' "$CONF"
    {
        echo "CONFIG_STAGING=y"
        echo "CONFIG_FB=y"
        echo "CONFIG_FB_CFB_FILLRECT=y"
        echo "CONFIG_FB_CFB_COPYAREA=y"
        echo "CONFIG_FB_CFB_IMAGEBLIT=y"
        echo "CONFIG_FB_DEFERRED_IO=y"
        echo "CONFIG_FB_SYS_FOPS=y"
        echo "CONFIG_SPI=y"
        echo "CONFIG_FB_TFT=y"
        echo "CONFIG_FB_TFT_ST7789V=y"
        echo "CONFIG_MTK_T7XX=m"
        echo "CONFIG_USB_RTL8152=m"
        echo "CONFIG_R8169=m"
        echo "CONFIG_MMC_SDHCI_PLTFM=y"
        echo "CONFIG_TCP_CONG_ADVANCED=y"
        echo "CONFIG_TCP_CONG_BBR=y"
        echo "CONFIG_DEFAULT_BBR=y"
        echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\""
    } >> "$CONF"
done

# --- 5. 注册设备并完善 DEVICE_PACKAGES (明确屏蔽 ModemManager) ---
TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
if [ -n "$TARGET_MK" ] && ! grep -q "hinlink_h29k" "$TARGET_MK"; then
    echo "正在注册 H29K 并屏蔽冲突包..."
    cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  DEVICE_DTS_DIR := \$(LINUX_DIR)/arch/arm64/boot/dts/rockchip
  UBOOT_DEVICE_NAME := hinlink_h29k
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | rockchip-img | gzip | append-metadata
  KERNEL_SIZE := 33554432
  KERNEL_LOADADDR := 0x00200000
  BOARD_ROOTFS_PARTSIZE := 1024
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-usb-net-rtl8152 kmod-r8169 \\
	kmod-aic8800-sdio wpad-openssl -wpad-basic -wpad-mini -urngd \\
	dnsmasq-full -dnsmasq \\
	kmod-mtk_t7xx kmod-usb-net-qmi-wwan uqmi kmod-usb-serial-option kmod-usb-serial-qualcomm \\
	kmod-fb kmod-fb-cfb-fillrect kmod-fb-cfb-copyarea kmod-fb-cfb-imgblt \\
	kmod-h29k-fb-st7789v \\
	irqbalance luci-app-irqbalance luci-i18n-irqbalance-zh-cn \\
	luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn -luci-app-qmodem \\
	-modemmanager -libmbim -libqmi \\
	luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# --- 6. 全局 .config 强制设置 ---
cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_kmod-aic8800-sdio=y
CONFIG_PACKAGE_kmod-h29k-fb-st7789v=y
CONFIG_PACKAGE_luci-app-qmodem-next=y
CONFIG_PACKAGE_luci-i18n-qmodem-next-zh-cn=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-theme-argon=y
EOF

# --- 7. 系统默认值初始化 (含启动项静默处理) ---
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k-custom <<EOF
#!/sh
# 强制停止并禁用可能残留的 modemmanager 服务（双重保险）
/etc/init.d/modemmanager stop 2>/dev/null
/etc/init.d/modemmanager disable 2>/dev/null

uci set luci.main.mediaurlbase='/luci-static/argon'
uci set luci.main.lang='zh_hans'
uci set system.@system[0].hostname='H29K'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set wireless.default_radio0.ssid='H29K'
uci set wireless.radio0.country='CN'
uci set wireless.radio0.disabled='0'
uci commit luci
uci commit system
uci commit wireless
exit 0
EOF

# --- 8. 执行生成配置与最终清理 (彻底斩断 ModemManager) ---
make defconfig

# 1. 清理 wpad/dnsmasq 冲突
sed -i '/CONFIG_PACKAGE_wpad-basic/d' .config
sed -i '/CONFIG_PACKAGE_wpad-mini/d' .config
sed -i '/CONFIG_PACKAGE_dnsmasq/d' .config
echo "# CONFIG_PACKAGE_wpad-basic is not set" >> .config
echo "# CONFIG_PACKAGE_dnsmasq is not set" >> .config

# 2. 强力屏蔽 ModemManager 及其底层依赖
sed -i '/CONFIG_PACKAGE_modemmanager/d' .config
sed -i '/CONFIG_PACKAGE_libmbim/d' .config
sed -i '/CONFIG_PACKAGE_libqmi/d' .config
echo "# CONFIG_PACKAGE_modemmanager is not set" >> .config
echo "# CONFIG_PACKAGE_libmbim is not set" >> .config
echo "# CONFIG_PACKAGE_libqmi is not set" >> .config

# 3. 清理 Qmodem 旧版
sed -i '/CONFIG_PACKAGE_luci-app-qmodem=/d' .config
echo "# CONFIG_PACKAGE_luci-app-qmodem is not set" >> .config

# 4. 修复分区与机型锁定
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

sed -i 's/CONFIG_TARGET_rockchip_armv8_DEVICE_.*=y/# & is not set/' .config
H29K_CONF=$(grep -i "CONFIG_TARGET_rockchip_armv8_DEVICE_.*H29K.*" .config | head -n 1 | cut -d'=' -f1)
if [ -n "$H29K_CONF" ]; then
    sed -i "s/.*$H29K_CONF.*/$H29K_CONF=y/" .config
else
    echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config
fi

make defconfig
