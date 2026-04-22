#!/bin/bash

# --- 1. 环境与底层基础修复 ---
# 解决某些脚本依赖 /lib/functions.sh 的路径兼容性问题
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 2. 硬件支持文件下载与强制断言 ---
# 下载 H29K 专属 DTS 和引导程序，下载失败则立即终止编译，防止产生坏件
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_BIN_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"

mkdir -p "$DTS_PATH"
echo "正在下载 H29K 硬件支持文件..."
curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts" || { echo "DTS下载失败"; exit 1; }
curl -fsSL "$BOOT_BIN_URL" > hinlink_h29k-u-boot-rockchip.bin || { echo "Boot下载失败"; exit 1; }

# 将引导程序放入预设目录，供固件打包工具调用
mkdir -p bin/targets/rockchip/armv8
cp hinlink_h29k-u-boot-rockchip.bin bin/targets/rockchip/armv8/

# --- 3. 动态注入 video.mk (适配所有内核版本的 TFT 驱动路径) ---
VIDEO_MK="package/kernel/linux/modules/video.mk"
sed -i '/KernelPackage\/h29k-fb-tft-core/,/eval $(call KernelPackage,h29k-fb-tft-core)/d' "$VIDEO_MK"
sed -i '/KernelPackage\/h29k-fb-st7789v/,/eval $(call KernelPackage,h29k-fb-st7789v)/d' "$VIDEO_MK"

echo "正在注入屏幕驱动定义到 $VIDEO_MK..."
cat >> "$VIDEO_MK" <<EOF

define KernelPackage/h29k-fb-tft-core
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=Support for small TFT LCD display modules (H29K)
  KCONFIG:=CONFIG_FB_TFT
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/*/fbtft.ko \$(LINUX_DIR)/drivers/staging/fbtft/fbtft.ko
  AUTOLOAD:=\$(call AutoProbe,fbtft)
endef
\$(eval \$(call KernelPackage,h29k-fb-tft-core))

define KernelPackage/h29k-fb-st7789v
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=ST7789V LCD display support (H29K)
  DEPENDS:=+kmod-h29k-fb-tft-core +kmod-fb +kmod-fb-cfb-fillrect +kmod-fb-cfb-copyarea +kmod-fb-cfb-imgblt
  KCONFIG:=CONFIG_FB_TFT_ST7789V
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/*/fb_st7789v.ko \$(LINUX_DIR)/drivers/staging/fbtft/fb_st7789v.ko
  AUTOLOAD:=\$(call AutoProbe,fb_st7789v)
endef
\$(eval \$(call KernelPackage,h29k-fb-st7789v))
EOF

# --- 4. 自动修补所有内核配置 (全硬件支持、BBR 及拨号协议) ---
echo "正在修补所有内核版本的 config 配置 (TFT/BBR/SPI/5G/QMI)..."
find target/linux/rockchip/armv8/ -name "config-*" | while read CONF; do
    sed -i '/CONFIG_STAGING/d' "$CONF"
    sed -i '/CONFIG_FB_TFT/d' "$CONF"
    sed -i '/CONFIG_TCP_CONG/d' "$CONF"
    sed -i '/CONFIG_DEFAULT_TCP_CONG/d' "$CONF"
    sed -i '/CONFIG_USB_NET_QMI_WWAN/d' "$CONF"
    {
        echo "CONFIG_STAGING=y"
        echo "CONFIG_FB=y"
        echo "CONFIG_FB_CFB_FILLRECT=y"
        echo "CONFIG_FB_CFB_COPYAREA=y"
        echo "CONFIG_FB_CFB_IMAGEBLIT=y"
        echo "CONFIG_FB_DEFERRED_IO=y"
        echo "CONFIG_FB_SYS_FOPS=y"
        echo "CONFIG_FB_BACKLIGHT=y"
        echo "CONFIG_SPI=y"
        echo "CONFIG_FB_TFT=m"
        echo "CONFIG_FB_TFT_ST7789V=m"
        echo "CONFIG_FB_TFT_FBTFT_DEVICE=m"
        echo "CONFIG_MTK_T7XX=m"
        echo "CONFIG_USB_NET_QMI_WWAN=m"
        echo "CONFIG_USB_SERIAL_QUALCOMM=m"
        echo "CONFIG_USB_SERIAL_OPTION=m"
        echo "CONFIG_USB_RTL8152=m"
        echo "CONFIG_R8169=m"
        echo "CONFIG_TCP_CONG_ADVANCED=y"
        echo "CONFIG_TCP_CONG_BBR=y"
        echo "CONFIG_DEFAULT_BBR=y"
        echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\""
    } >> "$CONF"
done

# --- 5. 注册设备并完善 DEVICE_PACKAGES (含 qmodem, 5G, 网卡等) ---
TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
if [ -n "$TARGET_MK" ] && ! grep -q "hinlink_h29k" "$TARGET_MK"; then
    echo "正在向 $TARGET_MK 注册 H29K 设备包..."
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
	kmod-aic8800 aic8800-firmware \\
	kmod-mtk_t7xx kmod-usb-net-qmi-wwan uqmi kmod-usb-serial-option kmod-usb-serial-qualcomm \\
	kmod-fb kmod-fb-cfb-fillrect kmod-fb-cfb-copyarea kmod-fb-cfb-imgblt \\
	kmod-h29k-fb-tft-core kmod-h29k-fb-st7789v \\
	irqbalance luci-app-irqbalance luci-i18n-irqbalance-zh-cn \\
	luci-app-qmodem luci-i18n-qmodem-zh-cn \\
	luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# --- 6. 全局 .config 强制设置 ---
cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_PACKAGE_kmod-aic8800=y
CONFIG_PACKAGE_aic8800-firmware=y
CONFIG_PACKAGE_kmod-mtk_t7xx=y
CONFIG_PACKAGE_kmod-h29k-fb-tft-core=y
CONFIG_PACKAGE_kmod-h29k-fb-st7789v=y
CONFIG_PACKAGE_luci-app-qmodem=y
CONFIG_PACKAGE_luci-i18n-qmodem-zh-cn=y
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_luci-app-irqbalance=y
CONFIG_PACKAGE_luci-i18n-irqbalance-zh-cn=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
EOF

# --- 7. 系统默认值初始化 (UCI 方案) ---
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k-custom <<EOF
#!/bin/sh
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

# --- 8. 执行生成配置与最终清理 ---
make defconfig

# 修复 JFFS2 错误
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config

# 调整分区大小
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# --- 核心修改：确保单选含有 H29K 关键字的机型 ---
echo "正在检测并单选 H29K 机型..."
# 1. 先取消所有已选中的 rockchip_armv8 设备
sed -i 's/CONFIG_TARGET_rockchip_armv8_DEVICE_.*=y/# & is not set/' .config

# 2. 查找包含 H29K 关键字的配置项（不区分大小写）
H29K_CONF=$(grep -i "CONFIG_TARGET_rockchip_armv8_DEVICE_.*H29K.*" .config | head -n 1 | cut -d'=' -f1)

if [ -n "$H29K_CONF" ]; then
    echo "匹配到机型项: $H29K_CONF，正在锁定..."
    # 3. 强制开启该项并移除任何之前的“not set”注释
    sed -i "s/.*$H29K_CONF.*/$H29K_CONF=y/" .config
else
    echo "警告: 未在 .config 中找到包含 H29K 的机型项，使用默认强制注入..."
    echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config
fi

# 最后再次刷新以应用所有依赖修改
make defconfig
