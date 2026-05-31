#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

set -euo pipefail  # 严格报错模式：任一命令失败立即终止

# ======================== 【1. 统一下载与文件校验中心】 ========================
echo "📥 开始统一拉取 H29K 编译所需的核心外置资源..."

# 创建全局所需的所有目录架构
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip \
         package/boot/uboot-rockchip/configs \
         package/boot/uboot-rockchip/dts \
         target/linux/rockchip/image \
         scripts \
         files/etc/config/screen \
         files/etc/docker/mediamtx \
         files/etc/init.d \
         files/etc/fonts/conf.d \
         files/usr/bin

BASE_URL="https://raw.githubusercontent.com/I-agree/H29K/main/files"
LOGO_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"

# [工具函数] 统一的下载与基础大小校验
download_and_check() {
    local url="$1"
    local dest="$2"
    echo "正在下载: $dest ..."
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$url" -o "$dest"
    if [ ! -s "$dest" ]; then
        echo "❌ 错误: $dest 下载失败或文件为空！"
        exit 1
    fi
}

# --- 批量下载 10 个核心底座组件 ---
download_and_check "${BASE_URL}/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts" "target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-hinlink-h29k.dts"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"
download_and_check "${BASE_URL}/target/linux/rockchip/image/armv8.mk" "target/linux/rockchip/image/armv8.mk"
download_and_check "${BASE_URL}/target/linux/rockchip/Makefile" "target/linux/rockchip/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/Makefile" "package/boot/uboot-rockchip/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-tools/Makefile" "package/boot/uboot-tools/Makefile"
download_and_check "${BASE_URL}/target/linux/rockchip/image/Makefile" "target/linux/rockchip/image/Makefile"
download_and_check "${BASE_URL}/target/linux/rockchip/image/mmc.bootscript" "target/linux/rockchip/image/mmc.bootscript"
download_and_check "${BASE_URL}/scripts/gen_image_generic.sh" "scripts/gen_image_generic.sh"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts" "package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts"

# --- 深度内容专项校验 ---
if grep -q "hinlink_h28k" "target/linux/rockchip/image/armv8.mk"; then
    echo "❌ 错误: armv8.mk 包含非法内容 (h28k)" && exit 1
fi
if ! grep -q "智能识别 Binman 合体固件或传统拆分固件" "target/linux/rockchip/image/Makefile"; then
    echo "❌ 错误: Makefile 核心打包规则不匹配" && exit 1
fi

# --- 统一拉取应用层开机 LOGO 组与 MediaMTX 配置 ---
for i in 1 2 3; do
    download_and_check "${LOGO_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg"
done
download_and_check "https://raw.githubusercontent.com/bluenviron/mediamtx/main/mediamtx.yml" "files/etc/docker/mediamtx/mediamtx.yml"

echo "✅ 所有外部资源下载并校验通过！"

# ======================== 【2. 清理原生冲突架构源】 ========================
echo "🧹 正在清理原生冲突的架构补丁..."
rm -f target/linux/bcm27xx/patches-6.12/950-0076-OF-DT-Overlay-configfs-interface.patch || true
rm -f target/linux/ipq806x/patches-6.12/901-02-ARM-decompressor-add-option-to-ignore-MEM-ATAGs.patch || true
rm -f target/linux/mpc85xx/patches-6.12/102-powerpc-add-cmdline-override.patch || true
rm -f package/boot/uboot-mediatek/patches/280-image-fdt-save-name-of-FIT-configuration-in-chosen-node.patch || true
rm -f target/linux/qualcommax/patches-6.12/0911-arm64-cmdline-replacement.patch || true
rm -f target/linux/ipq806x/patches-6.12/902-ARM-decompressor-support-for-ATAGs-rootblock-parsing.patch || true
rm -f target/linux/ipq806x/patches-6.12/900-arm-add-cmdline-override.patch || true
rm -f target/linux/mvebu/patches-6.12/300-mvebu-Mangle-bootloader-s-kernel-arguments.patch || true
rm -rf target/linux/airoha

# ======================== 【3. H29K 主线内核配置合并注入】 ========================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 🌟【核心修复】彻底剔除可能残存的硬件加密旧总开关、所有旧子驱动符号（含非对称加密组件）以及屏幕、调度器冲突项
sed -i '/CONFIG_EMAC_ROCKCHIP/d; /CONFIG_ARM64_PA_BITS/d; /CONFIG_CMA_SIZE_MBYTES/d; /CONFIG_CRYPTO_HW/d; /CONFIG_CRYPTO_DEV_/d; /CONFIG_CRYPTO_AKCIPHER/d; /CONFIG_CRYPTO_KPP/d; /CONFIG_DEFAULT_NET_CONG/d; /CONFIG_DEFAULT_BBR/d; /CONFIG_DRM_PANEL_SITRONIX_ST7789V/d; /CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL/d' "$CONFIG_FILE" 2>/dev/null || true

