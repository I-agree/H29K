#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# --- 第一部分：环境补丁与内核模块定义 ---
# 解决宿主机脚本依赖
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# 【核心修复】在官方源码中手动定义缺失的 kmod-fb-tft-st7789v 软件包实体
VIDEO_MK="package/kernel/linux/modules/video.mk"
if [ -f "$VIDEO_MK" ] && ! grep -q "fb-tft-st7789v" "$VIDEO_MK"; then
    echo "正在定义 kmod-fb-tft-st7789v 软件包实体..."
    cat >> "$VIDEO_MK" <<EOF

define KernelPackage/fb-tft-st7789v
  SUBMENU:=Video Support
  TITLE:=ST7789V LCD FB driver
  KCONFIG:=CONFIG_FB_TFT CONFIG_FB_TFT_ST7789V
  FILES:=\$(LINUX_DIR)/drivers/staging/fbtft/fb_st7789v.ko \\
         \$(LINUX_DIR)/drivers/staging/fbtft/fbtft.ko
  AUTOLOAD:=\$(confvar,CONFIG_FB_TFT_ST7789V)
  DEPENDS:=+kmod-fb
endef

\$(eval \$(call KernelPackage,fb-tft-st7789v))
EOF
fi

# --- 第二部分：源码注入 (适配官方 OpenWrt 标准) ---

TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_PATH"
curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts > "$DTS_PATH/rk3528-opc-h29k.dts"

if [ -n "$TARGET_MK" ]; then
    # 准备 Loader
    curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin > dl/hinlink_h29k-u-boot-rockchip.bin
    
    # 注入 Loader 编译逻辑
    if ! grep -q "hinlink_h29k-u-boot-rockchip.bin" "$TARGET_MK"; then
        echo '
$(STAGING_DIR_IMAGE)/hinlink_h29k-u-boot-rockchip.bin: dl/hinlink_h29k-u-boot-rockchip.bin
	mkdir -p $(dir $@)
	cp $< $@
' >> "$TARGET_MK"
    fi

    # 注入设备定义 (使用官方标准的 boot-common | pine64-img 打包函数)
    if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
        echo "正在向官方 armv8.mk 注入 H29K 定义..."
        cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  # 关键修复：官方构建流水线，解决 Missing Build/rockchip-combined 报错
  IMAGES := sysupgrade.img.gz
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | pine64-img | gzip | append-metadata
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-fb-tft-st7789v \\
    kmod-aic8800-sdio wpad-openssl -wpad-basic-mbedtls -wpad-basic -urngd \\
    kmod-usb3 kmod-usb-dwc3-rockchip kmod-usb-net-rtl8152 \\
    luci-i18n-base-zh-cn luci-theme-argon luci-app-argon-config luci-app-turboacc
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# --- 第三部分：内核强制配置 (Staging + BBR + SPI) ---

KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    echo "正在强化内核配置以支持屏幕与网络性能..."
    cat >> "$KERNEL_CONF" <<EOF
CONFIG_STAGING=y
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m
CONFIG_SPI=y
CONFIG_SPI_MASTER=y
CONFIG_SPI_ROCKCHIP=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_DW_HDMI=y
EOF
fi

# 系统基本设置 (语言、主机名)
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# --- 第四部分：智能锁定与配置生成 ---

# 预写设备选择，引导 defconfig
echo "CONFIG_TARGET_rockchip=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

make defconfig

# 智能检查设备锁定情况
if ! grep -q "DEVICE_hinlink_h29k=y" .config; then
    echo "错误：未能成功锁定 H29K 设备，请检查注入逻辑！"
    exit 1
fi

# 语言包自动补齐
if [ -f .config ]; then
    echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config
    grep "=y" .config | grep "CONFIG_PACKAGE_luci-app-" | sed 's/CONFIG_PACKAGE_luci-app-//g;s/=y//g' | while read -r app; do
        echo "CONFIG_PACKAGE_luci-i18n-$app-zh-cn=y" >> .config
    done
fi

# 分区锁定
sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/g' .config
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/g' .config

# 剔除其他设备干扰
sed -i 's/CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_.*=y/# & is not set/g' .config
echo "CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config
sed -i 's/CONFIG_TARGET_ARCH_PACKAGES=.*/CONFIG_TARGET_ARCH_PACKAGES="aarch64_generic"/g' .config
