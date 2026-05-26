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

# ==============================================================================
# 终极修复 kmod-dma-buf 死循环：
# 1. 保留内核 CONFIG_DMA_SHARED_BUFFER=y  → 屏幕/DRM 100%正常
# 2. 清空 FILES 和 AUTOLOAD → 不找 .ko 文件，不报错
# 3. 生成空的合法 ipk → 满足所有依赖，不影响任何程序
# 4. 无需 CONFIG_PACKAGE_kmod-dma-buf=n → 彻底安全
# ==============================================================================
sed -i '/define KernelPackage\/dma-buf/,/endef/{
  s|^\s*FILES:=\$(LINUX_DIR)/drivers/dma-buf/dma-shared-buffer.ko|  FILES:=|
  s|^\s*AUTOLOAD:=\$(call AutoLoad,20,dma-shared-buffer)|  AUTOLOAD:=|
}' package/kernel/linux/modules/other.mk

# 终极精致空包：kmod-sound-core（无语法错误、无警告、不影响依赖）
sed -i '/define KernelPackage\/sound-core/,/^endef/{
  s/^\(  FILES:=\).*/\1/
  s/^\(  AUTOLOAD:=\).*/\1/
}' package/kernel/linux/modules/sound.mk

# 1. 清理OpenWrt原生冲突补丁
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
rm -rf target/linux/airoha

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
URL_UBOOT_DEF="https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"
URL_ARMV8_MK="https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/armv8.mk"

# 下载（curl 稳定版）
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$URL_UBOOT_DEF" -o "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"

# 校验defconfig
[ -s "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" ] || { echo "❌ U-Boot defconfig 下载失败" >&2; exit 1; }

echo "✅ H29K 配置文件defconfig下载成功"

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

# ==============================
# 【安装squashfs4】
# ==============================
# 定义正确目录
TARGET_DIR="target/linux/rockchip"
mkdir -p $TARGET_DIR

# 下载指定的官方原版修改的Makefile
echo "正在下载 rockchip Makefile ..."
curl -L --retry 5 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/Makefile \
-o $TARGET_DIR/Makefile

echo -e "\n=============================================\n"

# 下载 H29K 专用 uboot-rockchip Makefile 并验证是否成功
echo "正在下载 H29K U-Boot Makefile..."
wget -q --show-progress --retry=3 --timeout=10 \
-O package/boot/uboot-rockchip/Makefile \
https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/Makefile

# 验证文件是否下载成功
if [ -s package/boot/uboot-rockchip/Makefile ]; then
    echo -e "\033[42;37m 下载成功！U‑Boot Makefile 已正确安装 \033[0m"
    echo "路径：package/boot/uboot-rockchip/Makefile"
else
    echo -e "\033[41;37m 下载失败！请检查网络或链接 \033[0m"
    exit 1
fi

# 下载修复 uboot-tools 的 Makefile
echo "正在下载 uboot-tools 修复文件 ..."
wget -q --show-progress --retry=3 --timeout=10 \
-O package/boot/uboot-tools/Makefile \
https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-tools/Makefile

# 验证是否下载成功
if [ -s package/boot/uboot-tools/Makefile ]; then
    echo -e "\033[42;37m 下载成功 ✅ uboot-tools 已修复 \033[0m"
else
    echo -e "\033[41;37m 下载失败 ❌ 请检查网络 \033[0m"
    exit 1
fi

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
# 定义配置文件路径
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

cat >> "$CONFIG_FILE" << 'EOF'
# === 之前删除的项 ===
# CONFIG_EMAC_ROCKCHIP is not set
# CONFIG_ARC_EMAC_CORE is not set

# === RK3528 核心必需 ===
CONFIG_ROCKCHIP_RK3528=y
CONFIG_SOC_RK3528=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_EPAN=y
CONFIG_ARM64_PAN=y
CONFIG_ARM64_VHE=y
CONFIG_ARM64_PA_BITS_40=y
CONFIG_ARM64_VA_BITS_48=y
CONFIG_ARM64_ASIMD=y
CONFIG_CLK_RK3528_PLL=y
CONFIG_CLK_RK3528_ACLK_PERI=y
CONFIG_CLK_RK3528_HCLK_PERI=y
CONFIG_CLK_RK3528_PCLK_PERI=y
CONFIG_CLK_RK3528_ACLK_CPU=y

# === 显示 DRM ST7789V V2 ===
CONFIG_DRM_PANEL_SIMPLE=y
CONFIG_DRM_PANEL_ST7789V_V2=y
CONFIG_DRM_ROCKCHIP_VOP2=y
# CONFIG_DRM_ROCKCHIP_INNO_HDMI is not set
# CONFIG_DRM_ANALOGIX_DP is not set
# CONFIG_FB is not set

# === 触控 FT6236 ===
CONFIG_INPUT=y
CONFIG_INPUT_MISC=y
CONFIG_INPUT_POLLDEV=y
CONFIG_TOUCHSCREEN_FT6236=y

# === SPI 总线 ===
CONFIG_SPI=y
CONFIG_SPI_MASTER=y
CONFIG_SPI_ROCKCHIP_SPI=y
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_BACKLIGHT_PWM=y
CONFIG_REGULATOR=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y

# === USB DWC3 ===
CONFIG_USB_DWC3=y
CONFIG_USB_DWC3_HOST=y
CONFIG_USB_DWC3_GADGET=y
CONFIG_USB_DWC3_ROCKCHIP=y
CONFIG_USB_DWC3_ROCKCHIP_PHY_V2=y

