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

# ====== BEGIN: Predefine config via .config.override ======
echo "🔧 Writing .config.override for u-boot-rk3528..."

cat > /workdir/openwrt/.config.override << 'EOF'
# RK3528 Bootloader Stack — Auto-enabled by diy-part1.sh
CONFIG_TARGET_MULTI_ARCH=n
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_SUBTARGET_generic=y
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

# ==============================================
# 清理 Rockchip 旧网卡驱动（RK3528/H29K 不需要）
# ==============================================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 删除 CONFIG_EMAC_ROCKCHIP=y
sed -i '/CONFIG_EMAC_ROCKCHIP=y/d' "$CONFIG_FILE"

# 删除 CONFIG_ARC_EMAC_CORE=y
sed -i '/CONFIG_ARC_EMAC_CORE=y/d' "$CONFIG_FILE"

echo "✅ 已清理无用网卡配置：CONFIG_EMAC_ROCKCHIP 和 CONFIG_ARC_EMAC_CORE 已删除"

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
# 📌 设备定义：HINLINK H29K（RK3528）
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
    luci-theme-argon imagemagick imagemagick-jpeg imagemagick-png imagemagick-gif curl \
    luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn \
    luci-app-bbr luci-i18n-bbr-zh-cn luci-mod-admin-full \
    luci-app-irqbalance luci-i18n-irqbalance-zh-cn \
    dnscrypt-proxy luci-app-dnscrypt-proxy luci-i18n-dnscrypt-proxy-zh-cn \
    irqbalance luci-app-irqbalance luci-i18n-irqbalance-zh-cn
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

# ==============================================
# 为 Hinlink H29K 添加内核驱动配置
# ==============================================
# 内容覆盖写入 config-6.12（注意：使用 > 而非 >>，确保干净替换）
cat > target/linux/rockchip/armv8/config-6.12 << 'EOF'
# === Hinlink H29K Hardware Mandatory Built-in Drivers (RK3528, Kernel 6.12) ===
CONFIG_ROCKCHIP_ERRATUM_3568002=y
CONFIG_ARM64_VA_BITS_39=y
CONFIG_ARM64_PAN=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_MODULE_PLTS=y
CONFIG_ARM64_VHE=y
CONFIG_ARM64_PSEUDO_NMI=y
CONFIG_CPU_LITTLE_ENDIAN=y
CONFIG_ARM64_PA_BITS_48=y
CONFIG_NR_CPUS=512
CONFIG_SCHED_MC=n
CONFIG_SCHED_CLUSTER=n
CONFIG_SCHED_SMT=n

# TCP BBR Support (required for DEFAULT_TCP_CONG="bbr")
# 注意：6.12.x 内核要求 CONFIG_DEFAULT_TCP_CONG 必须为小写字符串，带双引号
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_DEFAULT_TCP_CONG="cubic"

# === 队列调度（FQ + FQ_CODEL） ===
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
CONFIG_DEFAULT_QDISC="fq_codel"

# --- ST7789V LCD Panel (172x320, MIPI-DSI) ---
# 【关键修复】RK3528 使用 DRM 框架，非传统 FB；必须启用 DRM 基础
CONFIG_DRM=y
CONFIG_DRM_ROCKCHIP=y
CONFIG_DRM_ROCKCHIP_DW_MIPI_DSI=y
CONFIG_ST7789V=y
CONFIG_DRM_PANEL_SIMPLE=y

# --- FT6236 Touch Controller (I2C) ---
# 【关键修复】FT6236 依赖 I2C 总线
CONFIG_I2C=y
CONFIG_I2C_CHARDEV=y
CONFIG_I2C_ROCKCHIP=y
CONFIG_INPUT=y
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_TOUCHSCREEN=y
CONFIG_TOUCHSCREEN_FT6236=y

