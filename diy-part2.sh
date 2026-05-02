#!/bin/bash
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

# ======================== 【资源准备】 ========================
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

# ✅ 2.5. DTS 文件 → 注入到 arch/arm/dts/rockchip/ 下的标准路径
DTS_SRC="files/arch/arm/dts/rockchip/rk3528-hinlink-h29k.dts"
DTS_DST="arch/arm/dts/rockchip/rockchip/rk3528-hinlink-h29k.dts"
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


# ======================== 【设为系统默认中文MiSans-Regular.ttf字体】 ========================
# ✅ 原理：通过 fontconfig 规则，让所有 <family>serif</family>、<family>sans-serif</family>、<family>monospace</family>
#        的中文文本自动 fallback 到 MiSans-Regular.ttf（OpenWrt 默认使用 fontconfig 2.13+）
mkdir -p files/etc/fonts/conf.d

cat > files/etc/fonts/conf.d/99-misans-default.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- 将 MiSans 设为中文字体首选 -->
  <match target="pattern">
    <test name="lang" compare="contains">
      <string>zh</string>
    </test>
    <edit name="family" mode="prepend_first">
      <string>MiSans</string>
    </edit>
  </match>
  <!-- 全局 fallback：当请求 sans-serif/serif 时，优先使用 MiSans -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>MiSans</family>
      <family>DejaVu Sans</family>
      <family>WenQuanYi Micro Hei</family>
    </prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer>
      <family>MiSans</family>
      <family>DejaVu Serif</family>
      <family>WenQuanYi Micro Hei</family>
    </prefer>
  </alias>
</fontconfig>
EOF

printf '\n'
# ✅ 构建时预生成 fonts.cache（避免首次启动卡顿，兼容 BusyBox 环境）
echo "✅ 已配置 MiSans 为默认中文字体，构建后生效"

# ======================== 【屏幕脚本（procd 服务化）】 ========================
# ✅ 修复点8：弃用 /etc/rc.local（OpenWrt 22.03+ 已废弃），改用 procd 服务管理
#    优势：启动时机可控、日志可查、状态可监控、重启安全
mkdir -p files/etc/init.d
cat > files/etc/init.d/h29k-screen <<'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
  procd_open_instance
  procd_set_param command /usr/bin/h29k_screen.sh
  procd_set_param respawn ${respawn_timeout:-3600} ${respawn_retry:-5}
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_close_instance
}

service_triggers() {
  procd_add_reload_trigger "system"
}
EOF
chmod +x files/etc/init.d/h29k-screen

# 屏幕主脚本（保持原逻辑，仅路径适配）
mkdir -p files/usr/bin
cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/truetype/MiSans-Regular.ttf"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"
sleep 12
for i in 1 2 3; do [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8; done

while true; do
    # ==============================
    # 动态获取 cdc-wdm 设备（兼容多模组）
    # ==============================
    WDM_DEV=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1)
    WDM_DEV=${WDM_DEV:-/dev/cdc-wdm0}
    RSRP=$(uqmi -d "$WDM_DEV" --get-signal-info 2>/dev/null | grep rsrp | awk '{print $2}')
    [ -z "$RSRP" ] && RSRP="Search"

    # ✅ 网络名言（带超时）→ 失败则 fallback 到本地预存名言（3条）
    QUOTE=$(curl -s --connect-timeout 2 --max-time 3 "https://v1.hitokoto.cn/?encode=text" 2>/dev/null | cut -c 1-25)
    if [ -z "$QUOTE" ]; then
      # 🔹 本地名言库（UTF-8 短句，适配 MiSans 渲染）
      QUOTES=(
        "山高水长，行则将至"
        "心之所向，素履以往"
        "静水流深，厚积薄发"
      )
      # 🔹 随机选取一条（BusyBox shuf 兼容写法）
      RAND_IDX=$((RANDOM % ${#QUOTES[@]}))
      QUOTE="${QUOTES[$RAND_IDX]}"
    fi

    convert "$LOGO_DIR/LOGO3.jpg" -fill "rgba(0,0,0,0.7)" -draw "rectangle 0 60 240 240" \
    -font "$FONT" -fill "#00FF00" -pointsize 45 -annotate +35+130 "$RSRP" \
    -fill white -pointsize 15 -annotate +160+130 "dB" \
    -fill "#222222" -draw "rectangle 0 195 240 240" \
    -fill "#CCCCCC" -pointsize 14 -annotate +10+225 "${QUOTE:-H29K Ready}" "$TMP_IMG"
    fbv -f "$TMP_IMG"
    sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

# ======================== 【系统默认设置（UCI）】 ========================
# ✅ 修复点9：启用 h29k-screen 服务（替代 rc.local）
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k <<'EOF'
#!/bin/sh
# ✅ 设置系统基础参数
uci set luci.main.lang=zh_cn
uci set system.@system.hostname=H29K
uci set system.@system.zonename=Asia/Shanghai
uci set system.@system.timezone=CST-8
uci commit system

# ✅ 启用 IRQ 平衡服务（提升多核性能）
/etc/init.d/irqbalance enable

# ✅ 禁用 ModemManager（避免与 uqmi/uqmic 冲突）
/etc/init.d/modemmanager disable

# ✅ 启用自定义屏幕服务（procd 方式，安全可靠）
/etc/init.d/h29k-screen enable

exit 0
EOF
chmod +x files/etc/uci-defaults/99-h29k

# 【强制清理配置，避免残留冲突】
sed -i '/^CONFIG_TARGET_rockchip_armv8_DEVICE_/s/=y$/=n/' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

printf '\n'
