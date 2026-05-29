#!/bin/bash

set -euo pipefail  # 🔥 关键修复：任一命令失败立即终止，杜绝静默错误

# ======================== 【资源准备】 ========================
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
# ==========================================================================
# 配置 input-event-daemon 转发按键事件 → 兼容 OpenWrt 原生 button 脚本
# ==========================================================================
mkdir -p files/etc

# 生成 input-event-daemon 配置
cat > files/etc/input-event-daemon.conf <<'EOF'
/dev/input/event0
412:1:/bin/button hotplug reset pressed
412:0:/bin/button hotplug reset released
EOF

# ======================== 【离线复制字体：MiSans-Regular.ttf】 ========================
SRC_FONT="$(dirname "$0")/fonts/MiSans-Regular.ttf"
DST_FONT="files/usr/share/fonts/truetype/MiSans-Regular.ttf"

mkdir -p "$(dirname "$DST_FONT")"

if [ ! -f "$SRC_FONT" ]; then
  echo "❌ 错误：字体文件未找到！请确认："
  echo "    • fonts/MiSans-Regular.ttf 已提交到 Git"
  echo "    • 查找路径：$SRC_FONT"
  exit 1
fi

if [[ ! -r "$SRC_FONT" ]]; then
  echo -e "\033[31m❌ 错误：字体文件不可读（权限问题）\033[0m"
  ls -l "$SRC_FONT"
  exit 1
fi

cp -f "$SRC_FONT" "$DST_FONT"

if [[ ! -s "$DST_FONT" ]]; then
  echo -e "\033[31m❌ 错误：复制后目标文件为空！\033[0m"
  exit 1
fi

# 用 Linux 原生 od 代替 xxd，防止编译宿主机因没有 xxd 导致 pipefail 崩溃
MAGIC=$(head -c 4 "$DST_FONT" 2>/dev/null | od -t x1 -An | tr -d ' \n')
if [[ "$MAGIC" != "00010000" ]] && [[ "$MAGIC" != "4f54544f" ]]; then
  echo -e "\033[31m❌ 错误：'$DST_FONT' 不是有效的 TTF/OTF 字体（Magic: $MAGIC）\033[0m"
  exit 1
fi

chmod 644 "$DST_FONT"
echo "✅ 字体复制并校验成功：$DST_FONT"

# ======================== 【设为系统默认中文字体】 ========================
mkdir -p files/etc/fonts/conf.d

cat > files/etc/fonts/conf.d/99-misans-default.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="lang" compare="contains">
      <string>zh</string>
    </test>
    <edit name="family" mode="prepend_first">
      <string>MiSans</string>
    </edit>
  </match>
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

# ======================== 【屏幕脚本（procd 服务化）】 ========================
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

# 屏幕主脚本
mkdir -p files/usr/bin
cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/truetype/MiSans-Regular.ttf"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"

sleep 12
fc-cache -f /usr/share/fonts/truetype/ 2>/dev/null

for i in 1 2 3; do 
    [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8
done

while true; do
    WDM_DEV=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1)
    WDM_DEV=${WDM_DEV:-/dev/cdc-wdm0}
    
    # 🎯 核心优化：多级定界清洗 JSON 脏字符，防止 RSRP 显示带逗号或引号
    RSRP=$(uqmi -d "$WDM_DEV" --get-signal-info 2>/dev/null | grep rsrp | awk -F: '{print $2}' | tr -d ' ,"' | head -n1)
    [ -z "$RSRP" ] && RSRP="Search"

    QUOTE=$(curl -s --connect-timeout 2 --max-time 3 "https://v1.hitokoto.cn/?encode=text" 2>/dev/null | tr -d '\r\n')
    if [ -z "$QUOTE" ]; then
      RAND_IDX=$(($(date +%s) % 3))
      case "$RAND_IDX" in
        0) QUOTE="山林从不向四季起誓，枯萎随缘" ;;
        1) QUOTE="真爱没用，相爱才有用" ;;
        2) QUOTE="被你改变的那一部分我，代替了你永远陪在了我的身边。" ;;
      esac
    fi

    if [ -f "$LOGO_DIR/LOGO3.jpg" ]; then
        gm convert "$LOGO_DIR/LOGO3.jpg" -resize 320x172\! \
        -fill "rgba(0,0,0,0.6)" -draw "rectangle 0 20 320 130" \
        -font "$FONT" -fill "#00FF00" -pointsize 48 -annotate +40+95 "$RSRP" \
        -fill white -pointsize 16 -annotate +215+95 "dB" \
        -fill "#1a1a1a" -draw "rectangle 0 140 320 172" \
        -fill "#CCCCCC" -pointsize 13 -annotate +15+161 "${QUOTE:-H29K Ready}" "$TMP_IMG" 2>/dev/null || echo "Render Error"
    fi
    
    [ -s "$TMP_IMG" ] && fbv -f "$TMP_IMG" 2>/dev/null

    sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

