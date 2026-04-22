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

curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts"
if [ $? -ne 0 ] || [ ! -s "$DTS_PATH/rk3528-opc-h29k.dts" ]; then
    echo "FATAL ERROR: rk3528-opc-h29k.dts 下载失败，编译终止！"
    exit 1
fi

curl -fsSL "$BOOT_BIN_URL" > hinlink_h29k-u-boot-rockchip.bin
if [ $? -ne 0 ] || [ ! -s "hinlink_h29k-u-boot-rockchip.bin" ]; then
    echo "FATAL ERROR: H29K-Boot-Loader.bin 下载失败，编译终止！"
    exit 1
fi

mkdir -p bin/targets/rockchip/armv8
cp hinlink_h29k-u-boot-rockchip.bin bin/targets/rockchip/armv8/
echo "硬件支持文件准备就绪。"

# --- 3. 动态注入 video.mk (适配 6.12 内核路径并移除非法字符) ---
VIDEO_MK="package/kernel/linux/modules/video.mk"

# 清理旧的错误定义
sed -i '/KernelPackage\/h29k-fb-tft-core/,/eval $(call KernelPackage,h29k-fb-tft-core)/d' "$VIDEO_MK"
sed -i '/KernelPackage\/h29k-fb-st7789v/,/eval $(call KernelPackage,h29k-fb-st7789v)/d' "$VIDEO_MK"

echo "正在注入修复后的屏幕驱动定义到 $VIDEO_MK..."
cat >> "$VIDEO_MK" <<EOF

define KernelPackage/h29k-fb-tft-core
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=Support for small TFT LCD display modules (H29K)
  KCONFIG:=CONFIG_FB_TFT
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/fbtft/fbtft.ko
  AUTOLOAD:=\$(call AutoProbe,fbtft)
endef
\$(eval \$(call KernelPackage,h29k-fb-tft-core))

define KernelPackage/h29k-fb-st7789v
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=ST7789V LCD display support (H29K)
  DEPENDS:=+kmod-h29k-fb-tft-core
  KCONFIG:=CONFIG_FB_TFT_ST7789V
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/fbtft/fb_st7789v.ko
  AUTOLOAD:=\$(call AutoProbe,fb_st7789v)
endef
\$(eval \$(call KernelPackage,h29k-fb-st7789v))
EOF

# --- 4. 强制开启内核 TFT 帧缓冲支持 (核心修复项) ---
# 针对 Rockchip 平台的 6.12 配置文件进行物理注入
KCONFIG_612="target/linux/rockchip/armv8/config-6.12"
if [ -f "$KCONFIG_612" ]; then
    echo "正在强制开启内核 TFT 帧缓冲配置..."
    # 确保基础 FB 支持开启 (y 表示内置，m 表示模块)
    sed -i '/CONFIG_FB/d' "$KCONFIG_612"
    echo "CONFIG_FB=y" >> "$KCONFIG_612"
    echo "CONFIG_FB_CFB_FILLRECT=y" >> "$KCONFIG_612"
    echo "CONFIG_FB_CFB_COPYAREA=y" >> "$KCONFIG_612"
    echo "CONFIG_FB_CFB_IMAGEBLIT=y" >> "$KCONFIG_612"
    # 开启 TFT 核心支持
    echo "CONFIG_FB_TFT=m" >> "$KCONFIG_612"
    echo "CONFIG_FB_TFT_FBTFT_DEVICE=m" >> "$KCONFIG_612"
    echo "CONFIG_FB_TFT_ST7789V=m" >> "$KCONFIG_612"
fi

# --- 5. 注册设备到 Makefile (维持 0x00200000 内存地址) ---
TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
if [ -n "$TARGET_MK" ] && ! grep -q "hinlink_h29k" "$TARGET_MK"; then
    echo "正在注册 H29K 设备到 $TARGET_MK..."
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
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-r8169 kmod-usb-net-rtl8152 kmod-aic8800 aic8800-firmware kmod-mtk_t7xx kmod-h29k-fb-st7789v
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# --- 6. 核心配置注入 (BBR + WLAN 底层) ---
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    cat >> "$KERNEL_CONF" <<EOF
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_WLAN=y
CONFIG_CFG80211=y
CONFIG_CFG80211_WEXT=y
EOF
fi

# --- 7. 软件包注入与 Argon 主题锁定 ---
cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
CONFIG_PACKAGE_kmod-aic8800=y
CONFIG_PACKAGE_aic8800-firmware=y
CONFIG_PACKAGE_kmod-mtk_t7xx=y
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_luci-app-irqbalance=y
CONFIG_PACKAGE_luci-i18n-irqbalance-zh-cn=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
EOF

# --- 8. 系统默认值初始化 ---
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k-custom <<EOF
#!/bin/sh
uci set luci.main.mediaurlbase='/luci-static/argon'
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

# --- 9. 最终配置生成与分区清理 ---
make defconfig

sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 确保单选 H29K 机型
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_/d' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

make defconfig
