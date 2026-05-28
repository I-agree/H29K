#!/bin/sh
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)

# === 1. 软件源与主题配置 ===
# 添加 QModem 软件源
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default
# 无线网卡驱动
echo 'src-git aic8800 https://github.com/radxa-pkg/aic8800.git;main' >> feeds.conf.default
# 正确安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon

# === 2. 核心规避：终极修复 kmod-dma-buf 与 kmod-sound-core 编译死循环 ===
sed -i '/define KernelPackage\/dma-buf/,/endef/{
  s|^\s*FILES:=\$(LINUX_DIR)/drivers/dma-buf/dma-shared-buffer.ko|  FILES:=|
  s|^\s*AUTOLOAD:=\$(call AutoLoad,20,dma-shared-buffer)|  AUTOLOAD:=|
}' package/kernel/linux/modules/other.mk

sed -i '/define KernelPackage\/sound-core/,/^endef/{
  s/^\(  FILES:=\).*/\1/
  s/^\(  AUTOLOAD:=\).*/\1/
}' package/kernel/linux/modules/sound.mk

# === 3. 清理 OpenWrt 原生多余/冲突的架构补丁（切断污染源） ===
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

# === 4. 下载 H29K 专用核心设备树 (DTS) 与固件 Makefile 资源 ===
DTS_SAVE_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_SAVE_DIR"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts \
-o "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts"

if [ ! -s "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts" ]; then
    echo "❌ rk3528-hinlink-h29k.dts 下载失败或为空"
    exit 1
fi
echo "✅ rk3528-hinlink-h29k.dts 下载并校验成功"

# 建立基础下载路径
mkdir -p package/boot/uboot-rockchip/configs/ target/linux/rockchip/image/

# 下载 U-Boot defconfig
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig \
-o package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig
[ -s "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" ] || { echo "❌ U-Boot defconfig 下载失败"; exit 1; }

# 下载并校验 armv8.mk
MK_FILE="target/linux/rockchip/image/armv8.mk"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/armv8.mk -o "$MK_FILE"
if [ ! -s "$MK_FILE" ] || grep -q "hinlink_h28k" "$MK_FILE"; then
    echo "❌ armv8.mk 下载失败或包含非法内容 (h28k)"
    exit 1
fi

# 下载底座 Makefile 编译策略
curl -L --retry 5 https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/Makefile -o target/linux/rockchip/Makefile
wget -q --retry-connrefused --waitretry=2 -O package/boot/uboot-rockchip/Makefile https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/Makefile
wget -q --retry-connrefused --waitretry=2 -O package/boot/uboot-tools/Makefile https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-tools/Makefile

# === 5. 🎯 针对 H29K 进行内核配置（config-6.12）的强力清洗与合并注入 ===
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# A. 彻底抹除原文件中与 H29K 冲突或会导致覆盖失效的底层选项
sed -i '/CONFIG_EMAC_ROCKCHIP/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARC_EMAC_CORE/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_PA_BITS/d' "$CONFIG_FILE"
sed -i '/CONFIG_ROCKCHIP_IOMMU/d' "$CONFIG_FILE"
sed -i '/CONFIG_CMA_SIZE_MBYTES/d' "$CONFIG_FILE"
sed -i '/CONFIG_CRYPTO_DEV_ROCKCHIP/d' "$CONFIG_FILE"
sed -i '/CONFIG_UNMAP_KERNEL_AT_EL0/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_TAGGED_ADDR_ABI/d' "$CONFIG_FILE"
sed -i '/CONFIG_COMPAT_32BIT_TIME/d' "$CONFIG_FILE"
sed -i '/CONFIG_RODATA_FULL_DEFAULT_ENABLED/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_ERRATUM_1530923/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_ERRATUM_858921/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_SVE/d' "$CONFIG_FILE"

# 强力防御性验证
if grep -qE "CONFIG_ARM64_TAGGED_ADDR_ABI=y|CONFIG_COMPAT_32BIT_TIME=y|CONFIG_UNMAP_KERNEL_AT_EL0=y|CONFIG_ROCKCHIP_IOMMU=y" "$CONFIG_FILE"; then
    echo "❌ 错误：部分冲突配置项清洗失败，终止编译！"
    exit 1
