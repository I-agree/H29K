#!/bin/bash

# --- 1. 环境与设备树修复 ---
# 修正：更新下载地址，避免 404 错误
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.txt"

TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_PATH"

# 使用静默模式下载并检查是否成功
curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts" || echo "DTS Download Failed"
curl -fsSL "$BOOT_URL" > H29K-Boot-Loader.txt || echo "Bootloader Info Download Failed"

if [ -n "$TARGET_MK" ] && [ -f H29K-Boot-Loader.txt ]; then
    if ! grep -q "hinlink_h29k" "$TARGET_MK"; then
        cat H29K-Boot-Loader.txt >> "$TARGET_MK"
        cat >> "$TARGET_MK" <<EOF
define Device/hinlink_h29k
  DEVICE_VENDOR := Hinlink
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  KERNEL_LOADADDR := 0x02000000
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-r8169
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# --- 2. 内核配置注入 (针对 6.12 内核优化) ---
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    cat >> "$KERNEL_CONF" <<EOF
# 性能：BBR
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"

# 屏幕与硬件总线 (PCIe/SDIO/SPI)
CONFIG_FB=y
CONFIG_FB_SYS_FOPS=y
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m
CONFIG_WWAN=y
CONFIG_MTK_T7XX=m
CONFIG_PCI_ROCKCHIP=y
CONFIG_WLAN=y
CONFIG_CFG80211_WEXT=y
CONFIG_MMC_SDHCI_ROCKCHIP=y
CONFIG_AIC8800_WLAN=m
CONFIG_R8169=y

# 针对 5G 模块 MHI 支持 (解决图片中的依赖警告)
CONFIG_MHI_BUS=y
CONFIG_MHI_WWAN_CTRL=m
CONFIG_MHI_WWAN_NET=m
EOF
fi

# --- 3. 软件包锁定与全简体中文 ---
# 彻底清理无效依赖，防止编译中断
sed -i '/quectel/d' .config
sed -i '/qmodem/d' .config
sed -i '/kmod-r8125/d' .config
sed -i '/kmod-mhi-wwan/d' .config

cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y

# 简体中文全家桶
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=y
CONFIG_PACKAGE_luci-i18n-autocore-zh-cn=y
CONFIG_PACKAGE_luci-i18n-irqbalance-zh-cn=y
CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=y
CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y

# 核心驱动与优化
CONFIG_PACKAGE_kmod-r8169=y
CONFIG_PACKAGE_kmod-mtk_t7xx=y
CONFIG_PACKAGE_kmod-aic8800=y
CONFIG_PACKAGE_aic8800-firmware=y
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_luci-app-irqbalance=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
EOF

# --- 4. 强制中文首选项与主机名 ---
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate

# 强制注入中文配置文件
mkdir -p files/etc/config
cat > files/etc/config/luci <<EOF
config core 'main'
    option lang 'zh_cn'
    option mediaurlbase '/luci-static/argon'
EOF

make defconfig
