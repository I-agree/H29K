#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

set -euo pipefail  # 严格报错模式：任一非条件命令失败立即终止

# =================================================================================
# 1. 🎯 工业级自愈补丁：将 rk3528-hinlink-h29k 安全注册进内核 Makefile
# =================================================================================
# 使用原生 Shell 循环替代 ls/find 管道，100% 免疫 set -e 报错自杀机制
PATCH_DIR=""
for d in target/linux/rockchip/patches-6.12 target/linux/rockchip/patches-*; do
    if [ -d "$d" ]; then
        PATCH_DIR="$d"
        break
    fi
done

if [ -n "$PATCH_DIR" ]; then
    echo "📥 侦测到目标内核补丁阵列: $PATCH_DIR，正在注入 H29K 标准差分补丁..."
    
    # 写入数学计数严密对齐的 Unified Diff 补丁，严防 Quilt 报 Hunk Header 错误
    cat << 'EOF' > "$PATCH_DIR/999-add-rk3528-hinlink-h29k-makefile.patch"
--- a/arch/arm64/boot/dts/rockchip/Makefile
+++ b/arch/arm64/boot/dts/rockchip/Makefile
@@ -1,1 +1,2 @@
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3528-hinlink-h28k.dtb
+dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3528-hinlink-h29k.dtb
EOF

    echo "✅ 严格数学对齐内核补丁已成功封印至 Quilt 队列！"
else
    echo "⚠️ 提示：未探测到 rockchip 补丁目录，跳过内核补丁修改。"
fi

# =================================================================================
# 🚨 核心补丁：打通 OpenWrt 外层依赖锁
# =================================================================================

# ======================== 【3. 屏幕驱动与核心系统组件注入】 ========================
mkdir -p files/etc
cat > files/etc/input-event-daemon.conf <<'EOF'
/dev/input/event0
412:1:/bin/button hotplug reset pressed
412:0:/bin/button hotplug reset released
EOF

SRC_FONT="$(dirname "$0")/fonts/MiSans-Regular.ttf"
DST_FONT="files/usr/share/fonts/truetype/MiSans-Regular.ttf"
mkdir -p "$(dirname "$DST_FONT")"

if [ -f "$SRC_FONT" ]; then
    cp -f "$SRC_FONT" "$DST_FONT"
    MAGIC=$(head -c 4 "$DST_FONT" 2>/dev/null | od -t x1 -An | tr -d ' \n' || true)
    if [[ "$MAGIC" != "00010000" ]] && [[ "$MAGIC" != "4f54544f" ]]; then
        echo "❌ 错误：字体魔数校验未通过！" && exit 1
    fi
    chmod 644 "$DST_FONT"
else
    echo "❌ 错误：未在本地 fonts/ 目录找到 MiSans-Regular.ttf" && exit 1
fi

cat > files/etc/fonts/conf.d/99-misans-default.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="lang" compare="contains"><string>zh</string></test>
    <edit name="family" mode="prepend_first"><string>MiSans</string></edit>
  </match>
</fontconfig>
EOF

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
EOF
chmod +x files/etc/init.d/h29k-screen

cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/truetype/MiSans-Regular.ttf"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"

# 自动匹配 ST7789 小屏对应的帧缓冲设备
get_st7789_fb() {
    for fb in /sys/class/graphics/fb*; do
        if [ -f "$fb/device/of_node/compatible" ]; then
            if grep -q "sitronix,st7789v" "$fb/device/of_node/compatible" 2>/dev/null; then
                echo "/dev/$(basename "$fb")"
                return 0
            fi
        fi
    done
    # 兜底：匹配失败时降级为 fb1，兼容旧逻辑
    echo "/dev/fb1"
}
SCREEN_FB=$(get_st7789_fb)

sleep 12

