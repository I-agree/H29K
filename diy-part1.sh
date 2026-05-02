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
define Device/hinlink_h29k
  SOC := rk3528
  SUBTARGET := armv8
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  UBOOT_CONFIG := hinlink_h29k
  KERNEL_LOADADDR := 0x00280000
  KERNEL_ENTRYADDR := 0x00280000
  DEVICE_UBOOT_IMAGE := u-boot-rockchip-hinlink_h29k.bin
  DEVICE_COMPAT_VERSION := 1
  SUPPORTED_DEVICES := hinlink_h29k
  IMAGE/boot.bin := boot-scr | boot-kernel | boot-dtb
  IMAGE/sysupgrade.img.gz := boot.bin | append-rootfs | pad-rootfs | check-size | gzip
  DEVICE_PACKAGES := \
    kmod-usb3 kmod-usb-net-rtl8152 kmod-aic8800-sdio dnsmasq-full \
    kmod-usb-net-cdc-mbim uqmi qmi-utils kmod-usb-serial-option kmod-usb-net-rndis-host \
    luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn \
    luci-theme-argon imagemagick wqy-microhei curl irqbalance \
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

# ======================== 【内核屏幕配置】 ========================
# 清理旧内核选项（避免冲突），注入 H29K 屏幕专属配置
CONF_FILES=$(find target/linux/rockchip/armv8 -name "config-*")
for CONF in $CONF_FILES; do
  # 移除可能冲突的 staging/fb/tcpc 配置（确保干净）
  sed -i '/CONFIG_STAGING/d; /CONFIG_FB_TFT/d; /CONFIG_TCP_CONG/d; /CONFIG_DEFAULT_TCP_CONG/d' "$CONF"
  # 注入 H29K 必需内核模屏幕相关（ST7789V 屏幕），CONFIG_OF_GPIO=y源代码已经有了。
  cat >> "$CONF" <<'EOF'
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_FBDEV_OVERALLOC=100
CONFIG_DRM_ROCKCHIP=y
CONFIG_DRM_ROCKCHIP_DSI=y
CONFIG_DRM_ROCKCHIP_VOP2=y
CONFIG_FB_ST7789V=y
CONFIG_GPIO_RK3528=y
CONFIG_GPIOLIB=y
CONFIG_BACKLIGHT_RK806=y
CONFIG_BACKLIGHT_CLASS_DEVICE=y
EOF
done

printf '\n'
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

# ✅ 校验2：U-Boot 已添加 hinlink-h29k-rk3528（Makefile确认）
UBOOT_MK="package/boot/uboot-rockchip/Makefile"
if ! grep -q "hinlink-h29k-rk3528" "$UBOOT_MK"; then
  echo -e "\033[31m[错误] U-Boot 未添加 H29K 设备！编译终止！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] U-Boot 已添加 H29K 设备（Makefile校验）\033[0m"

# ==================================================================
# OpenWrt diy-part1.sh 兼容的屏幕驱动检查脚本
# 功能：检查 target/linux/rockchip/armv8/config-* 中是否存在 CONFIG_FB_ST7789V=y
# ✅ 支持内核版本动态识别（自动匹配 config-6.12 / config-6.13 / config-6.14...）
# ✅ 严格区分 Rockchip DRM 版本（CONFIG_FB_ST7789V=y）与 FBTFT 版本（CONFIG_FB_TFT_ST7789V=y）
# ✅ 在 diy-part1.sh 中直接 source 即可，失败时 exit 1 触发编译中断
# ✅ 输出带颜色提示，兼容 BusyBox ash / bash
# ==================================================================

# --- 颜色定义（兼容无 color 支持环境）---
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# --- 函数：查找 rockchip/armv8 配置目录 ---
find_rockchip_config_dir() {
    local topdir="$1"
    local path="$topdir/target/linux/rockchip/armv8"
    if [ -d "$path" ]; then
        echo "$path"
        return 0
    fi
    echo "" >&2
    return 1
}