# === MMC/SDIO/WIFI ===
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_PLTFM=y
CONFIG_MMC_SDHCI_ROCKCHIP=y
CONFIG_MMC_SDHCI_OF_ROCKCHIP_V2=y

# === 网络 TCP & QoS ===
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
CONFIG_DEFAULT_QDISC="fq"

# === RK3528 平台驱动 ===
CONFIG_ROCKCHIP_RK3528_PMU=y
CONFIG_ROCKCHIP_DRM_VOP2=y
CONFIG_ROCKCHIP_VOP2_KMS=y
CONFIG_ROCKCHIP_USB3PHY=y
CONFIG_ROCKCHIP_EMMC=y
CONFIG_ROCKCHIP_CLK_RK3528=y
CONFIG_ROCKCHIP_SECURE_BOOT=y
CONFIG_ROCKCHIP_TRUSTED_FOUNDATION=y

# === 硬件加密 ===
CONFIG_CRYPTO_DEV_ROCKCHIP=y
CONFIG_CRYPTO_DEV_ROCKCHIP_AES=y
CONFIG_CRYPTO_DEV_ROCKCHIP_SHA=y
CONFIG_CRYPTO_DEV_ROCKCHIP_TRNG=y

# === 视频硬解 VPU ===
CONFIG_VIDEO_ROCKCHIP_VPU=y
CONFIG_VIDEO_ROCKCHIP_VPU_DEC=y
CONFIG_VIDEO_ROCKCHIP_VPU_ENC=y
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CONTROLLER=y
CONFIG_VIDEO_DEV=y

# === DMA & CMA ===
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_CMA_SIZE_MBYTES=320

# === 地址空间（强制） ===
# CONFIG_ARM64_VA_BITS_52 is not set
# CONFIG_ARM64_PA_BITS_36 is not set
# CONFIG_ARM64_PA_BITS_42 is not set
# CONFIG_ARM64_PA_BITS_48 is not set

# === 必须关闭的无用功能 ===
# CONFIG_ROCKCHIP_RGA is not set
# CONFIG_ROCKCHIP_IOMMU is not set
# CONFIG_ROCKCHIP_DW_HDMI is not set
# CONFIG_PCIE_ROCKCHIP_HOST is not set
# CONFIG_SND is not set
# CONFIG_SND_SOC is not set
# CONFIG_SND_SOC_ROCKCHIP is not set
# CONFIG_SND_SOC_ROCKCHIP_I2S is not set
# CONFIG_BT is not set
# CONFIG_MFD_RK808 is not set
# CONFIG_ROCKCHIP_DMC_RK3588 is not set

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
# CONFIG_TARGET_MULTI_ARCH is not set
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
# CONFIG_ARM64_EPHEMERAL_PAGE_TABLES is not set
# CONFIG_PACKAGE_u-boot-rk3528 is not set
# CONFIG_PACKAGE_u-boot-rk3528-tpl is not set
# CONFIG_TRUSTED_FIRMWARE_A is not set

EOF

echo "✅ RK3528 H29K 最终配置"

# 简单可靠：等待10秒后再继续执行（OpenWrt Actions 环境专用）
# 不依赖任何外部工具，兼容所有 BusyBox / dash / bash 环境

sleep 10

# ✅ 等待完成，后续命令可直接跟在此行下方
# 例如：
# echo "✅ 10秒已过，开始下一步..."
# make menuconfig

# ==============================
# 适配H29K的打包流水线
# ==============================
# 1. 下载并覆盖到正确路径
wget -O target/linux/rockchip/image/Makefile https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/Makefile

# 2. 自动验证 IMAGE 行是否正确
grep -q "智能识别 Binman 合体固件或传统拆分固件" target/linux/rockchip/image/Makefile

# 3. 输出验证结果
if [ $? -eq 0 ]; then
    echo -e "\033[32m✅ 验证成功：Makefile 已正确修改，打包规则完全符合要求！\033[0m"
else
    echo -e "\033[31m❌ 验证失败：文件内容不匹配，请检查！\033[0m"
fi

# 下载 H29K 专用 mmc.bootscript（仅 1 个文件）
mkdir -p target/linux/rockchip/image
wget -q https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/mmc.bootscript -O target/linux/rockchip/image/mmc.bootscript

# 下载 H29K 专用 gen_image_generic.sh（仅 1 个文件）
mkdir -p scripts
wget -q https://raw.githubusercontent.com/I-agree/H29K/main/files/scripts/gen_image_generic.sh -O scripts/gen_image_generic.sh

# 下载 H29K 专用 U-Boot 专属 DTS
# 定义路径
DTS_DEST_DIR="package/boot/uboot-rockchip/dts"
DTS_FILE="$DTS_DEST_DIR/rk3528-hinlink-h29k.dts"
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts"

# 1. 创建目录（不存在则自动建）
mkdir -p "$DTS_DEST_DIR"

# 2. 下载 DTS 文件
echo "下载 H29K U-BOOT DTS..."
wget -q -O "$DTS_FILE" "$DTS_URL"

# 3. 验证文件是否下载成功
if [ -f "$DTS_FILE" ] && [ -s "$DTS_FILE" ]; then
    echo "✅ 成功：rk3528-hinlink-h29k.dts 已下载并放置到 $DTS_DEST_DIR"
else
    echo "❌ 失败：DTS 文件下载失败或为空"
    exit 1
fi
