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

#!/bin/bash
set -e

echo "🔧 正在配置 BBR 支持..."

# ===== 1. 定义目标配置文件 =====
ROCKCHIP_CONFIG="./target/linux/rockchip/armv8/config-6.12"
GENERIC_CONFIG="./target/linux/generic/config-6.12"
DOT_CONFIG="./.config"

# ===== 2. 所需的完整 BBR 配置项（含依赖）=====
BBR_REQUIRED=(
  "CONFIG_TCP_CONG_ADVANCED=y"     # ← 关键！父开关，必须开启
  "CONFIG_TCP_CONG_BBR=y"
  "CONFIG_TCP_CONG_CUBIC=y"        # 保留兼容，默认可切
  "CONFIG_NET_SCH_FQ_CODEL=y"
  "CONFIG_NET_SCHED=y"
  "CONFIG_INET=y"                  # IPv4 基础
  "CONFIG_IP_ADVANCED_ROUTER=y"    # FQ_CODEL & BBR 依赖
  "CONFIG_NETFILTER=y"             # 推荐启用
  "CONFIG_DEFAULT_TCP_CONG=\"bbr\""
)

# ===== 3. 安全写入：先删后写，避免重复/冲突 =====
for cfg in "${BBR_REQUIRED[@]}"; do
  # 提取 CONFIG_XXX 部分（如 CONFIG_TCP_CONG_BBR）
  key=$(echo "$cfg" | sed 's/=.*//')
  
  # 删除所有以该 KEY 开头的行（兼容 =y/m/n/is not set）
  sed -i "/^$key[ =]/d" "$ROCKCHIP_CONFIG"
  sed -i "/^$key[ =]/d" "$GENERIC_CONFIG"
  sed -i "/^$key[ =]/d" "$DOT_CONFIG"
  
  # 追加到 rockchip config（推荐放这里，设备专属）
  echo "$cfg" >> "$ROCKCHIP_CONFIG"
  echo "✅ 已设置：$cfg"
done

# ===== 4. 强制更新 .config（避免被 feeds 或 menuconfig 覆盖）=====
# 如果 .config 存在且未设置 DEFAULT_TCP_CONG，则补上
if [ -f "$DOT_CONFIG" ]; then
  if ! grep -q '^CONFIG_DEFAULT_TCP_CONG=' "$DOT_CONFIG"; then
    echo 'CONFIG_DEFAULT_TCP_CONG="bbr"' >> "$DOT_CONFIG"
  fi
  # 确保 TCP_CONG_ADVANCED=y（否则 BBR 不可用）
  if ! grep -q '^CONFIG_TCP_CONG_ADVANCED=y' "$DOT_CONFIG"; then
    sed -i '/^CONFIG_TCP_CONG_ADVANCED=/d' "$DOT_CONFIG"
    echo 'CONFIG_TCP_CONG_ADVANCED=y' >> "$DOT_CONFIG"
  fi
fi

# ===== 5. 验证写入结果 =====
echo "🔍 验证配置："
grep -E "^(CONFIG_TCP_CONG_ADVANCED|CONFIG_TCP_CONG_BBR|CONFIG_DEFAULT_TCP_CONG)" "$ROCKCHIP_CONFIG" || true

echo "✅ BBR 配置已安全写入，准备编译..."


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

# ==============================================
# 清理 Rockchip 旧网卡驱动（RK3528/H29K 不需要）
# ==============================================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 删除 CONFIG_EMAC_ROCKCHIP=y
sed -i '/CONFIG_EMAC_ROCKCHIP=y/d' "$CONFIG_FILE"

# 删除 CONFIG_ARC_EMAC_CORE=y
sed -i '/CONFIG_ARC_EMAC_CORE=y/d' "$CONFIG_FILE"

echo "✅ 已清理无用网卡配置：CONFIG_EMAC_ROCKCHIP 和 CONFIG_ARC_EMAC_CORE 已删除"

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
# 为 Hinlink H29K 添加内核驱动配置
# ==============================================
cat >> target/linux/rockchip/armv8/config-6.12 << 'EOF'

# === Hinlink H29K Hardware Mandatory Built-in Drivers (RK3528, Kernel 6.12) ===
CONFIG_R8168=y

# --- ST7789V LCD Panel (172x320, SPI) ---
CONFIG_FB=y
CONFIG_FB_CFB_FILLRECT=y
CONFIG_FB_CFB_COPYAREA=y
CONFIG_FB_CFB_IMAGEBLIT=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_IMAGEBLIT=y
CONFIG_FB_FOREIGN_ENDIAN=y
CONFIG_FB_ROCKCHIP=y
CONFIG_FB_ROCKCHIP_LCDC=y
CONFIG_FB_ST7789V=y

# --- FT6236 Touch Controller (I2C) ---
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
CONFIG_USB_NET_DRIVERS=y
CONFIG_USB_NET_RNDIS=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_USB_NET_CDC_MBIM=y
CONFIG_USB_NET_CDC_NCM=y
CONFIG_USB_NET_CDC_EEM=y

# --- Power & Regulator for Modem ---
CONFIG_POWER_SUPPLY=y
CONFIG_POWER_RESET=y
CONFIG_POWER_RESET_SYSCON_POWEROFF=y
CONFIG_POWER_RESET_SYSCON_RESTART=y
CONFIG_REGULATOR=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y
CONFIG_REGULATOR_RK808=y

# H29K RK3528 USB Support
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_QUALCOMM=y
CONFIG_USB_SERIAL_SIERRAWIRELESS=y
CONFIG_USB_SERIAL_WWAN=y

# CDC MBIM/RNDIS
CONFIG_USB_NET=y
CONFIG_USB_NET_CDCETHER=y

# ST7789V & FT6236 (built-in, not module)
CONFIG_FB_TFT=y
CONFIG_FB_TFT_ST7789V=y
EOF