cat >> "$CONFIG_FILE" << 'EOF'

# === RK3528 主线核心与平台级别底座驱动（对齐 Linux 6.12）===
CONFIG_ARCH_ROCKCHIP=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_VA_BITS_48=y
CONFIG_ARM64_VA_BITS=48
CONFIG_ARM64_PA_BITS_48=y
CONFIG_COMMON_CLK_ROCKCHIP=y
CONFIG_ROCKCHIP_PMDOMAINS=y
CONFIG_PWM_ROCKCHIP=y
CONFIG_OF_GPIO=y

# --- 禁用低效且冲突的板载硬件加密，全力释放更强的 ARMv8 CPU 内置加密扩展性能 ---
CONFIG_CRYPTO_HW=y
# CONFIG_CRYPTO_DEV_ROCKCHIP is not set

# --- 主线标准显示架构与 ST7789V 屏幕驱动对齐 ---
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_PANEL_SITRONIX_ST7789V=y
CONFIG_BACKLIGHT_PWM=y

# --- 主线标准高速总线与存储协议栈 ---
CONFIG_SPI_ROCKCHIP=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y
CONFIG_MMC_SDHCI_OF_ROCKCHIP=y
CONFIG_USB_DWC3_ROCKCHIP=y

# --- CMA 连续物理内存调优 ---
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_CMA_SIZE_MBYTES=128

# --- 网络高并发 TCP BBR + FQ 底层内建 ---
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_NET_CONG="bbr"
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_QDISC="fq"

# --- 采用现代 Schedutil 智能调度模式 ---
CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y

# --- 关闭主线无需或可能冲突的功能 ---
# CONFIG_SND is not set
# CONFIG_BT is not set
EOF
echo "✅ 已向 $CONFIG_FILE 注入目标内核参数"

# 全局通用内核参数防御修正
GENERIC_CONFIG="target/linux/generic/config-6.12"
if [ -f "$GENERIC_CONFIG" ]; then
    sed -i '/CONFIG_ARM64_SVE/d; /CONFIG_ARM64_ASIMD/d' "$GENERIC_CONFIG"
    echo "# CONFIG_ARM64_SVE is not set" >> "$GENERIC_CONFIG"
    echo "CONFIG_ARM64_ASIMD=y" >> "$GENERIC_CONFIG"
fi

# 写入单机型 Override 规则
echo -e "# H29K OVERRIDE\n# CONFIG_TARGET_MULTI_ARCH is not set\nCONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" > .config.override

# ======================== 【4. 屏幕驱动与核心系统组件注入】 ========================
# 按钮映射配置
mkdir -p files/etc
cat > files/etc/input-event-daemon.conf <<'EOF'
/dev/input/event0
412:1:/bin/button hotplug reset pressed
412:0:/bin/button hotplug reset released
EOF

# 本地字体合规复制
SRC_FONT="$(dirname "$0")/fonts/MiSans-Regular.ttf"
DST_FONT="files/usr/share/fonts/truetype/MiSans-Regular.ttf"
mkdir -p "$(dirname "$DST_FONT")"

if [ -f "$SRC_FONT" ]; then
    cp -f "$SRC_FONT" "$DST_FONT"
    MAGIC=$(head -c 4 "$DST_FONT" 2>/dev/null | od -t x1 -An | tr -d ' \n')
    if [[ "$MAGIC" != "00010000" ]] && [[ "$MAGIC" != "4f54544f" ]]; then
        echo "❌ 错误：字体魔数校验未通过！" && exit 1
    fi
    chmod 644 "$DST_FONT"
else
    echo "❌ 错误：未在本地 fonts/ 目录找到 MiSans-Regular.ttf" && exit 1
fi

# 系统默认中文字体指定
mkdir -p files/etc/fonts/conf.d
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

# 屏幕守护服务化脚本
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

# 屏幕主控渲染引擎
mkdir -p files/usr/bin
cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/truetype/MiSans-Regular.ttf"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"
sleep 12
for i in 1 2 3; do 
    [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8
done

while true; do
    WDM_DEV=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1)
    WDM_DEV=${WDM_DEV:-/dev/cdc-wdm0}
    RSRP=$(uqmi -d "$WDM_DEV" --get-signal-info 2>/dev/null | grep rsrp | awk -F: '{print $2}' | tr -d ' ,"' | head -n1)
    [ -z "$RSRP" ] && RSRP="Search"

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

    if [ -f "$LOGO_DIR/LOGO3.jpg" ]; then
        # 🌟【优化】将强制改变长宽比的 ! 符号通过双引号包裹，使其在各种 shell 环境中均能完美解析
        gm convert "$LOGO_DIR/LOGO3.jpg" -resize "320x172!" -fill "rgba(0,0,0,0.6)" -draw "rectangle 0 20 320 130" -font "$FONT" -fill "#00FF00" -pointsize 48 -annotate +40+95 "$RSRP" -fill white -pointsize 16 -annotate +215+95 "dB" -fill "#1a1a1a" -draw "rectangle 0 140 320 172" -fill "#CCCCCC" -pointsize 13 -annotate +15+161 "$QUOTE" "$TMP_IMG" 2>/dev/null || echo "Render Error"
    fi
    [ -s "$TMP_IMG" ] && fbv -f "$TMP_IMG" 2>/dev/null
    sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

