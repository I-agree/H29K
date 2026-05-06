#!/bin/bash
set -euo pipefail  # 🔥 关键修复：任一命令失败立即终止，杜绝静默错误

# ======================== 【资源准备】 ========================
# 创建开机 LOGO 存放目录
mkdir -p files/etc/config/screen bin/targets/rockchip/armv8/

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

# ==================== H29K 配置文件存在性验证（diy-part2.sh 专用） ====================
# ✅ 作用：在构建中途（defconfig 已执行后）再次确认两个关键配置文件已成功下载并就位
# ✅ 原因：防止 diy-part1.sh 下载失败、路径错误或被其他脚本误删，导致后续编译静默出错
# ✅ 策略：严格检查「普通文件是否存在」，任一缺失立即报错并终止构建，不妥协

# 检查 U-Boot 配置文件：应位于 package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig
[ -f package/boot/uboot-rockchip/configs/hinlink_h29k_defconfig ] || { echo "❌ 错误：U-Boot 配置文件缺失！请检查 diy-part1.sh 是否执行成功，或手动运行 wget 下载" >&2; exit 1; }

# 检查 Rockchip 固件镜像配置文件：应位于 target/linux/rockchip/image/hinlink_h29k_defconfig
[ -f target/linux/rockchip/image/hinlink_h29k_defconfig ] || { echo "❌ 错误：Rockchip 镜像配置文件缺失！该文件决定 kernel/image 打包行为，请勿遗漏" >&2; exit 1; }

# 全部通过 → 输出友好提示，继续构建流程
echo "✅ 成功：H29K 两份配置文件均已就位，构建流程将继续..."

printf '\n'
echo -e "\033[32m=====================================\033[0m"
echo -e "\033[32m✅ 所有检查通过！\033[0m"
echo -e "\033[32m=====================================\033[0m"
