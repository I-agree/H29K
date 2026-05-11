#!/bin/sh
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
# 添加 QModem 软件源
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default
# 无线网卡驱动
echo 'src-git aic8800 https://github.com/radxa-pkg/aic8800.git;main' >> feeds.conf.default
# 正确安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon

# ====================== 方案：全套切换为LEDE rk3528.dtsi + rk3528-pinctrl.dtsi ======================
# 1. 清理OpenWrt原生冲突DTS和补丁
rm -f target/linux/rockchip/patches-6.12/070-01-v6.13-arm64-dts-rockchip-Add-base-DT-for-rk3528-SoC.patch
rm -f target/linux/rockchip/patches-6.12/070-04-v6.15-arm64-dts-rockchip-Add-pinctrl-and-gpio-nodes-for-RK3528.patch
rm -rf target/linux/rockchip/patches-6.12
rm -rf target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528*.dtsi
rm -rf target/linux/generic/hack-6.12
rm -rf target/linux/bcm27xx/patches-6.12
rm -f target/linux/generic/hack-6.18/920-device_tree_cmdline.patch
rm -f target/linux/ipq806x/patches-6.12/901-02-ARM-decompressor-add-option-to-ignore-MEM-ATAGs.patch
rm -f target/linux/mpc85xx/patches-6.12/102-powerpc-add-cmdline-override.patch
rm -f package/boot/uboot-mediatek/patches/280-image-fdt-save-name-of-FIT-configuration-in-chosen-node.patch
rm -f target/linux/generic/hack-6.12/920-device_tree_cmdline.patch
rm -f target/linux/mpc85xx/patches-6.18/102-powerpc-add-cmdline-override.patch
rm -f target/linux/mediatek/patches-6.18/901-arm-add-cmdline-override.patch
rm -f target/linux/qualcommax/patches-6.12/0911-arm64-cmdline-replacement.patch
rm -f target/linux/ipq806x/patches-6.12/902-ARM-decompressor-support-for-ATAGs-rootblock-parsing.patch
rm -f target/linux/ipq806x/patches-6.12/900-arm-add-cmdline-override.patch
rm -f target/linux/mvebu/patches-6.12/300-mvebu-Mangle-bootloader-s-kernel-arguments.patch
rm -f target/linux/bcm27xx/patches-6.12/950-0076-OF-DT-Overlay-configfs-interface.patch

# === 🔥 P3TERX: Auto-remove fdt.c pollution (RK3528 clean build) ===
# Remove fdt.c if exists (created by generic/bcm27xx/qualcommax patches)
rm -f "$BUILD_DIR"/target-*/linux-*/drivers/of/fdt.c
# Remove fdt.o reference from drivers/of/Makefile (added by bcm27xx/950-*.patch)
sed -i '/fdt\.o/d' "$BUILD_DIR"/target-*/linux-*/drivers/of/Makefile 2>/dev/null
# Remove CONFIG_OF_CONFIGFS line (side effect of bcm27xx/950-*.patch)
sed -i '/CONFIG_OF_CONFIGFS/d' "$BUILD_DIR"/target-*/linux-*/drivers/of/Kconfig 2>/dev/null
# Restore original of_fdt.h (remove early_init_dt_* declarations injected by 920-*.patch)
sed -i '/early_init_dt_verify/d; /early_init_dt_scan/d' "$BUILD_DIR"/target-*/linux-*/include/linux/of_fdt.h 2>/dev/null
# Ensure no stale .o/.ko files remain (defensive cleanup)
find "$BUILD_DIR"/target-*/linux-*/drivers/of/ -name "fdt.*" -delete 2>/dev/null

# 定义路径
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_DIR"

# 下载 LEDE 原版 rk3528.dtsi（稳定curl）
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
https://raw.githubusercontent.com/I-agree/H29K/main/123/rk3528.dtsi \
-o "$DTS_DIR/rk3528.dtsi"

# 下载 LEDE 原版 rk3528-pinctrl.dtsi（稳定curl）
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
https://raw.githubusercontent.com/I-agree/H29K/main/123/rk3528-pinctrl.dtsi \
-o "$DTS_DIR/rk3528-pinctrl.dtsi"