fi

# B. 一次性注入完全体 H29K 内核技术栈（含 SVE 禁用选项）
cat >> "$CONFIG_FILE" << 'EOF'

# === RK3528 核心与平台级别底座驱动 ===
CONFIG_ROCKCHIP_RK3528=y
CONFIG_SOC_RK3528=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_EPAN=y
CONFIG_ARM64_PAN=y
CONFIG_ARM64_VHE=y
CONFIG_ARM64_PA_BITS_40=y
CONFIG_ARM64_VA_BITS_48=y
CONFIG_ARM64_ASIMD=y
# CONFIG_ARM64_SVE is not set
CONFIG_CLK_RK3528_PLL=y
CONFIG_CLK_RK3528_ACLK_PERI=y
CONFIG_CLK_RK3528_HCLK_PERI=y
CONFIG_CLK_RK3528_PCLK_PERI=y
CONFIG_CLK_RK3528_ACLK_CPU=y
CONFIG_ROCKCHIP_RK3528_PMU=y
CONFIG_ROCKCHIP_SECURE_BOOT=y
CONFIG_ROCKCHIP_TRUSTED_FOUNDATION=y
CONFIG_ROCKCHIP_USB3PHY=y
CONFIG_ROCKCHIP_EMMC=y
CONFIG_ROCKCHIP_CLK_RK3528=y

# --- PWM 硬件控制器与 GPIO 设备树基础 ---
CONFIG_PWM=y
CONFIG_PWM_SYSFS=y
CONFIG_PWM_ROCKCHIP=y
CONFIG_OF_GPIO=y

# --- DRM/KMS 专用背光管理（取代 fbdev emulation）---
# CONFIG_DRM_FBDEV_EMULATION is not set
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_KMS_CMA_HELPER=y
CONFIG_DRM_SIMPLE_BRIDGE=y

# --- 现代 DRM 显示架构与 ST7789V 屏幕驱动 ---
CONFIG_DRM_ROCKCHIP_VOP2=y
CONFIG_ROCKCHIP_DRM_VOP2=y
CONFIG_ROCKCHIP_VOP2_KMS=y
CONFIG_DRM_PANEL_SIMPLE=y
CONFIG_DRM_PANEL_ST7789V=y
CONFIG_DRM_PANEL_ST7789V_V2=y
# 💡 核心修复：强行开启 DRM 对传统 Framebuffer 的完美模拟，确保应用层 fbv 工具能正常打开 /dev/fb0
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_FBDEV_OVERALLOC=100
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_BACKLIGHT_PWM=y

# --- 触控 FT6236 驱动支持 ---
CONFIG_INPUT=y
CONFIG_INPUT_MISC=y
CONFIG_INPUT_POLLDEV=y
CONFIG_TOUCHSCREEN_FT6236=y

# --- 高速总线接口外设底层协议栈 ---
CONFIG_SPI=y
CONFIG_SPI_MASTER=y
CONFIG_SPI_ROCKCHIP_SPI=y
CONFIG_REGULATOR=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y
CONFIG_USB_DWC3=y
CONFIG_USB_DWC3_HOST=y
CONFIG_USB_DWC3_GADGET=y
CONFIG_USB_DWC3_ROCKCHIP=y
CONFIG_USB_DWC3_ROCKCHIP_PHY_V2=y
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_PLTFM=y
CONFIG_MMC_SDHCI_ROCKCHIP=y
CONFIG_MMC_SDHCI_OF_ROCKCHIP_V2=y

# --- 硬件级加密引擎安全加速 (Crypto) ---
CONFIG_CRYPTO_DEV_ROCKCHIP=y
CONFIG_CRYPTO_DEV_ROCKCHIP_AES=y
CONFIG_CRYPTO_DEV_ROCKCHIP_SHA=y
CONFIG_CRYPTO_DEV_ROCKCHIP_TRNG=y

# --- 视频硬解 VPU 核心媒体框架 ---
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CONTROLLER=y
CONFIG_VIDEO_DEV=y
CONFIG_VIDEO_ROCKCHIP_VPU=y
CONFIG_VIDEO_ROCKCHIP_VPU_DEC=y
CONFIG_VIDEO_ROCKCHIP_VPU_ENC=y