# 启动连续开机 LOGO 动画
for i in 1 2 3; do 
    [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -d "$SCREEN_FB" -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8
done

while true; do
    # 初始化看板默认状态
    RSRP="Search"
    UNIT=" "

    # =================================================================================
    # 📡 5G 模组状态机：智能化硬件盲猜与自愈感知（MBIM -> QMI -> RNDIS 三级兜底）
    # =================================================================================
    WDM_DEV=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1)
    
    # 【第一级：判定是否为联发科 FM350-GL 等标准的 MBIM 驱动模式】
    if [ -n "$WDM_DEV" ] && command -v mbimcli >/dev/null 2>&1; then
        MBIM_OUT=$(mbimcli -d "$WDM_DEV" --basic-connect-query-signal-state --no-close 2>/dev/null || true)
        # 从 MBIM 报文中精准抓取真实 dBm 值（例如抓取 '(-65 dBm)' 中的 '-65'）
        RSRP_VAL=$(echo "$MBIM_OUT" | grep -o '(-[0-9]\+' | tr -d '(' | head -n1)
        if [ -n "$RSRP_VAL" ]; then
            RSRP="$RSRP_VAL"
            UNIT="dB"
        fi
    fi

    # 【第二级：老旧高通 QMI 协议物理模组备份（uqmi 兜底）】
    if [ "$RSRP" = "Search" ] && command -v uqmi >/dev/null 2>&1; then
        WDM_DEV=${WDM_DEV:-/dev/cdc-wdm0}
        RSRP_VAL=$(uqmi -d "$WDM_DEV" --get-signal-info 2>/dev/null | grep rsrp | awk -F: '{print $2}' | tr -d ' ,"' | head -n1)
        if [ -n "$RSRP_VAL" ]; then
            RSRP="$RSRP_VAL"
            UNIT="dB"
        fi
    fi

    # 【第三级：切入 USB (RNDIS) 免驱网卡模式（通过网络延迟防崩换算）】
    if [ "$RSRP" = "Search" ]; then
        # 动态探测当前系统默认出网路由是否绑定在外接 USB 虚拟网卡上
        RNDIS_DEV=$(ip route | grep default | awk '{print $5}' | grep -E 'usb|eth' | head -n 1)
        if [ -n "$RNDIS_DEV" ]; then
            # 向公网发送 1 次极速 ping 探测
            PING_TIME=$(ping -I "$RNDIS_DEV" -c 1 -W 1 114.114.114.114 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print int($1)}' || true)
            if [ -n "$PING_TIME" ]; then
                # 核心调优：将 RNDIS 延迟无缝转译为“拟真 dBm 信号”，完美契合原 UI 渲染排版！
                if [ "$PING_TIME" -lt 25 ]; then RSRP="-55";
                elif [ "$PING_TIME" -lt 55 ]; then RSRP="-72";
                elif [ "$PING_TIME" -lt 95 ]; then RSRP="-88";
                else RSRP="-105"; fi
                UNIT="dB"
            else
                RSRP="NoNet" # RNDIS 存在，但未联网
                UNIT=" "
            fi
        else
            RSRP="Search" # 全线踏空，处于搜网或未插模块状态
            UNIT=" "
        fi
    fi
    # =================================================================================

    # 动态抓取一言名言 API
    if NET_QUOTE=$(curl -fsSL --connect-timeout 2 --max-time 3 "https://v1.hitokoto.cn/?c=f&encode=text" 2>/dev/null) && [ -n "$NET_QUOTE" ]; then
        QUOTE="$NET_QUOTE"
    else
        case $((RANDOM % 6)) in
            0) QUOTE="山林不向四季起誓，荣枯随缘。" ;;
            1) QUOTE="喜欢就处，别问是朋友还是恋人！" ;;
            2) QUOTE="关系不是绳子，非要绑住谁的手脚；" ;;
            3) QUOTE="缘分就像山风，吹到哪儿都是风景。" ;;
            4) QUOTE="能走一段是礼物，能走一生是运气。" ;;
            *) QUOTE="被你改变的那一部分我，代替了你永远陪在了我的身边。" ;;
        esac
    fi

    # 调用 GraphicsMagick 熔铸动态看板（完美利用变量 $UNIT 擦除多余后缀）
    if [ -f "$LOGO_DIR/LOGO3.jpg" ]; then
        gm convert "$LOGO_DIR/LOGO3.jpg" -resize "320x172!" \
            -fill "rgba(0,0,0,0.6)" -draw "rectangle 0 20 320 130" \
            -font "$FONT" -fill "#00FF00" -pointsize 48 -annotate +40+95 "$RSRP" \
            -fill white -pointsize 16 -annotate +215+95 "$UNIT" \
            -fill "#1a1a1a" -draw "rectangle 0 140 320 172" \
            -fill "#CCCCCC" -pointsize 13 -annotate +15+161 "$QUOTE" \
            "$TMP_IMG" 2>/dev/null || echo "Render Error"
    fi
    
    [ -s "$TMP_IMG" ] && fbv -d "$SCREEN_FB" -f "$TMP_IMG" 2>/dev/null
    sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