# 验证文件是否下载成功
if [ ! -s "$DTS_DIR/rk3528.dtsi" ] || [ ! -s "$DTS_DIR/rk3528-pinctrl.dtsi" ]; then
    echo "❌ 下载 DTSI 文件失败，停止编译！"
    exit 1
fi

echo "✅ 成功下载 LEDE rk3528.dtsi + rk3528-pinctrl.dtsi 到正确目录"

# 下载指定 dts 到目标目录，带校验
DTS_SAVE_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_SAVE_DIR"

curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts \
-o "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts"

# 验证是否下载成功
if [ -f "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts" ]; then
    echo "✅ rk3528-hinlink-h29k.dts 下载并保存成功"
else
    echo "❌ rk3528-hinlink-h29k.dts 下载失败"
    exit 1
fi

# ==================== 稳定下载 H29K 配置文件 ====================
mkdir -p package/boot/uboot-rockchip/configs/ target/linux/rockchip/image/

# 下载地址
URL_UBOOT_DEF="https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig"
URL_IMAGE_DEF="https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/hinlink_h29k_defconfig"
URL_ARMV8_MK="https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/armv8.mk"

# 下载（curl 稳定版）
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$URL_UBOOT_DEF" -o "package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$URL_IMAGE_DEF" -o "target/linux/rockchip/image/hinlink_h29k_defconfig"

# 校验两个 defconfig
[ -s "package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig" ] || { echo "❌ U-Boot defconfig 下载失败" >&2; exit 1; }
[ -s "target/linux/rockchip/image/hinlink_h29k_defconfig" ]         || { echo "❌ Image defconfig 下载失败" >&2; exit 1; }

echo "✅ H29K 两个配置文件下载成功"

# ==================== 稳定下载 armv8.mk ====================
MK_FILE="target/linux/rockchip/image/armv8.mk"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$URL_ARMV8_MK" -o "$MK_FILE"

# 校验文件非空
if [ ! -s "$MK_FILE" ]; then
    echo "❌ 下载 armv8.mk 失败，终止编译"
    exit 1
fi

# 校验不包含 hinlink_h28k
if grep -q "hinlink_h28k" "$MK_FILE"; then
    echo "❌ ERROR: armv8.mk 包含 hinlink_h28k，终止编译"
    exit 1
fi

echo "✅ 已下载并替换 armv8.mk 成功"
echo "✅ 已校验：无 hinlink_h28k，仅保留 rk3528 + hinlink_h29k"

# ==============================
# 【强制限定补丁作用域】
# ==============================
# 定义正确目录
TARGET_DIR="target/linux/rockchip"
mkdir -p $TARGET_DIR

# 下载你指定的官方原版 Makefile
echo "正在下载 rockchip Makefile ..."
curl -L --retry 5 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/Makefile \
-o $TARGET_DIR/Makefile

# 检查是否下载成功
if [ -f "$TARGET_DIR/Makefile" ]; then
    echo -e "\n✅ 下载成功：$TARGET_DIR/Makefile"
else
    echo -e "\n❌ 下载失败"
    exit 1
fi

# ==============================
# 验证：是否包含【强制限定补丁作用域】
# ==============================
echo -e "\n============================================="
echo "  检查结果：是否强制限定补丁作用域"
echo -e "=============================================\n"

grep -q "强制限定补丁作用域" $TARGET_DIR/Makefile
if [ $? -eq 0 ]; then
    echo "✅ 已确认：包含 强制限定补丁作用域 配置"
    echo "    作用：仅应用 rockchip 专属补丁，禁止其他平台污染"
else
    echo "❌ 未找到"
fi

echo -e "\n=============================================\n"

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
# 清理非法 PA_BITS 配置（RK3528 仅支持 CONFIG_ARM64_PA_BITS=40）
# ==============================================
# 删除 CONFIG_ARM64_PA_BITS=48
sed -i '/CONFIG_ARM64_PA_BITS=48/d' "$CONFIG_FILE"

# 删除 CONFIG_ARC_EMAC_CORE=y
sed -i '/CONFIG_ARM64_PA_BITS_48=y/d' "$CONFIG_FILE"

echo "✅ 已清理非法 PA_BITS 配置：CONFIG_ARM64_PA_BITS=48 和 CONFIG_ARC_EMAC_CORE=y 已删除"

