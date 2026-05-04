#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default
# 无线网卡驱动
echo 'src-git aic8800 https://github.com/radxa-pkg/aic8800.git;main' >> feeds.conf.default
# 添加 Argon 主题源
echo 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' >> feeds.conf.default
# 添加 Argon 配置插件源
echo 'src-git jerrykuku https://github.com/jerrykuku/luci-app-argon-config.git;master' >> feeds.conf.default
# 添加 OpenAppFilter 插件源
#echo 'src-git OpenAppFilter https://github.com/destan19/OpenAppFilter.git;master' >> feeds.conf.default

# 下载指定 dts 到目标目录，带校验
DTS_SAVE_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/"
mkdir -p "$DTS_SAVE_DIR"

wget -q https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts \
-O "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts"

# 验证是否下载成功
if [ -f "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts" ]; then
    echo "✅ rk3528-hinlink-h29k.dts 下载并保存成功"
else
    echo "❌ rk3528-hinlink-h29k.dts 下载失败"
    exit 1
fi

# ======================== 【添加 H29K：armv8.mk 设备定义】 ========================
# ✅ 修复点3：DEVICE_DTS 使用标准社区命名 rk3528-hinlink-h29k（非 opc- 前缀）
TARGET_MK="target/linux/rockchip/image/armv8.mk"

cat >> "$TARGET_MK" <<'EOF'
# 📌 设备定义：HINLINK H29K（RK3528）有线网卡kmod-r8168驱动集成到内核
#    - 遵循 OpenWrt 命名规范：rk3528-{vendor}-{model}
define Device/hinlink_h29k
  SOC := rk3528
  SUBTARGET := armv8
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  TRUSTED_FIRMWARE_A := rk3528
  UBOOT_CONFIG := hinlink_h29k
  KERNEL_LOADADDR := 0x00280000
  KERNEL_ENTRYADDR := 0x00280000
  DEVICE_UBOOT_IMAGE := u-boot-rockchip-hinlink_h29k.bin
  DEVICE_COMPAT_VERSION := 1
  SUPPORTED_DEVICES := hinlink_h29k
  IMAGE/boot.bin := boot-scr | boot-kernel | boot-dtb
  IMAGE/sysupgrade.img.gz := boot.bin | append-rootfs | pad-rootfs | check-size | gzip
  DEVICE_PACKAGES := \
    kmod-usb3 kmod-aic8800-sdio dnsmasq-full \
    kmod-usb-net-cdc-mbim uqmi qmi-utils kmod-usb-serial-option kmod-usb-net-rndis-host \
    luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn \
    luci-theme-argon imagemagick imagemagick-jpeg imagemagick-png imagemagick-gif curl irqbalance \
    luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn \
    luci-app-bbr luci-i18n-bbr-zh-cn luci-mod-admin-full \
    luci-app-irqbalance luci-i18n-irqbalance-zh-cn \
    dnscrypt-proxy luci-app-dnscrypt-proxy luci-i18n-dnscrypt-proxy-zh-cn \
    luci-app-oaf appfilter luci-i18n-oaf-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF

# ==============================================
# 定制 uboot-rockchip：替换 rk3528 默认配置 + 添加 H29K
# ==============================================
sed -i '/^define U-Boot\/rk3528\/Default/,/^endef/d' package/boot/uboot-rockchip/Makefile

# 将新设备添加到 UBOOT_TARGETS 编译列表
sed -i '/hinlink-h28k-rk3528/a\
  hinlink-h29k-rk3528 \\\
' package/boot/uboot-rockchip/Makefile

# 插入新的 rk3528/Default
sed -i '/# RK3528 boards/a\
define U-Boot/rk3528/Default\n\
  BUILD_SUBTARGET:=armv8\n\
  DEPENDS:=+PACKAGE_u-boot-$(1):trusted-firmware-a-rk3528\n\
  ATF:=rk3528_bl31_v1.20.elf\n\
  # ⚠️ Default TPL is for reference only — DO NOT use for H29K\n\
  TPL:=rk3528_ddr_1056MHz_v1.11.bin\n\
endef\n\
' package/boot/uboot-rockchip/Makefile

# 插入 hinlink-h29k-rk3528 设备定义
sed -i '/^define U-Boot\/radxa-e20c-rk3528/i\
define U-Boot/hinlink-h29k-rk3528\n\
  $(U-Boot/rk3528/Default)\n\
  NAME:=HINLINK H29K\n\
  BUILD_DEVICES:= \\\n\
    hinlink_h29k\n\
  UBOOT_CONFIG:=rk3528/hinlink_h29k_defconfig\n\
  UBOOT_DTS:=rockchip/rk3528-hinlink-h29k\n\
  TPL:=rk3528_ddr_1066MHz_v1.13.bin\n\
  MINILOADER:=rk3528_miniloader_v1.13.bin\n\
endef\n\
' package/boot/uboot-rockchip/Makefile