# ======================== 【4. 系统初始化与 UCI 策略】 ========================
# 👇 【已纠错】必须放在 uci-defaults 目录下，否则开机不会自动执行！
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/10-h29k <<'EOF'
#!/bin/sh

# === 基础系统设置：LuCI中文、主机名、时区 ===
uci -q set luci.main.lang=zh_cn
uci -q set system.@system[0].zonename=Asia/Shanghai
uci -q set system.@system[0].timezone=CST-8
uci -q get system.@system >/dev/null && uci -q set system.@system[0].hostname=H29K
uci -q commit system
uci -q commit luci

# === WiFi AP 配置：SSID=H29K，开放无密码 ===
# 👇 【已纠错】修复了 UCI 语法错误，确保无线配置能正确生成
uci -q delete wireless.default_radio0
uci -q set wireless.default_radio0=wifi-iface
uci -q set wireless.default_radio0.device=radio0
uci -q set wireless.default_radio0.mode=ap
uci -q set wireless.default_radio0.ssid=H29K
uci -q set wireless.default_radio0.encryption=none
uci -q set wireless.default_radio0.disabled=0
uci -q set wireless.default_radio0.network=lan

uci -q set wireless.radio0.disabled=0
uci -q commit wireless

# === 中断均衡：仅设置开机自启 ===
/etc/init.d/irqbalance enable

# === SPI屏幕自定义服务：仅设置开机自启 ===
/etc/init.d/h29k-screen enable

exit 0
EOF
chmod +x files/etc/uci-defaults/10-h29k

# =================================================================================
# 🚨 针对 aic8800 本地 Makefile 的终极补丁（支持 set -e 严格模式）
# =================================================================================
REAL_AIC_MAKEFILE="package/kernel/aic8800/Makefile"

if [ -f "$REAL_AIC_MAKEFILE" ]; then
    echo "📥 侦测到目标组件，正在从自定义仓库强制下载覆盖 aic8800 Makefile..."
    
    # 👇 【已加固】先下载到临时文件，校验成功后再覆盖，防止 pipefail 和空文件导致 grep 崩溃
    TMP_AIC_MAKEFILE=$(mktemp)
    if curl -sSL --connect-timeout 8 --retry 3 \
      "https://raw.githubusercontent.com/I-agree/H29K/main/package/kernel/aic8800/Makefile" > "$TMP_AIC_MAKEFILE"; then
      
        if [ -s "$TMP_AIC_MAKEFILE" ] && grep -q "PKG_BUILD_DEPENDS:=mac80211" "$TMP_AIC_MAKEFILE"; then
            mv -f "$TMP_AIC_MAKEFILE" "$REAL_AIC_MAKEFILE"
            echo "✅ aic8800 Makefile 覆盖成功，令牌锁死与 GCC14 报错已物理粉碎！"
        else
            echo "❌ 校验失败：Makefile 中缺失 PKG_BUILD_DEPENDS:=mac80211 或文件为空，编译将终止！"
            rm -f "$TMP_AIC_MAKEFILE"
            exit 1
        fi
    else
        echo "❌ 下载失败：无法获取 aic8800 Makefile，编译将终止！"
        rm -f "$TMP_AIC_MAKEFILE"
        exit 1
    fi
else
    echo "⚠️ 警告：在 $REAL_AIC_MAKEFILE 未找到该组件，请确认源码路径！"
fi

# =================================================================================

echo "🚀 H29K专用代码已经准备就绪，即将开始正式编译！"
