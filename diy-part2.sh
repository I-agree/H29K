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
# 1. 解决宿主机脚本依赖
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# 2. 【核心修复】重新定义 kmod-fb-tft-st7789v，解决内核符号缺失报错
# 增加了对 fb_sys_fops, syscopyarea 等符号所属包的依赖
VIDEO_MK="package/kernel/linux/modules/video.mk"
if [ -f "$VIDEO_MK" ] && ! grep -q "fb-tft-st7789v" "$VIDEO_MK"; then
    echo "正在定义 kmod-fb-tft-st7789v 并补齐符号依赖..."
    cat >> "$VIDEO_MK" <<EOF

define KernelPackage/fb-tft-st7789v
  SUBMENU:=Video Support
  TITLE:=ST7789V LCD FB driver
  KCONFIG:=CONFIG_FB_TFT CONFIG_FB_TFT_ST7789V
  FILES:=\$(LINUX_DIR)/drivers/staging/fbtft/fb_st7789v.ko \\
         \$(LINUX_DIR)/drivers/staging/fbtft/fbtft.ko
  AUTOLOAD:=\$(confvar,CONFIG_FB_TFT_ST7789V)
  DEPENDS:=+kmod-fb +kmod-fb-cfb-fillrect +kmod-fb-cfb-copyarea +kmod-fb-cfb-imgblt
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
    # 3. 准备 Loader 文件 (修正下载顺序与路径)
    LOADER_FILE="hinlink_h29k-u-boot-rockchip.bin"
    LOADER_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
    
    # 确保 dl 目录存在
    mkdir -p dl
    echo "正在下载 Loader 文件..."
    curl -fsSL "$LOADER_URL" -o "dl/$LOADER_FILE"
    
    # 确保同步到 staging 目录，解决打包时 No such file 的问题
    STAGING_IMAGE_DIR="staging_dir/target-aarch64_generic_musl/image"
    mkdir -p "$STAGING_IMAGE_DIR"
    if [ -f "dl/$LOADER_FILE" ]; then
        cp "dl/$LOADER_FILE" "$STAGING_IMAGE_DIR/$LOADER_FILE"
        echo "成功同步 Loader 至 $STAGING_IMAGE_DIR"
    else
        echo "错误：Loader 下载失败！"
    fi

    # 4. 注入设备定义 (使用官方 boot-common 流水线)
    if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
        echo "正在注入 H29K 设备定义..."
        cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  IMAGES := sysupgrade.img.gz
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | pine64-img | gzip | append-metadata
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-fb-tft-st7789v \\
    kmod-fb-cfb-fillrect kmod-fb-cfb-copyarea kmod-fb-cfb-imgblt \\
    kmod-aic8800-sdio wpad-openssl -wpad-basic-mbedtls -wpad-basic -urngd \\
    kmod-usb3 kmod-usb-dwc3-rockchip kmod-usb-net-rtl8152 \\
    luci-i18n-base-zh-cn luci-theme-argon luci-app-argon-config luci-app-turboacc
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# --- 第三部分：内核强制配置 ---

KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    cat >> "$KERNEL_CONF" <<EOF
CONFIG_STAGING=y
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
EOF
fi

# 修正主机名与默认语言
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# --- 第四部分：配置生成与锁定 ---

# 引导配置到 .config
echo "CONFIG_TARGET_rockchip=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

make defconfig

# 强制分区大小锁定
sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/g' .config
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/g' .config

# 禁用其他设备干扰
sed -i 's/CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_.*=y/# & is not set/g' .config
echo "CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config