# --- USB 5G Modem Support (MBIM + NCM + RNDIS foundation) ---
CONFIG_USB=y
CONFIG_USB_DEVICEFS=y
CONFIG_USB_COMMON=y
CONFIG_USB_ARCH_HAS_HCD=y
CONFIG_USB_SUPPORT=y
CONFIG_USB_PHY=y
CONFIG_USB_ROCKCHIP_PHY=y
CONFIG_USB_STORAGE=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_OPTION=y
CONFIG_USB_NET=y  # 【关键修复】CDC_MBIM / CDC_NCM 的强制依赖
CONFIG_USB_NET_DRIVERS=y
CONFIG_USB_NET_RNDIS=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_USB_NET_CDC_MBIM=y
CONFIG_USB_NET_CDC_NCM=y
CONFIG_USB_NET_CDC_EEM=y

# --- Power & Regulator for Modem & SoC ---
CONFIG_POWER_SUPPLY=y
CONFIG_POWER_RESET=y
CONFIG_POWER_RESET_SYSCON_POWEROFF=y
CONFIG_POWER_RESET_SYSCON_RESTART=y
CONFIG_REGULATOR=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y
CONFIG_MFD_RK808=y
CONFIG_REGULATOR_RK808=y
CONFIG_SENSORS_RK808=y
CONFIG_SENSORS_RK808_ADC=y

# H29K RK3528 USB Support
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_QUALCOMM=y
CONFIG_USB_SERIAL_SIERRAWIRELESS=y
CONFIG_USB_SERIAL_WWAN=y

# CDC MBIM/RNDIS
CONFIG_USB_NET_CDCETHER=y
CONFIG_USB_NET_QMI_WWAN=y  # 【新增】5G 模块通用驱动（移远/华为/高通必备）

# 自动关闭所有 ARM64 errata，适合 RK3528 (Cortex-A53)
CONFIG_AMPERE_ERRATUM_AC03_CPU_38=n
CONFIG_ARM64_ERRATUM_826319=n
CONFIG_ARM64_ERRATUM_827319=n
CONFIG_ARM64_ERRATUM_824069=n
CONFIG_ARM64_ERRATUM_819472=n
CONFIG_ARM64_ERRATUM_843419=n
CONFIG_ARM64_ERRATUM_832075=n
CONFIG_ARM64_ERRATUM_1024718=n
CONFIG_ARM64_ERRATUM_1165522=n
CONFIG_ARM64_ERRATUM_1319367=n
CONFIG_ARM64_ERRATUM_1530923=n
CONFIG_ARM64_ERRATUM_2441007=n
CONFIG_ARM64_ERRATUM_1286807=n
CONFIG_ARM64_ERRATUM_1463225=n
CONFIG_ARM64_ERRATUM_1542419=n
CONFIG_ARM64_ERRATUM_1508412=n
CONFIG_ARM64_ERRATUM_2051678=n
CONFIG_ARM64_ERRATUM_2077057=n
CONFIG_ARM64_ERRATUM_2658417=n
CONFIG_ARM64_ERRATUM_2054223=n
CONFIG_ARM64_ERRATUM_2067961=n
CONFIG_ARM64_ERRATUM_2441009=n
CONFIG_ARM64_ERRATUM_2645198=n
CONFIG_ARM64_ERRATUM_2966298=n
CONFIG_ARM64_ERRATUM_3117295=n
CONFIG_ARM64_ERRATUM_3194386=n
CONFIG_CAVIUM_ERRATUM_22375=n
CONFIG_CAVIUM_ERRATUM_23154=n
CONFIG_CAVIUM_ERRATUM_27456=n
CONFIG_CAVIUM_ERRATUM_30115=n
CONFIG_CAVIUM_TX2_ERRATUM_219=n
CONFIG_FUJITSU_ERRATUM_010001=n
CONFIG_HISILICON_ERRATUM_161600802=n
CONFIG_HISILICON_ERRATUM_162100801=n
CONFIG_QCOM_FALKOR_ERRATUM_1003=n
CONFIG_QCOM_FALKOR_ERRATUM_1009=n
CONFIG_QCOM_QDF2400_ERRATUM_0065=n
CONFIG_QCOM_FALKOR_ERRATUM_E1041=n
CONFIG_NVIDIA_CARMEL_CNP_ERRATUM=n
EOF