# --- 开辟 320MB 连续物理内存（CMA），彻底喂饱硬解和高速屏幕刷新 ---
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_CMA_SIZE_MBYTES=320

# --- 网络高并发 TCP BBR + FQ 底层内建 ---
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
CONFIG_DEFAULT_QDISC="fq"

# --- 必须关闭的无用/冲突功能 ---
# CONFIG_ROCKCHIP_RGA is not set
# CONFIG_ROCKCHIP_IOMMU is not set
# CONFIG_ROCKCHIP_DW_HDMI is not set
# CONFIG_PCIE_ROCKCHIP_HOST is not set
# CONFIG_SND is not set
# CONFIG_SND_SOC is not set
# CONFIG_BT is not set

# === END H29K CONFIGURATION ===
EOF
echo "✅ 已向 $CONFIG_FILE 安全注入 H29K 完全体内核配置技术栈"

# C. 对全局通用内核配置（generic/config-6.12）进行先清洗再修正，防止重复定义
GENERIC_CONFIG="target/linux/generic/config-6.12"
if [ -f "$GENERIC_CONFIG" ]; then
    sed -i '/CONFIG_ARM64_SVE/d' "$GENERIC_CONFIG"
    sed -i '/CONFIG_ARM64_ASIMD/d' "$GENERIC_CONFIG"
    echo "# CONFIG_ARM64_SVE is not set" >> "$GENERIC_CONFIG"
    echo "CONFIG_ARM64_ASIMD=y" >> "$GENERIC_CONFIG"
    echo "✅ 已完成对全局通用内核配置 generic/config-6.12 的防御性修正"
fi

# === 6. 写入完整独立编译 Override 规则 ===
OVERRIDE_FILE="/workdir/openwrt/.config.override"
mkdir -p "$(dirname "$OVERRIDE_FILE")"
cat > "$OVERRIDE_FILE" << 'EOF'
# RK3528 H29K OVERRIDE — GENERATED BY diy-part1.sh
# CONFIG_TARGET_MULTI_ARCH is not set
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
# CONFIG_ARM64_EPHEMERAL_PAGE_TABLES is not set
# CONFIG_PACKAGE_u-boot-rk3528 is not set
# CONFIG_PACKAGE_u-boot-rk3528-tpl is not set
# CONFIG_TRUSTED_FIRMWARE_A is not set
EOF
echo "✅ H29K 独立单机型 Override 编译快照已生成"

# === 7. 适配 H29K 专用打包与引导流水线 ===
# 覆盖并验证 rockchip 镜像生成 Makefile
IMAGE_MAKEFILE="target/linux/rockchip/image/Makefile"
wget -q -O "$IMAGE_MAKEFILE" https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/Makefile

if grep -q "智能识别 Binman 合体固件或传统拆分固件" "$IMAGE_MAKEFILE"; then
    echo -e "\033[32m✅ 验证成功：Makefile 打包规则完全符合 H29K 要求！\033[0m"
else
    echo -e "\033[31m❌ 验证失败：Makefile 下载损坏或不匹配！\033[0m"
    exit 1
fi

# 下载其它打包依赖脚本与专属 U-Boot DTS
wget -q https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/mmc.bootscript -O target/linux/rockchip/image/mmc.bootscript
mkdir -p scripts && wget -q https://raw.githubusercontent.com/I-agree/H29K/main/files/scripts/gen_image_generic.sh -O scripts/gen_image_generic.sh

DTS_DEST_DIR="package/boot/uboot-rockchip/dts"
mkdir -p "$DTS_DEST_DIR"
wget -q -O "$DTS_DEST_DIR/rk3528-hinlink-h29k.dts" "https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts"

if [ -s "$DTS_DEST_DIR/rk3528-hinlink-h29k.dts" ]; then
    echo "✅ 成功：U-Boot 专属编译 DTS 已顺利就位"
else
    echo "❌ 失败：U-Boot DTS 下载失败"
    exit 1
fi

echo "🚀 [diy-part1.sh] 针对 H29K 机型的全栈预处理圆满完成！"
