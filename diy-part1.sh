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

# ====================== 方案B：全套切换为 LEDE 原版 ======================
# 1. 清理OpenWrt原生冲突DTS和补丁
rm -rf target/linux/rockchip/patches-6.12
rm -rf target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528*.dtsi

# 2. 下载 LEDE 全套 rockchip patches-6.12
git clone --depth 1 --single-branch --branch master https://github.com/coolsnowwolf/lede.git /tmp/lede-tmp

# 3. 复制LEDE原版补丁、DTS覆盖到当前OpenWrt
mkdir -p target/linux/rockchip/
cp -r /tmp/lede-tmp/target/linux/rockchip/patches-6.12 target/linux/rockchip/
cp -r /tmp/lede-tmp/target/linux/rockchip/files target/linux/rockchip/

# 4. 清理临时文件
rm -rf /tmp/lede-tmp

# 5. 验证关键文件是否就位
echo "==== 校验LEDE原版RK3528文件 ===="
ls -lh target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528*.dtsi
ls -lh target/linux/rockchip/patches-6.12/*rk3528*

echo "✅ 已切换为LEDE全套源码+补丁，版本完全对齐，无补丁冲突"

# ====== BEGIN: Predefine config via .config.override ======
echo "🔧 Writing .config.override for u-boot-rk3528..."

cat > /workdir/openwrt/.config.override << 'EOF'
# RK3528 Bootloader Stack — Auto-enabled by diy-part1.sh
CONFIG_TARGET_MULTI_ARCH=n
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_SUBTARGET_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
CONFIG_PACKAGE_u-boot-rk3528=y
CONFIG_PACKAGE_u-boot-rk3528-tpl=y
CONFIG_TRUSTED_FIRMWARE_A="rk3528"
CONFIG_PACKAGE_kmod-rockchip-pcie=y
CONFIG_PACKAGE_kmod-usb-dwc3-rockchip=y
CONFIG_PACKAGE_kmod-sound-soc-rockchip=y
# Optional: Pin rkbin version to prevent accidental upgrade
CONFIG_RKBIN_VERSION="2025.06.13"
EOF

echo "✅ .config.override written with RK3528 bootloader stack"
ls -l /workdir/openwrt/.config.override

# Now run defconfig — it will merge .config.override automatically
cd /workdir/openwrt
make defconfig > /dev/null 2>&1
echo "✅ make defconfig completed with override applied"
# ====== END ======

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

mkdir -p package/boot/uboot-rockchip/configs/ target/linux/rockchip/image/
wget -O package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig
wget -O target/linux/rockchip/image/hinlink_h29k_defconfig https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/hinlink_h29k_defconfig
[ -f package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig ] && [ -f target/linux/rockchip/image/hinlink_h29k_defconfig ] || { echo "❌ H29K config download failed" >&2; exit 1; }

# 下载纯净版 armv8.mk 替换，只保留 rk3528 + hinlink_h29k
MK_FILE="target/linux/rockchip/image/armv8.mk"

# 下载 raw 原始文件
wget -O "$MK_FILE" https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/armv8.mk

# 校验下载是否成功
if [ ! -s "$MK_FILE" ]; then
    echo "ERROR: 下载 armv8.mk 失败，终止编译"
    exit 1
fi

# 校验不包含 hinlink_h28k
if grep -q "hinlink_h28k" "$MK_FILE"; then
    echo "ERROR: armv8.mk 包含 hinlink_h28k，终止编译"
    exit 1
fi

echo "✅ 已下载并替换 armv8.mk 成功"
echo "✅ 已校验：无 hinlink_h28k，仅保留 rk3528 + hinlink_h29k"

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
