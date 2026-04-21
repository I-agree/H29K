#!/bin/bash

# --- 1. 环境与设备树 ---
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
  # 修正：移除可能不存在的 kmod-r8125，改用内核更通用的 r8169 或让系统自动选择
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-r8169
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# --- 2. 内核配置注入 (补齐有线网卡驱动 + 其他修复) ---
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    cat >> "$KERNEL_CONF" <<EOF
# 基础 TCP 优化
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"

# 修复屏幕驱动 ST7789V 缺失依赖
CONFIG_FB=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_IMAGEBLT=y
CONFIG_FB_SYS_FOPS=y
CONFIG_FB_DEFERRED_IO=y
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m

# 5G 模块 FM350-GL
CONFIG_WWAN=y
CONFIG_MTK_T7XX=m
CONFIG_PCI=y
CONFIG_PCI_MSI=y
CONFIG_PCI_ROCKCHIP=y

# 板载 Wi-Fi aic8800
CONFIG_WLAN=y
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_CFG80211_WEXT=y
CONFIG_MMC=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_PLTFM=y
CONFIG_MMC_SDHCI_ROCKCHIP=y
CONFIG_AIC8800_WLAN=m

# --- 核心修正：确保有线网卡驱动在内核中开启 ---
CONFIG_R8169=y
EOF
fi

# --- 3. 清理冗余并锁定软件包 ---
sed -i '/quectel-CM-5G/d' .config
sed -i '/quectel-cm/d' .config
sed -i '/qmodem/d' .config
sed -i '/kmod-r8125/d' .config  # 物理删除配置中的 r8125 以防报错

cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y

# 选中驱动
CONFIG_PACKAGE_kmod-r8169=y
CONFIG_PACKAGE_kmod-mtk_t7xx=y
CONFIG_PACKAGE_kmod-wwan=y
CONFIG_PACKAGE_wwan=y
CONFIG_PACKAGE_kmod-aic8800=y
CONFIG_PACKAGE_aic8800-firmware=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_kmod-fb-tft-st7789v=y

# 界面主题与工具
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_minicom=y
CONFIG_PACKAGE_iw=y
EOF

# --- 4. 个性化设置 ---
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

make defconfig