# --- 函数：动态查找最新 config-* 文件（语义化版本排序）---
find_latest_config() {
    local config_dir="$1"
    local candidates=()
    local best=""

    # 收集所有 config-* 文件
    while IFS= read -r -d '' f; do
        candidates+=("$f")
    done < <(find "$config_dir" -maxdepth 1 -name 'config-*' -print0 2>/dev/null | sort -z)

    # 按版本号排序（如 config-6.12 < config-6.13），取最新
    for f in "${candidates[@]}"; do
        if [[ "$(basename "$f")" =~ ^config\-([0-9]+)\.([0-9]+)(\.([0-9]+))?$ ]]; then
            major="${BASH_REMATCH1}"
            minor="${BASH_REMATCH2}"
            patch="${BASH_REMATCH4:-0}"
            # 构造数值键用于比较：major*1000000 + minor*1000 + patch
            key=$((major * 1000000 + minor * 1000 + patch))
            if [[ -z "$best_key" ]] || [[ $key -gt $best_key ]]; then
                best_key=$key
                best="$f"
            fi
        fi
    done

    if [ -n "$best" ]; then
        echo "$best"
        return 0
    else
        # fallback：尝试 config-6.12
        local fallback="$config_dir/config-6.12"
        if [ -f "$fallback" ]; then
            echo "$fallback"
            return 0
        fi
        echo "" >&2
        return 1
    fi
}

# --- 函数：检查 CONFIG_FB_ST7789V=y 是否存在（Rockchip DRM 版本）---
check_fb_st7789v() {
    local config_file="$1"
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ 错误：配置文件不存在：$config_file${NC}" >&2
        return 1
    fi

    # 使用 grep -E 精确匹配行：以 CONFIG_FB_ST7789V= 开头，后跟 y 或 m（排除 _TFT_）
    # 注意：grep -q 不输出，但 $? 可判断是否匹配
    if grep -q "^CONFIG_FB_ST7789V=[ym]$" "$config_file"; then
        # 获取匹配行（用于显示）
        local line=$(grep "^CONFIG_FB_ST7789V=[ym]$" "$config_file" | head -n1)
        echo -e "${GREEN}✅ 成功：在 $(basename "$config_file") 中找到 '$line'${NC}"
        return 0
    elif grep -q "CONFIG_FB_TFT_ST7789V=" "$config_file"; then
        echo -e "${YELLOW}⚠️  注意：检测到 CONFIG_FB_TFT_ST7789V=...（FBTFT staging 驱动）${NC}" >&2
        echo -e "${YELLOW}   H29K 屏幕需使用 CONFIG_FB_ST7789V=y（Rockchip DRM 版本），请勿混淆！${NC}" >&2
        return 1
    else
        echo -e "${RED}❌ 错误：未在 $(basename "$config_file") 中找到 CONFIG_FB_ST7789V=y 或 =m${NC}" >&2
        echo -e "${RED}💡 修复建议：请编辑该文件，添加一行：CONFIG_FB_ST7789V=y${NC}" >&2
        return 1
    fi
}

# --- 主逻辑 ---
main() {
    echo "🔍 正在检查 Rockchip 屏幕驱动配置..."

    # 1. 确定 OpenWrt 根目录（优先 TOPDIR，否则 pwd 向上搜索）
    local topdir="${TOPDIR:-}"
    if [ -z "$topdir" ]; then
        # 向上搜索 Makefile（含 OpenWrt 字样）
        local d="$(pwd)"
        for _ in {1..4}; do
            if [ -f "$d/Makefile" ] && grep -q "OpenWrt" "$d/Makefile" 2>/dev/null; then
                topdir="$d"
                break
            fi
            d="$(dirname "$d")"
        done
    fi

    if [ -z "$topdir" ] || [ ! -d "$topdir" ]; then
        echo -e "${RED}❌ 错误：无法定位 OpenWrt 根目录。请确保在 OpenWrt 源码根目录下运行，或设置 TOPDIR 环境变量。${NC}" >&2
        exit 1
    fi

    # 2. 查找 rockchip/armv8 目录
    local config_dir
    config_dir=$(find_rockchip_config_dir "$topdir")
    if [ -z "$config_dir" ]; then
        echo -e "${RED}❌ 错误：未找到 target/linux/rockchip/armv8 目录。${NC}" >&2
        exit 1
    fi

    # 3. 查找最新 config-* 文件
    local config_file
    config_file=$(find_latest_config "$config_dir")
    if [ -z "$config_file" ]; then
        echo -e "${RED}❌ 错误：在 $config_dir 中未找到任何 config-* 文件，且 config-6.12 也不存在。${NC}" >&2
        exit 1
    fi

    # 4. 执行核心检查
    if check_fb_st7789v "$config_file"; then
        echo -e "${GREEN}🎉 屏幕代码修改成功：CONFIG_FB_ST7789V=y 已启用 → 编译继续...${NC}"
        return 0
    else
        echo -e "${RED}💥 编译中止：屏幕驱动配置缺失，终止构建流程。${NC}" >&2
        exit 1
    fi
}

# === 调用主函数（支持 source 和直接执行）===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

printf '\n'
echo -e "\033[32m=====================================\033[0m"
echo -e "\033[32m✅ 所有检查通过！\033[0m"
echo -e "\033[32m=====================================\033[0m"
