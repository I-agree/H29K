#!/bin/bash

# --- 1. 环境与底层修复 ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 2. 硬件支持文件下载与强制校验 ---
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_BIN_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"

mkdir -p "$DTS_PATH"
echo "正在下载 H29K 硬件支持文件..."

# 下载并检查 DTS
curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts"
if [ $? -ne 0 ] || [ ! -s "$DTS_PATH/rk3528-opc-h29k.dts" ]; then
    echo "FATAL ERROR: rk3528-opc-h29k.dts 下载失败，编译终止！"
    exit 1
fi

# 下载并检查 Boot Loader
# 我们直接下载到源码根目录
curl -fsSL "$BOOT_BIN_URL" > hinlink_h29k-u-boot-rockchip.bin
if [ $? -ne 0 ] || [ ! -s "hinlink_h29k-u-boot-rockchip.bin" ]; then
    echo "FATAL ERROR: H29K-Boot-Loader.bin 下载失败，编译终止！"
    exit 1
fi

# 【关键点】为了防止打包脚本找不到文件，我们将其拷贝到 bin 目录备用
mkdir -p bin/targets/rockchip/armv8
cp hinlink_h29k-u-boot-rockchip.bin bin/targets/rockchip/armv8/

echo "硬件支持文件下载成功。"

# --- 3. 动态注入 video.mk (使用你提供的文件结构) ---
VIDEO_MK="package/kernel/linux/modules/video.mk"
if [ -f "$VIDEO_MK" ] && ! grep -q "h29k-fb-st7789v" "$VIDEO_MK"; then
    cat >> "$VIDEO_MK" <<EOF

define KernelPackage/h29k-fb-tft-core
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=Support for small TFT LCD display modules (H29K)
  KCONFIG:=CONFIG_FB_TFT
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/core/fb_tft.ko
  AUTOLOAD:=\$(conf_set_symbols,CONFIG_FB_TFT,fb_tft)
endef
\$(eval \$(call KernelPackage,h29k-fb-tft-core))

define KernelPackage/h29k-fb-st7789v
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=ST7789V LCD display support (H29K)
  DEPENDS:=+kmod-h29k-fb-tft-core
  KCONFIG:=CONFIG_FB_TFT_ST7789V
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/core/fb_st7789v.ko
  AUTOLOAD:=\$(conf_set_symbols,CONFIG_FB_TFT_ST7789V,fb_st7789v)
endef
\$(eval \$(call KernelPackage,h29k-fb-st7789v))
EOF
fi

# --- 4. 注册设备到 Makefile (修正打包指令) ---
TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
if [ -n "$TARGET_MK" ] && ! grep -q "hinlink_h29k" "$TARGET_MK"; then
    cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  # 确保这里调用的是 rockchip-img，它会自动寻找 \$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | rockchip-img | gzip | append-metadata
  KERNEL_SIZE := 33554432
  BOARD_ROOTFS_PARTSIZE := 1024
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-r8169 kmod-usb-net-rtl8152 kmod-aic8800 aic8800-firmware kmod-mtk_t7xx kmod-h29k-fb-st7789v
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# --- 5. 核心内核配置 ---
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

# --- 6. 软件包注入与默认主题 ---
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

# --- 7. 系统初始化设置 (uci-defaults) ---
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

# --- 8. 生成配置 ---
make defconfig

# --- 9. 修复 BUG 与 最终过滤 ---
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config
sed -i '/kmod-mhi-wwan/d' .config
sed -i '/quectel/d' .config
sed -i '/qmodem/d' .config

# 强制单选机型
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_/d' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

make defconfig