# ======================== 【5. 系统初始化与 UCI 策略】 ========================
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
/etc/init.d/h29k-screen enable
exit 0
EOF
chmod +x files/etc/uci-defaults/99-h29k

# ======================== 【6. Docker 与 MediaMTX 容器流】 ========================
mkdir -p files/etc/modules.d
echo -e "overlay\nbridge\nveth" > files/etc/modules.d/30-docker

cat > files/etc/init.d/mediamtx-init <<'EOF'
#!/bin/sh /etc/rc.common
START=99
boot() {
    local timeout=0
    while [ ! -S /var/run/docker.sock ]; do
        if [ $timeout -gt 30 ]; then return 1; fi
        sleep 1
        timeout=$((timeout + 1))
    done
    if ! docker ps -a --format '{{.Names}}' | grep -q '^mediamtx$'; then
        docker run -d --name mediamtx --restart always --network host -v /etc/docker/mediamtx/mediamtx.yml:/mediamtx.yml bluenviron/mediamtx:latest
    fi
}
EOF
chmod +x files/etc/init.d/mediamtx-init

cat > files/etc/uci-defaults/98-docker-autostart <<'EOF'
#!/bin/sh
/etc/init.d/dockerd enable
/etc/init.d/mediamtx-init enable
exit 0
EOF
chmod +x files/etc/uci-defaults/98-docker-autostart

sed -i 's/+docker-compose-v2//g; s/+docker-compose//g' feeds/luci/applications/luci-app-dockerman/Makefile 2>/dev/null || true

# 网络栈核心高并发参数微调
mkdir -p package/base-files/files/etc
sed -i '/net.netfilter.nf_conntrack_max/d' package/base-files/files/etc/sysctl.conf 2>/dev/null || true
cat >> package/base-files/files/etc/sysctl.conf << 'EOF'
net.netfilter.nf_conntrack_max=262144
net.core.netdev_max_backlog=10000
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF

# ==============================================================================
# 📹 【完全体边缘导播】动态插拔、HDMI同步、网络RTSP、网页端一键RTMP直播推流系统
# ==============================================================================
echo "🚀 正在注入 H29K 专属微型直播导播守护系统..."

# 1. 创建配置与脚本存放目录
mkdir -p files/usr/bin
mkdir -p files/etc/init.d
mkdir -p files/etc/docker/mediamtx

# 2. 生成 MediaMTX 核心配置文件（升级为 H.264 零功耗采集）
cat > files/etc/docker/mediamtx/mediamtx.yml << 'EOF'
paths:
  cam:
    # 🌟 切换为 -input_format h264 硬件直出，-c:v copy 彻底解放 CPU
    # 麦克风音频同样打包进 RTSP 流中（rtsp://127.0.0.1:8554/cam）
    runOnInit: ffmpeg -f v4l2 -input_format h264 -i /dev/video0 -f alsa -i hw:1,0 -c:v copy -c:a aac -b:a 128k -f rtsp rtsp://127.0.0.1:8554/cam
EOF

# 3. 编写【直播推流控制脚本】（供网页端调用）
cat > files/usr/bin/live-push.sh << 'EOF'
#!/bin/sh

ACTION=$1
RTMP_URL=$2

is_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