# ======================== 【系统默认设置（UCI）】 ========================
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k <<'EOF'
#!/bin/sh
uci set luci.main.lang=zh_cn
uci set system.@system.hostname=H29K
uci set system.@system.zonename=Asia/Shanghai
uci set system.@system.timezone=CST-8
uci commit system

/etc/init.d/irqbalance enable
/etc/init.d/modemmanager disable

if [ -f "/etc/init.d/input-event-daemon" ]; then
    /etc/init.d/input-event-daemon enable
fi

/etc/init.d/h29k-screen enable
exit 0
EOF
chmod +x files/etc/uci-defaults/99-h29k

# ======================== Docker + MediaMTX 预装 ========================

# 1. Docker 基础内核模块声明
mkdir -p files/etc/modules.d
echo -e "overlay\nbridge\nveth" > files/etc/modules.d/30-docker

# 2. 预先拉取 MediaMTX 配置文件
mkdir -p files/etc/docker/mediamtx
curl -fsSL --retry 3 \
  https://raw.githubusercontent.com/bluenviron/mediamtx/main/mediamtx.yml \
  -o files/etc/docker/mediamtx/mediamtx.yml

# 3. 🎯 核心重构：建立一个标准的 OpenWrt 开机单次自愈初始化服务，替代不兼容的 Cron @reboot 方案
mkdir -p files/etc/init.d
cat > files/etc/init.d/mediamtx-init <<'EOF'
#!/bin/sh /etc/rc.common

START=99

boot() {
    # 循环守卫：确保等待 Docker 守护引擎完全唤醒（最长守卫 30 秒）
    local timeout=0
    while [ ! -S /var/run/docker.sock ]; do
        if [ $timeout -gt 30 ]; then
            echo "❌ Docker 引擎启动超时，跳过 MediaMTX 自动化部署" >&2
            return 1
        fi
        sleep 1
        timeout=$((timeout + 1))
    done

    # 智能检索机制：如果容器未创建则初始化；如果已存在，让 Docker 自身的 --restart 策略接管，防止重复执行报错死锁
    if ! docker ps -a --format '{{.Names}}' | grep -q '^mediamtx$'; then
        echo "🚀 首次开机：正在部署并运行 MediaMTX 容器..."
        docker run -d \
          --name mediamtx \
          --restart always \
          --network host \
          -v /etc/docker/mediamtx/mediamtx.yml:/mediamtx.yml \
          bluenviron/mediamtx:latest
    else
        echo "✅ MediaMTX 容器已就绪，交由 Docker 引擎自主托管启动"
    fi
}
EOF
chmod +x files/etc/init.d/mediamtx-init

# 4. 在 uci-defaults 中注册这两个服务的自启状态
cat > files/etc/uci-defaults/98-docker-autostart <<'EOF'
#!/bin/sh
/etc/init.d/dockerd enable
/etc/init.d/mediamtx-init enable
exit 0
EOF
chmod +x files/etc/uci-defaults/98-docker-autostart

# 强行解除 dockerman 面板对 docker-compose 的底层编译依赖
sed -i 's/+docker-compose-v2//g' feeds/luci/applications/luci-app-dockerman/Makefile 2>/dev/null || true
sed -i 's/+docker-compose//g' feeds/luci/applications/luci-app-dockerman/Makefile 2>/dev/null || true

printf '\n'
# ======================== 【H29K 强制校验】 ========================
echo "🔍 开始 H29K 构建前置 2 重校验..."

DEVICE_NAME="hinlink_h29k"
MK_FILE="target/linux/rockchip/image/armv8.mk"
if ! grep -q "$DEVICE_NAME" "$MK_FILE"; then
  echo -e "\033[31m[错误] H29K 设备未定义！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] 设备定义已写入 armv8.mk\033[0m"

[ -f package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig ] || { echo "❌ 错误：U-Boot 配置文件缺失！" >&2; exit 1; }

echo "✅ 成功：H29K 预处理与一键部署逻辑已达完美闭环状态！"