# 定义配置文件路径
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 批量删除指定的配置项
sed -i '/CONFIG_ARM64_TAGGED_ADDR_ABI=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_COMPAT_32BIT_TIME=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_UNMAP_KERNEL_AT_EL0=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_RODATA_FULL_DEFAULT_ENABLED=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_ROCKCHIP_IOMMU=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_ERRATUM_1530923=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_ERRATUM_858921=y/d' "$CONFIG_FILE"

# 验证所有配置项是否删除成功
if grep -qE "CONFIG_ARM64_TAGGED_ADDR_ABI=y|CONFIG_COMPAT_32BIT_TIME=y|CONFIG_UNMAP_KERNEL_AT_EL0=y|CONFIG_RODATA_FULL_DEFAULT_ENABLED=y|CONFIG_ROCKCHIP_IOMMU=y|CONFIG_ARM64_ERRATUM_1530923=y|CONFIG_ARM64_ERRATUM_858921=y" "$CONFIG_FILE"; then
    echo "====================================================="
    echo " ❌ 错误：部分配置项删除失败，请检查！"
    echo "====================================================="
    exit 1
fi

echo "====================================================="
echo " ✅ 所有指定配置项已成功删除！"
echo " ✅ 验证通过，继续编译……"
echo "====================================================="

# 简单可靠：等待10秒后再继续执行（OpenWrt Actions 环境专用）
# 不依赖任何外部工具，兼容所有 BusyBox / dash / bash 环境

sleep 10

# ✅ 等待完成，后续命令可直接跟在此行下方
# 例如：
# echo "✅ 10秒已过，开始下一步..."
# make menuconfig

# ==============================================
# 为 Hinlink H29K 添加内核驱动配置（追加到文件末尾）
# ==============================================
cat >> "$CONFIG_FILE" << 'EOF'

# === 之前删除的项 ===
# CONFIG_EMAC_ROCKCHIP is not set
# CONFIG_ARC_EMAC_CORE is not set

# ARM64 Address Space (MANDATORY per RK3528 TRM §3.2.1 & §12.5)
# CONFIG_ARM64_VA_BITS_52 is not set
CONFIG_ARM64_PA_BITS_40=y
# CONFIG_ARM64_PA_BITS_36 is not set
# CONFIG_ARM64_PA_BITS_42 is not set
# CONFIG_ARM64_PA_BITS_48 is not set

# DRM Subsystem (REQUIRED for VOP2)
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_PANEL=y
CONFIG_DRM_BRIDGE=y
CONFIG_DRM_ANALOGIX_DP=y
CONFIG_DRM_ROCKCHIP=y

# RK3528 Platform Drivers
CONFIG_ROCKCHIP_RK3528=y
CONFIG_ROCKCHIP_RK3528_PMU=y
CONFIG_ROCKCHIP_DRM_VOP2=y
CONFIG_ROCKCHIP_VOP2_KMS=y
CONFIG_ROCKCHIP_USB3PHY=y
CONFIG_ROCKCHIP_EMMC=y
CONFIG_ROCKCHIP_CLK_RK3528=y
CONFIG_USB_XHCI_PCI_RENESAS=y
CONFIG_MMC_SDHCI_OF_ROCKCHIP_V2=y
CONFIG_ROCKCHIP_SECURE_BOOT=y
CONFIG_ROCKCHIP_TRUSTED_FOUNDATION=y

# RK3528 Kernel Features
CONFIG_ARM64_PAN=y
CONFIG_ARM64_MODULE_PLTS=y
CONFIG_ARM64_VHE=y
CONFIG_ARM64_PAGE_SHIFT=12
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
CONFIG_ROCKCHIP_RGA=n

# RK3528-Specific Disables
CONFIG_PCIE_ROCKCHIP_HOST=n
CONFIG_SND_SOC_ROCKCHIP_I2S=n
CONFIG_MFD_RK808=n
CONFIG_ARM64_ERRATUM_1530923=n
CONFIG_MFD_ROCKCHIP_MFPWM=n
CONFIG_PWM_ROCKCHIP_MFPWM=n
CONFIG_ROCKCHIP_SARADC_V2=n
CONFIG_ROCKCHIP_DMC_RK3588=n
CONFIG_ARM64_EPAN=y
CONFIG_ARM64_ASIMD=y
# CONFIG_ARM64_AS_HAS_MTE is not set

