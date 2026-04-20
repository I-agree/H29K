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

# 1. 准备 DTS 目录
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_PATH"
curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts > "$DTS_PATH/rk3528-opc-h29k.dts"

# 2. 在 Makefile 中注册设备 (强制跳过 U-Boot 拼接逻辑)
TARGET_MK=$(find target/linux/rockchip/image -name "*.mk" | xargs grep -l "Device/rk3528" | head -n 1)

if [ -n "$TARGET_MK" ]; then
    if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
        echo "正在向 $TARGET_MK 注册 H29K 设备 (跳过 U-Boot 封装)..."
        cat >> "$TARGET_MK" <<'EOF'

define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  # 关键：置空 UBOOT 变量，彻底避开 dd 找不到文件的报错
  UBOOT_DEVICE_NAME := 
  # 主流方式：使用 rockchip-combined 生成带 GPT 分区表的完整镜像
  IMAGE/sysupgrade.img.gz := rockchip-combined | append-metadata
  # 插件包
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-drm-rockchip kmod-console-font \
    kmod-usb3 kmod-usb-dwc3-rockchip \
    kmod-usb-net-rndis kmod-usb-net-cdc-ether kmod-usb-net-rtl8152 \
    kmod-usb-serial-option uqmi \
    luci-i18n-base-zh-cn luci-i18n-qmodem-next-zh-cn kmod-usb-net-cdc-mbim kmod-usb-net-cdc-ncm \
    luci-theme-argon luci-app-argon-config luci-app-turboacc luci-app-sqm
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# 3. 注入直播优化内核配置
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    # 先清理可能存在的冲突项
    sed -i '/CONFIG_MHI/d' "$KERNEL_CONF"
    sed -i '/CONFIG_TCP_CONG_BBR/d' "$KERNEL_CONF"
    
    cat >> "$KERNEL_CONF" <<EOF
# 5G Support
CONFIG_PCI=y
CONFIG_PCIE_ROCKCHIP=y
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_MHI_NET=y
CONFIG_MHI_WWAN_CTRL=y
CONFIG_WWAN=y
# BBR for stable streaming
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
EOF
fi

# 4. 系统基础设置
# 主机名与SSID
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate
sed -i 's/ssid=".*"/ssid="H29K"/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# 默认语言与时区
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i "s/'UTC'/'CST-8'\n\t\tset system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 5. 语言包自动选中逻辑 (执行前先展开依赖)
if [ -f .config ]; then
    echo "正在执行依赖展开并匹配中文包..."
    # 强制开启核心中文支持
    echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config
    # 遍历已选插件并开启对应中文包
    grep "=y" .config | grep "CONFIG_PACKAGE_luci-app-" | sed 's/CONFIG_PACKAGE_luci-app-//g;s/=y//g' | while read -r app; do
        echo "CONFIG_PACKAGE_luci-i18n-$app-zh-cn=y" >> .config
    done
fi

# 6. 强制生成完整依赖配置，确保语言包扫描完整
make defconfig

# 7. 强制移除 .config 中可能残留的 jffs2 生成选项
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config 2>/dev/null

# 8. 修复 QModem 初始化脚本找不到 functions.sh 的问题
# 我们在编译目录中强制寻找并确保路径正确
find build_dir/target-aarch64_generic_musl/ -name "qmodem_init" | xargs -I {} sed -i 's|/lib/functions.sh|/usr/share/libubox/functions.sh|g' {} 2>/dev/null

# 9. 如果是缺少核心库，直接从 package 目录中提取并放入 rootfs
mkdir -p build_dir/target-aarch64_generic_musl/root-rockchip/lib/
cp -n package/base-files/files/lib/functions.sh build_dir/target-aarch64_generic_musl/root-rockchip/lib/ 2>/dev/null

# 10. 如果是缺少核心库
touch staging_dir/target-aarch64_generic_musl/image/-u-boot-rockchip.bin
