#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# --- 第一部分：基础环境补丁 ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 第二部分：源码注入 (设备支持与 5G 模块) ---

# 1. H29K 设备树与引导逻辑
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

# 2. 注入 quectel-CM-5G 源码 (解决依赖包不存在问题)
mkdir -p package/custom
git clone --depth 1 https://github.com/I-agree/quectel_cm_5G.git package/custom/quectel-CM-5G

# --- 第三部分：内核配置与优化 (核心修复) ---

KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    # 开启屏幕支持与 BBR
    cat >> "$KERNEL_CONF" <<EOF
# 基础 TCP 优化
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"

# 修复屏幕驱动 ST7789V 缺失依赖 (fb_sys_fops 等)
CONFIG_FB=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_IMAGEBLT=y
CONFIG_FB_SYS_FOPS=y
CONFIG_FB_DEFERRED_IO=y
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m

# 5G/MHI 驱动基础内核支持
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_WWAN=y
CONFIG_MHI_WWAN_CTRL=m
CONFIG_MHI_WWAN_MBIM=m

# 其他图形支持
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_DW_HDMI=y
EOF
fi

# --- 第四部分：个性化设置 ---

# 设置默认中文和主机名
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# --- 第五部分：.config 锁定与依赖补全 ---

# 强制注入目标设备配置
cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y

# 选中 5G 驱动包
CONFIG_PACKAGE_quectel-CM-5G=y
CONFIG_PACKAGE_kmod-mhi-wwan=y

# 选中屏幕驱动包
CONFIG_PACKAGE_kmod-fb-tft-st7789v=y
EOF

# 运行 defconfig 刷新依赖关系
make defconfig

# 验证注入结果
if ! grep -q "DEVICE_hinlink_h29k=y" .config; then
    echo "警告：H29K 设备注入可能不完全，请检查 .config！"
fi
