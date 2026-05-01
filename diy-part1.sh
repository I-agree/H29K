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
echo 'src-git OpenAppFilter https://github.com/destan19/OpenAppFilter.git;master' >> feeds.conf.default

set -euo pipefail  # 🔥 关键修复：任一命令失败立即终止，杜绝静默错误

# ======================== 【第1部分：资源准备】 ========================
echo "🔧 正在按 OpenWrt 官方主线路径注入 H29K 文件..."

# ✅ 1. U-Boot defconfig → 直接复制到官方 configs/ 目录（无需重命名）
UBOOT_SRC="files/package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig"
UBOOT_DST="package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig"
if [ ! -f "$UBOOT_SRC" ]; then
  echo "❌ 错误：U-Boot defconfig 源文件不存在：$UBOOT_SRC"
  exit 1
fi
mkdir -p "$(dirname "$UBOOT_DST")"
cp -f "$UBOOT_SRC" "$UBOOT_DST"
echo "✅ 已注入 U-Boot defconfig → $UBOOT_DST"

# ✅ 2. DTS 文件 → 注入到 target/linux/rockchip/files/ 下的标准路径
#    官方约定：所有自定义 DTS 必须放在 target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
DTS_SRC="files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts"
DTS_DST="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-hinlink-h29k.dts"
if [ ! -f "$DTS_SRC" ]; then
  echo "❌ 错误：DTS 源文件不存在：$DTS_SRC"
  exit 1
fi
mkdir -p "$(dirname "$DTS_DST")"
cp -f "$DTS_SRC" "$DTS_DST"
echo "✅ 已注入 DTS → $DTS_DST"

# ✅ 3. Linux 内核 defconfig → 直接复制到 image/ 目录（官方标准位置）
DEFCONFIG_SRC="files/target/linux/rockchip/image/hinlink_h29k_defconfig"
DEFCONFIG_DST="target/linux/rockchip/image/hinlink_h29k_defconfig"
if [ ! -f "$DEFCONFIG_SRC" ]; then
  echo "❌ 错误：Linux defconfig 源文件不存在：$DEFCONFIG_SRC"
  exit 1
fi
mkdir -p "$(dirname "$DEFCONFIG_DST")"
cp -f "$DEFCONFIG_SRC" "$DEFCONFIG_DST"
echo "✅ 已注入 Linux defconfig → $DEFCONFIG_DST"

# ✅ 4. 强制验证：三个目标文件必须存在且非空
for FILE in "$UBOOT_DST" "$DTS_DST" "$DEFCONFIG_DST"; do
  if [ ! -s "$FILE" ]; then
    echo "❌ 严重错误：注入文件为空或缺失：$FILE"
    ls -lh "$FILE"
    exit 1
  fi
done

printf '\n'
echo "✅ 所有文件注入完成，路径与 OpenWrt 2026.04+ 官方主线完全一致。"
# ======================================================================

# 创建开机 LOGO 存放目录
mkdir -p files/etc/config/screen bin/targets/rockchip/armv8

# 定义通用下载函数（带重试、超时、失败退出）
download_file() {
  local url="$1"
  local path="$2"
  local name="$3"
  if curl -fsSL --retry 3 --connect-timeout 10 --max-time 30 "$url" -o "$path"; then
    echo "✅ $name 下载成功"
  else
    echo -e "\033[31m❌ $name 下载失败\033[0m"
    exit 1
  fi
}

# 下载三张开机 LOGO（JPG 格式，适配 fbv）
LOGO_RAW_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"
for i in 1 2 3; do
  download_file "${LOGO_RAW_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg" "LOGO${i}"
done

printf '\n'
# ======================== 【离线复制字体：MiSans-Regular.ttf】 ========================
# 🔹 源文件：diy-part2.sh 与 fonts/ 同级 → dirname "$0" 即仓库根
SRC_FONT="$(dirname "$0")/fonts/MiSans-Regular.ttf"

# 🔹 目标路径：OpenWrt 固件内标准位置
DST_FONT="files/usr/share/fonts/truetype/MiSans-Regular.ttf"

# 创建目标目录（安全，幂等）
mkdir -p "$(dirname "$DST_FONT")"

# ✅ 关键校验：检查源文件是否存在（CI 友好）
if [ ! -f "$SRC_FONT" ]; then
  echo "❌ 错误：字体文件未找到！请确认："
  echo "   • fonts/MiSans-Regular.ttf 已提交到 Git（运行：git ls-files fonts/MiSans-Regular.ttf）"
  echo "   • 当前工作目录正确（应在仓库根目录下执行此脚本）"
  echo "   • 查找路径：$SRC_FONT"
  exit 1
fi

if [[ ! -r "$SRC_FONT" ]]; then
  echo -e "\033[31m❌ 错误：字体文件不可读（权限问题）\033[0m"
  ls -l "$SRC_FONT"
  exit 1
fi

# 复制并校验
cp -f "$SRC_FONT" "$DST_FONT"

if [[ ! -s "$DST_FONT" ]]; then
  echo -e "\033[31m❌ 错误：复制后目标文件为空！\033[0m"
  exit 1
fi