case "$ACTION" in
    start)
        if [ -z "$RTMP_URL" ]; then
            echo "❌ 错误：未检测到推流地址！请在后面加上你的直播间 RTMP 地址和密钥。"
            exit 1
        fi
        if ! [ -e /dev/video0 ]; then
            echo "❌ 错误：当前未连接摄像头，拒绝发起直播！"
            exit 1
        fi
        
        # 如果已有旧推流，先物理超度
        docker rm -f live-pusher >/dev/null 2>&1
        
        echo "📡 正在启动网络直播推流模块..."
        # 🌟 从本地零延迟的 RTSP 源摘取音视频，原封不动地 (-c copy) 丢给 B站/抖音等直播平台，CPU 完全不发热！
        docker run -d --name live-pusher --restart always --network host \
            alpine:3.19 sh -c "apk add --no-cache ffmpeg && ffmpeg -i rtsp://127.0.0.1:8554/cam -c:v copy -c:a copy -f flv '$RTMP_URL'"
        
        if [ $? -eq 0 ]; then
            echo "✅ 直播推流已成功发起！"
            echo "🔗 目标平台: $RTMP_URL"
        else
            echo "❌ 直播推流容器启动失败，请检查网络或地址。"
        fi
        ;;
        
    stop)
        if is_container_running "live-pusher"; then
            echo "🛑 正在停止直播推流..."
            docker rm -f live-pusher >/dev/null 2>&1
            echo "✅ 直播已安全关闭，断开与平台的连接。"
        else
            echo "ℹ️ 当前没有正在进行的直播推流。"
        fi
        ;;
        
    status)
        if is_container_running "live-pusher"; then
            echo "🟢 状态：正在激情直播中..."
            docker logs --tail 2 live-pusher
        else
            echo "⚪ 状态：闲置中，未开启直播。"
        fi
        ;;
    *)
        echo "使用方法: $0 {start \"你的RTMP推流地址\"|stop|status}"
        ;;
esac
EOF

chmod +x files/usr/bin/live-push.sh

# 4. 编写核心动态监测与控制引擎脚本（加入直播断开保护机制）
cat > files/usr/bin/cam-monitor.sh << 'EOF'
#!/bin/sh

is_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

echo "👀 H29K 智能直播机监测守护进程已启动..."

while true; do
    # 核心判断：只有当检测到摄像头硬件存在时才工作
    if [ -e /dev/video0 ] && [ -e /dev/snd ]; then
        
        # A. 激活【网络串流核心服务】
        if ! is_container_running "mediamtx"; then
            echo "🎵 检测到摄像头接入，正在唤醒基础音视频引擎..."
            docker run -d --name mediamtx --restart always --network host \
                --privileged \
                --device /dev/video0:/dev/video0 \
                --device /dev/snd:/dev/snd \
                -v /etc/docker/mediamtx/mediamtx.yml:/mediamtx.yml \
                bluenviron/mediamtx:latest
        fi

        # B. 激活【HDMI本地大屏音画同步播放器】
        if ! is_container_running "cam-hdmi-player"; then
            echo "📺 正在向 HDMI 外接大屏输出实时音画面..."
            docker run -d --name cam-hdmi-player --restart always --network host \
                --privileged \
                --device /dev/fb0:/dev/fb0 \
                --device /dev/snd:/dev/snd \
                alpine:3.19 sh -c "apk add --no-cache ffmpeg && ffmpeg -re -i rtsp://127.0.0.1:8554/cam -f fbdev /dev/fb0 -f alsa hw:0,0"
        fi

    else
        # 💥 物理断电保护：如果拔掉摄像头，连同【直播推流】在内的所有容器瞬间强杀，防止后台死循环报错崩溃
        if echo "$(docker ps --format '{{.Names}}')" | grep -qE "cam-hdmi-player|mediamtx|live-pusher"; then
            echo "⚠️ 摄像头被物理拔出，正在紧急熔断直播、大屏输出及基础服务..."
            docker rm -f cam-hdmi-player mediamtx live-pusher >/dev/null 2>&1
            # 清屏，恢复整洁的 HDMI 显示端
            cat /dev/zero > /dev/fb0 >/dev/null 2>&1
        fi
    fi
    
    sleep 3
done
EOF

chmod +x files/usr/bin/cam-monitor.sh

# 5. 建立系统自启服务
cat > files/etc/init.d/cam-monitor << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh /usr/bin/cam-monitor.sh
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}
EOF

chmod +x files/etc/init.d/cam-monitor
echo "✅ 完全体智能导播直播系统部署完成！"

# ==============================================================================
# 🎛️ 【LuCI 预装】将直播控制按钮直接固化进入 OpenWrt 网页后台
# ==============================================================================
echo "🎨 正在向固件中预装『自定义命令』直播控制按钮..."

# 1. 确保 UCI 配置目录存在
mkdir -p files/etc/config

# 2. 写入预设的 luci_commands 配置文件
# 预设了三个按钮：开启（带默认提示占位符）、关闭、查看状态
cat > files/etc/config/luci_commands << 'EOF'

config command
	option name '🚀 一键开启网络直播'
	option command '/usr/bin/live-push.sh start "请在这里替换为你的RTMP推流地址和密钥"'

config command
	option name '🛑 一键关闭网络直播'
	option command '/usr/bin/live-push.sh stop'

config command
	option name '📊 查看当前直播状态'
	option command '/usr/bin/live-push.sh status'
EOF

echo "💖 网页端快捷按钮已成功打包进固件源码树！"

echo "🚀 H29K 所有轻量化改造与下载链整合已全部就位！"
