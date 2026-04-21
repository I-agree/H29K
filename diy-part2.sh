#!/bin/bash
#
# File name: diy-part2.sh
# Description: H29K 最终完美版 (全中文/全驱动/性能优化/报错修复)
#

# --- 1. 基础环境与设备树 (修正 mkits 报错) ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_PATH"
curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts > "$DTS_PATH/rk3528-opc-h29k.dts"

if [ -n "$TARGET_MK" ]; then
    curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.txt > H29K-Boot-Loader.txt
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

# --- 2. 内核配置注入 (BBR + 硬件总线) ---
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    cat >> "$KERNEL_CONF" <<EOF
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
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
EOF
fi

# --- 3. 软件包锁定与全中文国际化 ---
# 清理之前残留的报错项
sed -i '/quectel/d' .config
sed -i '/qmodem/d' .config
sed -i '/kmod-r8125/d' .config

cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y

# --- 核心驱动 ---
CONFIG_PACKAGE_kmod-r8169=y
CONFIG_PACKAGE_kmod-mtk_t7xx=y
CONFIG_PACKAGE_kmod-wwan=y
CONFIG_PACKAGE_wwan=y
CONFIG_PACKAGE_kmod-aic8800=y
CONFIG_PACKAGE_aic8800-firmware=y
CONFIG_PACKAGE_kmod-fb-tft-st7789v=y

# --- 优化插件 ---
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_luci-app-irqbalance=y

# --- 界面主题 ---
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y

# --- 全简体中文支持 (覆盖所有基础与插件) ---
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=y
CONFIG_PACKAGE_luci-i18n-autocore-zh-cn=y
CONFIG_PACKAGE_luci-i18n-irqbalance-zh-cn=y
CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=y
CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y

# 其他工具
CONFIG_PACKAGE_minicom=y
CONFIG_PACKAGE_iw=y
EOF

# --- 4. 强制中文首选项设置 ---
# 1. 修正默认主机名
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# 2. 强制默认语言为 zh_hans
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate

# 3. 注入系统初始化脚本，强制锁定语言为简体中文 (针对 luci)
mkdir -p files/etc/config
cat > files/etc/config/luci <<EOF
config core 'main'
    option lang 'zh_cn'
    option resourcebase '/luci-static/resources'
    option mediaurlbase '/luci-static/argon'
EOF

# 运行依赖刷新
make defconfig