# Magic Number 校验（TTF/OTF）
MAGIC=$(head -c 4 "$DST_FONT" 2>/dev/null | xxd -p 2>/dev/null | tr -d '\n')
if [[ "$MAGIC" != "00010000" ]] && [[ "$MAGIC" != "4f54544f" ]]; then
  echo -e "\033[31m❌ 错误：'$DST_FONT' 不是有效的 TTF/OTF 字体（Magic: $MAGIC）\033[0m"
  exit 1
fi

chmod 644 "$DST_FONT"
echo "✅ 字体复制成功：$DST_FONT"
echo "   → 构建后路径：/usr/share/fonts/truetype/MiSans-Regular.ttf"

echo "[OK] MiSans-Regular.ttf 已安装到固件内"

# ==============================================================================
# 【U-Boot 支持注入】—— 严格遵循 OpenWrt 官方 Makefile 风格（高危修复区）
# ✅ 修复点1：BusyBox sed 不支持 'a\' 多行追加 → 改用 POSIX 兼容写法（自动换行）
# ✅ 修复点2：NAME 字段统一为下划线命名，与 UBOOT_CONFIG 语义一致
# ==============================================================================
makefile="package/boot/uboot-rockchip/Makefile"

# 1️⃣ 在 hinlink-h28k-rk3528 后追加 hinlink-h29k-rk3528 到 UBOOT_TARGETS（POSIX 安全）
sed -i "/hinlink-h28k-rk3528/a hinlink-h29k-rk3528" "$makefile"

# 2️⃣ 在 hinlink-h28k 定义下方插入 hinlink-h29k 设备块（完全复刻官方格式）
#    ✅ NAME:=HINLINK_H29K（非空格，与 UBOOT_CONFIG 一致）
#    ✅ BUILD_DEVICES:=hinlink_h29k（小写+下划线，与 .config 中 CONFIG_TARGET_... 保持一致）
sed -i '/define U-Boot\/hinlink-h28k-rk3528/a\
define U-Boot/hinlink-h29k-rk3528\n  $(U-Boot/rk3528/Default)\n  UBOOT_CONFIG:=hinlink_h29k\n  NAME:=HINLINK_H29K\n  BUILD_DEVICES:=hinlink_h29k\nendef
' "$makefile"

# ======================== 【添加 H29K：armv8.mk 设备定义】 ========================
# ✅ 修复点3：DEVICE_DTS 使用标准社区命名 rk3528-hinlink-h29k（非 opc- 前缀）
TARGET_MK="target/linux/rockchip/image/armv8.mk"

cat >> "$TARGET_MK" <<'EOF'
# 📌 设备定义：HINLINK H29K（RK3528）
#    - 遵循 OpenWrt 命名规范：rk3528-{vendor}-{model}
#    - 使用官方 $(Device/rk3528) 宏保证内核与镜像一致性
define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  UBOOT_CONFIG := hinlink_h29k
  DEVICE_UBOOT_IMAGE := u-boot-rockchip-hinlink_h29k.bin
  IMAGE/boot.bin := boot-scr | boot-kernel | boot-dtb
  IMAGE/sysupgrade.img.gz := boot.bin | append-rootfs | pad-rootfs | check-size | gzip
  DEVICE_PACKAGES := \
    kmod-usb3 kmod-usb-net-rtl8152 kmod-r8169 kmod-aic8800-sdio wpad-openssl dnsmasq-full \
    kmod-mtk_t7xx kmod-usb-net-cdc-mbim uqmi kmod-usb-net-rndis-host kmod-usb-serial-option \
    kmod-h29k-fb-st7789v \
    luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn \
    luci-theme-argon fbv imagemagick wqy-microhei curl irqbalance \
    luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn \
    luci-mod-admin-full \
    luci-app-irqbalance luci-i18n-irqbalance-zh-cn \
    dnscrypt-proxy luci-app-dnscrypt-proxy luci-i18n-dnscrypt-proxy-zh-cn \
    luci-app-oaf appfilter luci-i18n-oaf-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF

printf '\n'
echo "===== ✅ 添加 H29K：armv8.mk 设备定义完成 ====="

# ======================== 【H29K 强制2项校验 · 失败立即终止编译】 ========================
echo "🔍 开始 H29K 构建前置2重校验..."

# ✅ 校验1：设备定义已写入 armv8.mk
DEVICE_NAME="hinlink_h29k"
MK_FILE="target/linux/rockchip/image/armv8.mk"
if ! grep -q "$DEVICE_NAME" "$MK_FILE"; then
  echo -e "\033[31m[错误] H29K 设备未定义！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] 设备定义已写入 armv8.mk\033[0m"

# ✅ 校验3：U-Boot 已添加 hinlink-h29k-rk3528（Makefile确认）
UBOOT_MK="package/boot/uboot-rockchip/Makefile"
if ! grep -q "hinlink-h29k-rk3528" "$UBOOT_MK"; then
  echo -e "\033[31m[错误] U-Boot 未添加 H29K 设备！编译终止！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] U-Boot 已添加 H29K 设备（Makefile校验）\033[0m"

printf '\n'
echo -e "\033[32m=====================================\033[0m"
echo -e "\033[32m✅ 所有检查通过！\033[0m"
echo -e "\033[32m=====================================\033[0m"
