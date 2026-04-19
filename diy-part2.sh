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

# 1. 创建目标目录（如果不存在）
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/

# 2. 下载 H29K 的设备树文件 (DTS)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
curl -fsSL https://raw.githubusercontent.com/aaaol/OpenWrt/master/Files/LEDE/HinLink_H29K/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts > target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts

# 3. 在 Makefile 中注册 H29K 设备
# 定义文件路径
armv8_MK="target/linux/rockchip/image/armv8.mk"

# 检查文件是否存在，防止路径变更导致报错
if [ -f "$armv8_MK" ]; then
    echo "正在向 $armv8_MK 注册 H29K 设备..."
    cat >> "$armv8_MK" <<EOF

define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_ALT0_VENDOR := LinkStar
  DEVICE_ALT0_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-drm-rockchip kmod-console-font
endef
TARGET_DEVICES += hinlink_h29k

else
    echo "错误: 找不到 $armv8_MK，请确认官方源码的 RK3528 路径是否正确。"
fi

# 定位 Rockchip 默认内核配置文件
KERNEL_CONF="target/linux/rockchip/config-default"

if [ -f "$KERNEL_CONF" ]; then
    echo "正在开启内核 Framebuffer 驱动支持..."
    
    # 开启 DRM/Framebuffer 核心支持
    echo "CONFIG_FB=y" >> "$KERNEL_CONF"
    echo "CONFIG_DRM=y" >> "$KERNEL_CONF"
    echo "CONFIG_DRM_ROCKCHIP=y" >> "$KERNEL_CONF"
    
    # 开启 Framebuffer 终端仿真（让屏幕能显示终端字符）
    echo "CONFIG_DRM_FBDEV_EMULATION=y" >> "$KERNEL_CONF"
    echo "CONFIG_FRAMEBUFFER_CONSOLE=y" >> "$KERNEL_CONF"
    echo "CONFIG_LOGO=y" >> "$KERNEL_CONF" # 可选：开启启动 Logo 支持
    
    # 针对 RK3528 的特定 VOP2 显示控制器支持
    echo "CONFIG_ROCKCHIP_VOP2=y" >> "$KERNEL_CONF"
else
    echo "警告：未找到内核配置文件 $KERNEL_CONF"
fi

# 开启 MHI 总线支持，这是很多 5G 模块（如移远 RM500Q）的依赖
echo "CONFIG_MHI_BUS=y" >> target/linux/rockchip/config-default
echo "CONFIG_MHI_BUS_PCI_GENERIC=y" >> target/linux/rockchip/config-default