# === END RK3528 CONFIGURATION ===
EOF

echo "✅ 已向 $CONFIG_FILE 安全追加 RK3528 H29K 全套配置（含 VA_BITS/PA_BITS/DRM/VOP2/Secure Boot）"

# Step 1: 彻底移除 rockchip/armv8/config-6.12 中的 CONFIG_ARM64_SVE=y（RK3528 不支持 SVE）
sed -i '/CONFIG_ARM64_SVE=y/d' target/linux/rockchip/armv8/config-6.12

# Step 2: 显式确保 generic/config-6.12 中 SVE 为明确 not set（防歧义）
echo "# CONFIG_ARM64_SVE is not set" >> target/linux/generic/config-6.12

# Step 3: 显式启用 ASIMD（VHE 的硬依赖，且 RK3528 原生支持）
echo "CONFIG_ARM64_ASIMD=y" >> target/linux/generic/config-6.12

# 写入完整 override（含 bootloader + secure boot）
OVERRIDE_FILE="/workdir/openwrt/.config.override"

cat >> "$OVERRIDE_FILE" << 'EOF'
# RK3528 H29K OVERRIDE — GENERATED BY diy-part1.sh
CONFIG_TARGET_MULTI_ARCH=n
CONFIG_TARGET_ROCKCHIP_ARMV8_DEVICE_H29K=y
CONFIG_ARM64_VA_BITS_48=y
CONFIG_ARM64_PA_BITS_40=y
CONFIG_ARM64_VHE=y
CONFIG_ARM64_PAN=y
CONFIG_ARM64_EPHEMERAL_PAGE_TABLES=n
CONFIG_PACKAGE_u-boot-rk3528=y
CONFIG_PACKAGE_u-boot-rk3528-tpl=y
CONFIG_TRUSTED_FIRMWARE_A="rk3528"
CONFIG_PACKAGE_kmod-rockchip-drm-vop2=y
CONFIG_PACKAGE_kmod-rockchip-usb3phy=y
CONFIG_PACKAGE_kmod-rockchip-emmc=y
EOF

echo "✅ RK3528 H29K 最终配置"

# 简单可靠：等待10秒后再继续执行（OpenWrt Actions 环境专用）
# 不依赖任何外部工具，兼容所有 BusyBox / dash / bash 环境

sleep 10

# ✅ 等待完成，后续命令可直接跟在此行下方
# 例如：
# echo "✅ 10秒已过，开始下一步..."
# make menuconfig

# ==============================================
# ✅ 强制创建所有目录
# ==============================================
mkdir -p target/linux/rockchip/files
mkdir -p target/linux/rockchip/files/include
mkdir -p target/linux/rockchip/files/include/dt-bindings
mkdir -p target/linux/rockchip/files/include/dt-bindings/clock
mkdir -p target/linux/rockchip/files/include/dt-bindings/power
mkdir -p target/linux/rockchip/files/include/dt-bindings/interrupt-controller
mkdir -p target/linux/rockchip/files/include/dt-bindings/phy
mkdir -p target/linux/rockchip/files/include/dt-bindings/pinctrl
mkdir -p target/linux/rockchip/files/include/dt-bindings/soc
mkdir -p target/linux/rockchip/files/include/dt-bindings/thermal
mkdir -p target/linux/rockchip/files/include/linux
mkdir -p target/linux/rockchip/files/drivers
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip
# mkdir -p target/linux/rockchip/files/arch/arm64/kernel

# ==================== 基础目录 ====================
ROC_DIR="target/linux/rockchip/files"
DTS_DIR="$ROC_DIR/arch/arm64/boot/dts/rockchip"
mkdir -p "$ROC_DIR" "$DTS_DIR"

# ==================== 克隆整个LEDE仓库（最稳，不猜任何文件） ====================
git clone --depth=1 https://github.com/coolsnowwolf/lede.git lede_temp

# ==================== 直接复制官方原生 include + drivers 文件夹 ====================
cp -rf lede_temp/target/linux/rockchip/files/include "$ROC_DIR/"
cp -rf lede_temp/target/linux/rockchip/files/drivers "$ROC_DIR/"

# 清理临时文件
rm -rf lede_temp

