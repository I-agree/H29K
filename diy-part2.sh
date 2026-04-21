#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (针对 FM350-GL 与 H29K 优化版)
#

# --- 1. 环境基础补丁 ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 2. H29K 设备树与引导逻辑 ---
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
  DEVICE_PACKAGES := kmod-r8125 kmod-usb3 uboot-rockchip-v8
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# --- 3. 内核配置优化 (核心修复：点亮屏幕 + FM350-GL PCIe 支持) ---
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    cat >> "$KERNEL_CONF" <<EOF
# 基础 TCP 优化
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"

# 修复屏幕驱动 ST7789V 缺失依赖 (解决 fb_sys_fops 等符号缺失)
CONFIG_FB=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_IMAGEBLT=y
CONFIG_FB_SYS_FOPS=y
CONFIG_FB_DEFERRED_IO=y
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m

# Fibocom FM350-GL (MediaTek T700) 原生内核驱动支持
CONFIG_WWAN=y
CONFIG_MTK_T7XX=m
CONFIG_PCI=y
CONFIG_PCI_MSI=y
CONFIG_PCIE_DW=y
CONFIG_PCIE_DW_HOST=y
CONFIG_PCI_ROCKCHIP=y
EOF
fi

# --- 4. 个性化设置 (中文 & 主机名) ---
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# --- 5. .config 锁定与清理 ---

# 移除会导致报错的移远(Quectel)私有软件包设置
sed -i '/quectel-CM-5G/d' .config
sed -i '/quectel-cm/d' .config
sed -i '/qmodem/d' .config

# 强制注入 FM350-GL 所需驱动及您要求的通用 USB 驱动
cat >> .config <<EOF
# 目标设备
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y

# FM350-GL (MediaTek T700) 驱动包
CONFIG_PACKAGE_kmod-mtk_t7xx=y
CONFIG_PACKAGE_kmod-wwan=y
CONFIG_PACKAGE_wwan=y

# 保留您要求的通用 USB 驱动
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-serial-option=y

# 屏幕驱动包
CONFIG_PACKAGE_kmod-fb-tft-st7789v=y

# 常用调试工具
CONFIG_PACKAGE_minicom=y
EOF

# 刷新依赖关系
make defconfig
