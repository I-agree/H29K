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

# ====================== 方案：全套切换为LEDE rk3528.dtsi + rk3528-pinctrl.dtsi ======================
# 1. 清理OpenWrt原生冲突DTS和补丁
rm -rf target/linux/rockchip/patches-6.12
rm -rf target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528*.dtsi

# 定义路径
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/"
mkdir -p "$DTS_DIR"

# 下载 LEDE 原版 rk3528.dtsi
wget -q -O "$DTS_DIR/rk3528.dtsi" \
https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528.dtsi

# 下载 LEDE 原版 rk3528-pinctrl.dtsi
wget -q -O "$DTS_DIR/rk3528-pinctrl.dtsi" \
https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-pinctrl.dtsi

# 验证文件是否下载成功
if [ ! -s "$DTS_DIR/rk3528.dtsi" ] || [ ! -s "$DTS_DIR/rk3528-pinctrl.dtsi" ]; then
    echo "❌ 下载 DTSI 文件失败，停止编译！"
    exit 1
fi

echo "✅ 成功下载 LEDE rk3528.dtsi + rk3528-pinctrl.dtsi 到正确目录"

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
CONFIG_PACKAGE_kmod-usb-dwc3-rockchip=y
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

# ==============================================
# 清理 Rockchip 旧网卡驱动（RK3528/H29K 不需要）
# ==============================================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 删除 CONFIG_EMAC_ROCKCHIP=y
sed -i '/CONFIG_EMAC_ROCKCHIP=y/d' "$CONFIG_FILE"

# 删除 CONFIG_ARC_EMAC_CORE=y
sed -i '/CONFIG_ARC_EMAC_CORE=y/d' "$CONFIG_FILE"

echo "✅ 已清理无用网卡配置：CONFIG_EMAC_ROCKCHIP 和 CONFIG_ARC_EMAC_CORE 已删除"

# ==============================================
# 为 Hinlink H29K 添加内核驱动配置
# ==============================================
# 内容覆盖写入 config-6.12（注意：使用 > 而非 >>，确保干净替换）
cat > target/linux/rockchip/armv8/config-6.12 << 'EOF'
# RK3528-specific additions (required)
CONFIG_ROCKCHIP_RK3528=y
CONFIG_ROCKCHIP_RK3528_PMU=y
CONFIG_ROCKCHIP_DRM_VOP2=y
CONFIG_ROCKCHIP_VOP2_KMS=y
CONFIG_ROCKCHIP_USB3PHY=y
CONFIG_ROCKCHIP_EMMC=y
CONFIG_ROCKCHIP_CLK_RK3528=y
CONFIG_ROCKCHIP_THERMAL=y
CONFIG_ROCKCHIP_ERRATUM_3568002=n
CONFIG_SPARSEMEM_VMEMMAP=n
CONFIG_ARM64_VA_BITS_39=y
CONFIG_ARM64_PAN=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_MODULE_PLTS=y
CONFIG_ARM64_VHE=y
CONFIG_CPU_LITTLE_ENDIAN=y
CONFIG_ARM64_PA_BITS_40=y
CONFIG_NR_CPUS=512
CONFIG_SCHED_MC=n
CONFIG_SCHED_CLUSTER=n
CONFIG_SCHED_SMT=n
CONFIG_UNMAP_KERNEL_AT_EL0=n
CONFIG_RODATA_FULL_DEFAULT_ENABLED=n
CONFIG_ARM64_TAGGED_ADDR_ABI=n
CONFIG_ARM64_SW_TTBR0_PAN=n
CONFIG_ARM64_PSEUDO_NMI=n
CONFIG_COMPAT_32BIT_TIME=n
CONFIG_ARM64_ERRATUM_858921=n
CONFIG_ROCKCHIP_IOMMU=n
CONFIG_ROCKCHIP_DW_HDMI=n
CONFIG_ROCKCHIP_VOP2=n
CONFIG_ROCKCHIP_RGA=n

# RK3528-specific removals (required)
CONFIG_PCIE_ROCKCHIP_HOST=n
CONFIG_SND_SOC_ROCKCHIP_I2S=n
CONFIG_MFD_RK808=n

# Optional cleanup
CONFIG_ARM64_ERRATUM_1530923=n

# RK3528 fixes for Linux 6.12.85 NEW symbol handling
CONFIG_MFD_ROCKCHIP_MFPWM=n
CONFIG_PWM_ROCKCHIP_MFPWM=n
CONFIG_ROCKCHIP_SARADC_V2=n
CONFIG_ROCKCHIP_DMC_RK3588=n
EOF