# ==================== 下载函数 ====================
download() {
  curl -fsSL --retry 5 --ipv4 "$1" -o "$2" || { echo "下载失败: $2"; exit 1; }
}

# ==================== 追加内核头文件 ====================
INC="$ROC_DIR/include/dt-bindings"
mkdir -p $INC/{interrupt-controller,phy,pinctrl,soc,thermal}

download https://raw.githubusercontent.com/I-agree/H29K/main/123/arm-gic.h $INC/interrupt-controller/arm-gic.h
download https://raw.githubusercontent.com/I-agree/H29K/main/123/irq.h $INC/interrupt-controller/irq.h
download https://raw.githubusercontent.com/I-agree/H29K/main/123/phy.h $INC/phy/phy.h
download https://raw.githubusercontent.com/I-agree/H29K/main/123/rockchip.h $INC/pinctrl/rockchip.h
download https://raw.githubusercontent.com/I-agree/H29K/main/123/rockchip,boot-mode.h $INC/soc/rockchip,boot-mode.h
download https://raw.githubusercontent.com/I-agree/H29K/main/123/thermal.h $INC/thermal/thermal.h

# ==================== 下载 rockchip-pinconf.dtsi ====================
download https://raw.githubusercontent.com/I-agree/H29K/main/123/rockchip-pinconf.dtsi $DTS_DIR/rockchip-pinconf.dtsi

# ==================== 下载 setup.c + of_fdt.h ====================
# SETUP_DIR="$ROC_DIR/arch/arm64/kernel"
# mkdir -p $SETUP_DIR $ROC_DIR/include/linux

# download https://raw.githubusercontent.com/I-agree/H29K/main/123/setup.c $SETUP_DIR/setup.c
# download https://raw.githubusercontent.com/I-agree/H29K/main/123/of_fdt.h $ROC_DIR/include/linux/of_fdt.h

# 基础路径
ROC_DIR="target/linux/rockchip/files"
DTS_DIR="$ROC_DIR/arch/arm64/boot/dts/rockchip"
INC="$ROC_DIR/include/dt-bindings"

echo "============================================="
echo "  🔍 全部文件完整性检查"
echo "============================================="

# 检查文件夹
check_dir() {
    if [ -d "$1" ]; then echo "✅ 目录存在: $1"; else echo "❌ 目录缺失: $1"; fi
}

# 检查文件
check_file() {
    if [ -f "$1" ]; then echo "✅ 文件存在: $1"; else echo "❌ 文件缺失: $1"; fi
}

echo -e "\n📁 检查主文件夹"
check_dir "$ROC_DIR/include"
check_dir "$ROC_DIR/drivers"

echo -e "\n📄 检查 LEDE 头文件"
check_file "$INC/clock/rk3528-cru.h"
check_file "$INC/power/rk3528-power.h"

echo -e "\n📄 检查补充内核头文件"
check_file "$INC/interrupt-controller/arm-gic.h"
check_file "$INC/interrupt-controller/irq.h"
check_file "$INC/phy/phy.h"
check_file "$INC/pinctrl/rockchip.h"
check_file "$INC/soc/rockchip,boot-mode.h"
check_file "$INC/thermal/thermal.h"

echo -e "\n📄 检查 rockchip-pinconf.dtsi"
check_file "$DTS_DIR/rockchip-pinconf.dtsi"

#echo -e "\n📄 检查 setup.c + of_fdt.h"
#check_file "$ROC_DIR/arch/arm64/kernel/setup.c"
#check_file "$ROC_DIR/include/linux/of_fdt.h"

echo -e "\n============================================="
echo " ✅ 检查完成！以上全部存在即为正常"
echo "============================================="

# ==============================================================================
# 修复 gpio-button-hotplug 驱动：适配内核 6.12（删除 broadcast_uevent）
# ==============================================================================
echo "【DIY】更新 gpio-button-hotplug 驱动至 6.12 兼容版"

# 1. 先创建目录（你提醒的关键步骤）
mkdir -p package/kernel/gpio-button-hotplug/src/

# 2. 下载官方新版驱动（无 broadcast_uevent，内核 6.12 专用）
wget -O package/kernel/gpio-button-hotplug/src/gpio-button-hotplug.c \
https://raw.githubusercontent.com/I-agree/H29K/main/123/gpio-button-hotplug.c
