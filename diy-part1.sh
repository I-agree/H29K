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
rm -f target/linux/generic/hack-6.12/920-device_tree_cmdline.patch || true
rm -f target/linux/bcm27xx/patches-6.12/950-0076-OF-DT-Overlay-configfs-interface.patch || true
rm -f target/linux/ipq806x/patches-6.12/901-02-ARM-decompressor-add-option-to-ignore-MEM-ATAGs.patch || true
rm -f target/linux/mpc85xx/patches-6.12/102-powerpc-add-cmdline-override.patch || true
rm -f package/boot/uboot-mediatek/patches/280-image-fdt-save-name-of-FIT-configuration-in-chosen-node.patch || true
rm -f target/linux/qualcommax/patches-6.12/0911-arm64-cmdline-replacement.patch || true
rm -f target/linux/ipq806x/patches-6.12/902-ARM-decompressor-support-for-ATAGs-rootblock-parsing.patch || true
rm -f target/linux/ipq806x/patches-6.12/900-arm-add-cmdline-override.patch || true
rm -f target/linux/mvebu/patches-6.12/300-mvebu-Mangle-bootloader-s-kernel-arguments.patch || true
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

# === 5. 🎯 针对 H29K 进行主线内核配置（config-6.12）的强力清洗与合并注入 ===
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# A. 彻底抹除原文件中可能冲突的底层选项
sed -i '/CONFIG_EMAC_ROCKCHIP/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_PA_BITS/d' "$CONFIG_FILE"
sed -i '/CONFIG_CMA_SIZE_MBYTES/d' "$CONFIG_FILE"
sed -i '/CONFIG_CRYPTO_DEV_ROCKCHIP/d' "$CONFIG_FILE"

# B. 一次性注入完全适配主线 Linux 6.12 的 H29K 内核技术栈
cat >> "$CONFIG_FILE" << 'EOF'

# === RK3528 主线核心与平台级别底座驱动（对齐 Linux 6.12）===
CONFIG_ARCH_ROCKCHIP=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_VA_BITS_48=y
CONFIG_COMMON_CLK_ROCKCHIP=y
CONFIG_ROCKCHIP_PMDOMAINS=y
CONFIG_PWM_ROCKCHIP=y
CONFIG_OF_GPIO=y

# --- 主线标准显示架构与 ST7789V 屏幕驱动对齐 ---
# 你的 DTS 声明的是 "sitronix,st7789v"，主线对应的 Kconfig 符号正是下面这个
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_PANEL_SITRONIX_ST7789V=y
CONFIG_BACKLIGHT_PWM=y

# --- 主线标准高速总线与存储协议栈（确保 eMMC/SD卡 正常 boot）---
CONFIG_SPI_ROCKCHIP=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y
CONFIG_MMC_SDHCI_OF_ROCKCHIP=y
CONFIG_USB_DWC3_ROCKCHIP=y

# --- 主线标准硬件级加密引擎安全加速 ---
CONFIG_CRYPTO_DEV_ROCKCHIP=y

# --- CMA 连续物理内存调优（推荐 128MB-256MB，平衡主线小屏幕显示与 Docker 运行空间） ---
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_CMA_SIZE_MBYTES=128

# --- 网络高并发 TCP BBR + FQ 底层内建 ---
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_QDISC="fq"

# --- 关闭主线无需或可能冲突的功能 ---
# CONFIG_SND is not set
# CONFIG_BT is not set
EOF
echo "✅ 已向 $CONFIG_FILE 安全注入适配主线 Linux 6.12 的 H29K 内核配置技术栈"

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
