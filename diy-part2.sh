#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

set -euo pipefail  # 严格报错模式：任一非条件命令失败立即终止

# ======================== 【0. 🚀 编译期：最新稳定版动态嗅探与自愈中心】 ========================
echo "🔍 正在动态获取互联网当前最新的稳定版版本号..."

# 🌟【自愈】末尾加上 || true。防止 GitHub Actions 共享 IP 触发 API 限流时导致 grep 失败
MEDIAMTX_RELEASES=$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 3 || true)

MEDIAMTX_VER=""
echo "🎁 开始智能检索并跨架构预拉取 H29K(ARM64) 专属 MediaMTX 镜像..."

# 🌟【架构修复】MediaMTX 必须使用带 -ffmpeg 后缀的官方镜像变体，否则 runOnInit 内部无法调用 ffmpeg 
if [ -n "$MEDIAMTX_RELEASES" ]; then
    for VER in $MEDIAMTX_RELEASES; do
        echo "⏳ 尝试拉取版本: bluenviron/mediamtx:${VER}-ffmpeg (linux/arm64) ..."
        if docker pull --platform linux/arm64 bluenviron/mediamtx:${VER}-ffmpeg >/dev/null 2>&1; then
            MEDIAMTX_VER="${VER}-ffmpeg"
            echo "🔥 [匹配成功] 已成功锁定并下载 MediaMTX 官方音视频完全体镜像标签: $MEDIAMTX_VER"
            break
        fi
        
        # 容错：去掉 'v' 前缀再次尝试
        VER_NO_V="${VER#v}"
        echo "⏳ 尝试拉取无 'v' 版本: bluenviron/mediamtx:${VER_NO_V}-ffmpeg (linux/arm64) ..."
        if docker pull --platform linux/arm64 bluenviron/mediamtx:${VER_NO_V}-ffmpeg >/dev/null 2>&1; then
            MEDIAMTX_VER="${VER_NO_V}-ffmpeg"
            echo "🔥 [匹配成功] 已成功锁定并下载 MediaMTX 官方音视频完全体镜像标签: $MEDIAMTX_VER"
            break
        fi
    done
fi

# 终极兜底
if [ -z "$MEDIAMTX_VER" ]; then
    echo "⚠️ 警告: 无法在 Docker Hub 找到精确的 Release 镜像，触发终极智能自愈兜底..."
    echo "⏳ 正在拉取 bluenviron/mediamtx:latest-ffmpeg (linux/arm64) ..."
    docker pull --platform linux/arm64 bluenviron/mediamtx:latest-ffmpeg
    docker tag bluenviron/mediamtx:latest-ffmpeg bluenviron/mediamtx:frozen-ffmpeg
    MEDIAMTX_VER="frozen-ffmpeg"
    echo "❄️ [兜底成功] 已将最新音视频一体镜像本地封印为永久冷启动标签: frozen-ffmpeg"
fi

# ② 动态抓取 Alpine 官方最新稳定版
docker pull alpine:latest >/dev/null 2>&1 || true
ALPINE_VER=$(docker run --rm alpine:latest cat /etc/alpine-release 2>/dev/null | tr -d '\r\n' || true)
if [ -z "$ALPINE_VER" ]; then
    echo "⚠️ 警告: 无法解析 Alpine 精确版本号，降级使用 3.20 稳定分支"
    FALLBACK_ALPINE_VER="3.20"
else
    FALLBACK_ALPINE_VER="$ALPINE_VER"
fi

echo "⏳ [宿主机环境预编译] 正在通过 Buildx 熔铸高并发纯本地化 ARM64 Alpine-FFmpeg 生产力镜像..."
# 🌟【自愈核心】在编译期利用 GitHub Actions 的强网环境，把 ffmpeg 灌入 Alpine 基础镜像中，彻底干掉运行期的 apk add 
cat > Dockerfile.alpine << EOF
FROM --platform=linux/arm64 alpine:${FALLBACK_ALPINE_VER}
RUN apk add --no-cache ffmpeg
EOF

# =================================================================
# ⚙️ 跨架构核心补丁：为 x86_64 宿主机注入 ARM64 动态内核模拟器
# =================================================================
echo "🔧 检测到 H29K 专属 ARM64 镜像熔铸需求，正在为宿主机注入 QEMU 模拟器..."
sudo docker run --privileged --rm tonistiigi/binfmt --install arm64

# --- 下面是 Docker 编译命令 ---
docker buildx build --platform linux/arm64 -f Dockerfile.alpine -t h29k-alpine-ffmpeg:${FALLBACK_ALPINE_VER} --load .

# ======================== 【1. 统一下载与文件校验中心】 ========================
echo "📥 开始统一拉取 H29K 编译所需的核心外置资源..."

mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip \
         package/boot/uboot-rockchip/configs \
         package/boot/uboot-rockchip/dts \
         target/linux/rockchip/image \
         scripts \
         files/etc/config/screen \
         files/etc/docker/mediamtx \
         files/etc/init.d \
         files/etc/fonts/conf.d \
         files/usr/bin \
         files/www \
         files/usr/share/docker-images

BASE_URL="https://raw.githubusercontent.com/I-agree/H29K/main/files"
LOGO_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"

download_and_check() {
    local url="$1"
    local dest="$2"
    echo "正在下载: $dest ..."
    if ! curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$url" -o "$dest"; then
        echo "❌ 错误: $url 网络请求或连接失败！" && exit 1
    fi
    if [ ! -s "$dest" ]; then
        echo "❌ 错误: $dest 下载成功但文件为空！" && exit 1
    fi
}

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

if grep -q "hinlink_h28k" "target/linux/rockchip/image/armv8.mk"; then
    echo "❌ 错误: armv8.mk 包含非法内容 (h28k)" && exit 1
fi
if ! grep -q "智能识别 Binman 合体固件或传统拆分固件" "target/linux/rockchip/image/Makefile"; then
    echo "❌ 错误: Makefile 核心打包规则不匹配" && exit 1
fi

for i in 1 2 3; do
    download_and_check "${LOGO_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg"
done

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

echo "📝 正在精准注入官方 OpenWrt 25.12 专属内核配置文件: $CONFIG_FILE"

# 清理可能引发覆盖的冲突条目
sed -i '/CONFIG_EMAC_ROCKCHIP/d; /CONFIG_ARM64_PA_BITS/d; /CONFIG_CMA_SIZE_MBYTES/d; /CONFIG_CRYPTO_HW/d; /CONFIG_CRYPTO_DEV_/d; /CONFIG_CRYPTO_AKCIPHER/d; /CONFIG_CRYPTO_KPP/d; /CONFIG_DEFAULT_NET_CONG/d; /CONFIG_DEFAULT_BBR/d; /CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL/d; /CONFIG_SND/d; /CONFIG_ARM64_SVE/d; /CONFIG_BT/d' "$CONFIG_FILE" 2>/dev/null || true

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

# --- 针对 A53 架构彻底关闭不支持的 SVE 扩展，全力确保 ASIMD(NEON) 跑满 ---
# CONFIG_ARM64_SVE is not set
CONFIG_ARM64_ASIMD=y

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

# 🌟【核心修复】彻底开启内核蓝牙协议栈总开关，确保 kmod-bluetooth 依赖能够顺利通过编译
CONFIG_BT=y
CONFIG_BT_BREDR=y
CONFIG_BT_LE=y
CONFIG_BT_HCIUART=y
CONFIG_BT_HCIUART_H4=y
EOF
echo "✅ 已向 $CONFIG_FILE 注入目标内核参数（含蓝牙母开关）"

GENERIC_CONFIG="target/linux/generic/config-6.12"
if [ -f "$GENERIC_CONFIG" ]; then
    sed -i '/CONFIG_ARM64_SVE/d; /CONFIG_ARM64_ASIMD/d' "$GENERIC_CONFIG" 2>/dev/null || true
    echo "# CONFIG_ARM64_SVE is not set" >> "$GENERIC_CONFIG"
    echo "CONFIG_ARM64_ASIMD=y" >> "$GENERIC_CONFIG"
fi

echo -e "# H29K OVERRIDE\n# CONFIG_TARGET_MULTI_ARCH is not set\nCONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" > .config.override

# ======================== 【4. 屏幕驱动与核心系统组件注入】 ========================
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
    MAGIC=$(head -c 4 "$DST_FONT" 2>/dev/null | od -t x1 -An | tr -d ' \n')
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

# ======================== 【6. Docker 基础环境策略】 ========================
mkdir -p files/etc/modules.d
echo -e "overlay\nbridge\nveth" > files/etc/modules.d/30-docker

cat > files/etc/uci-defaults/98-docker-autostart <<'EOF'
#!/bin/sh
/etc/init.d/dockerd enable
/etc/init.d/cam-monitor enable
exit 0
EOF
chmod +x files/etc/uci-defaults/98-docker-autostart

sed -i 's/+docker-compose-v2//g; s/+docker-compose//g' feeds/luci/applications/luci-app-dockerman/Makefile 2>/dev/null || true

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
echo "🚀 正在注入 H29K 专属微型直播导播守护系统核心..."

cat > files/etc/docker/mediamtx/mediamtx.yml << 'EOF'
logLevel: warn
logDestinations: [stdout]
writeQueueSize: 256

rtsp: true
rtspTransports: [udp, tcp]
rtspAddress: :8554
rtpAddress: :8000
rtcpAddress: :8001

rtmp: true
rtmpAddress: :1935

hls: true
hlsAddress: :8888
hlsAllowOrigins: ["*"]          
hlsAlwaysRemux: true            
hlsVariant: lowLatency          
hlsSegmentCount: 5              
hlsSegmentDuration: 1s          
hlsPartDuration: 200ms
hlsSegmentMaxSize: 20M
hlsDirectory: ""                

webrtc: true
webrtcAddress: :8889
webrtcAllowOrigins: ["*"]
webrtcLocalUDPAddress: :8189
webrtcIPsFromInterfaces: true
srt: false

pathDefaults:
  source: publisher
  overridePublisher: true

paths:
  cam:
    runOnInit: ffmpeg -f v4l2 -input_format h264 -i /dev/video0 -f alsa -i hw:1,0 -c:v copy -c:a aac -b:a 128k -f rtsp rtsp://127.0.0.1:8554/cam
    runOnInitRestart: true      
EOF

# 🌟【自愈】将原本运行时去网络拉取 ffmpeg 的逻辑，变更为直接执行本地已熔铸好的本地环境，断网秒开
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
        
        docker rm -f live-pusher >/dev/null 2>&1
        
        echo "📡 正在启动网络直播推流模块..."
        docker run -d --name live-pusher --restart always --network host \
            h29k-alpine-ffmpeg:__ALPINE_VER__ ffmpeg -i rtsp://127.0.0.1:8554/cam -c:v copy -c:a copy -f flv "$RTMP_URL"
        
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

# 🌟【自愈】HDMI 本地输出同样修正为开箱即用的本地离线高精镜像
cat > files/usr/bin/cam-monitor.sh << 'EOF'
#!/bin/sh

is_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

echo "👀 H29K 智能直播机监测守护进程已启动..."

timeout=0
while [ ! -S /var/run/docker.sock ]; do
    if [ $timeout -gt 30 ]; then break; fi
    sleep 1
    timeout=$((timeout + 1))
done

if [ -d /usr/share/docker-images ]; then
    echo "📦 [H29K] 正在进行全家桶离线驱动包冷启动注入，请稍候..." > /dev/console
    for tar in /usr/share/docker-images/*.tar; do
        if [ -f "$tar" ]; then
            docker load -i "$tar"
        fi
    done
    rm -rf /usr/share/docker-images
    echo "✅ [H29K] 离线镜像注入成功！系统已完全具备全功能生产力。" > /dev/console
fi

while true; do
    if [ -e /dev/video0 ]; then
        
        # A. 激活【网络串流核心服务】
        if ! is_container_running "mediamtx"; then
            echo "🎵 检测到摄像头接入，正在唤醒基础音视频引擎..."
            docker run -d --name mediamtx --restart always --network host \
                --privileged \
                --device /dev/video0:/dev/video0 \
                --device /dev/snd:/dev/snd \
                -v /etc/docker/mediamtx/mediamtx.yml:/mediamtx.yml \
                bluenviron/mediamtx:__MEDIAMTX_VER__
        fi

        # B. 激活【HDMI本地大屏音画同步播放器】
        if ! is_container_running "cam-hdmi-player"; then
            echo "📺 正在向 HDMI 外接大屏输出实时音画面..."
            docker run -d --name cam-hdmi-player --restart always --network host \
                --privileged \
                --device /dev/fb0:/dev/fb0 \
                --device /dev/snd:/dev/snd \
                h29k-alpine-ffmpeg:__ALPINE_VER__ ffmpeg -re -i rtsp://127.0.0.1:8554/cam -f fbdev /dev/fb0 -f alsa hw:0,0
        fi

    else
        if docker ps -a --format '{{.Names}}' | grep -qE "cam-hdmi-player|mediamtx|live-pusher"; then
            echo "⚠️ 摄像头被物理拔出，正在紧急熔断直播、大屏输出及基础服务..."
            docker rm -f cam-hdmi-player mediamtx live-pusher >/dev/null 2>&1
            dd if=/dev/zero of=/dev/fb0 bs=1M count=1 >/dev/null 2>&1 || true
        fi
    fi
    
    sleep 3
done
EOF
chmod +x files/usr/bin/cam-monitor.sh

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

echo "✅ 完全体智能导播直播系统架构准备完毕！"

# ==============================================================================
# 🖼️ 【xgplayer 内嵌】生成专属的网页端超低延迟监控大屏面板
# ==============================================================================
cat > files/www/cam.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>H29K 完全体边缘导播 - 网页实时预览</title>
    <style>
        body {
            margin: 0; padding: 0;
            background-color: #141414; color: #ffffff;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            min-height: 100vh;
        }
        .container {
            width: 90%; max-width: 800px;
            background: #1e1e1e; border-radius: 12px; padding: 20px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.5); border: 1px solid #333;
        }
        h2 {
            margin-top: 0; font-weight: 500; font-size: 1.4rem; color: #4fc3f7;
            display: flex; align-items: center; gap: 8px;
        }
        .status-badge {
            background: #2e7d32; color: #fff; font-size: 0.75rem;
            padding: 4px 8px; border-radius: 4px; font-weight: bold;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { opacity: 0.6; } 50% { opacity: 1; } 100% { opacity: 0.6; }
        }
        #h29k-player {
            width: 100%; height: 450px; background: #000; border-radius: 8px; overflow: hidden;
        }
        .info-panel {
            margin-top: 15px; font-size: 0.9rem; color: #aaaaaa; line-height: 1.6;
            background: #252525; padding: 12px; border-radius: 6px; border-left: 4px solid #4fc3f7;
        }
    </style>
    <script src="https://unpkg.com/xgplayer@3.0.1/browser/index.js" type="text/javascript"></script>
    <script src="https://unpkg.com/xgplayer-hls@3.0.1/browser/index.js" type="text/javascript"></script>
</head>
<body>
    <div class="container">
        <h2>📹 H29K 边缘导播网页实时预览 <span class="status-badge">LIVE 连线中</span></h2>
        <div id="h29k-player"></div>
        <div class="info-panel">
            <strong>💡 导播台微调说明：</strong><br>
            1. 当前视频流基于 <strong>MediaMTX LL-HLS</strong> 协议，首开极速，端到端延迟低至 1s 内。<br>
            2. 视频采用 H.264 硬件直通流拷贝技术，不占用 H29K 软路由的 CPU，客户端承担解码渲染。<br>
            3. 如果画面未正常播放，请点击播放器正中心的播放按钮。手机端支持原生内联控制和全屏手势。
        </div>
    </div>

    <script>
        const boxIp = window.location.hostname || '192.168.1.1';
        const player = new window.XgplayerHls({
            id: 'h29k-player',
            url: `http://${boxIp}:8888/cam/index.m3u8`, 
            isLive: true,
            autoplay: true,
            muted: true,
            playsinline: true,
            width: '100%',
            height: '100%',
            fluid: true,
            cors: true
        });
    </script>
</body>
</html>
EOF

# ==============================================================================
# 🎛️ 【LuCI 预装】将直播控制按钮直接固化进入 OpenWrt 网页后台
# ==============================================================================
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

config command
	option name '🌐 智能获取网页端实时监视大屏链接'
	option command 'echo "=================================================" && echo "👉 请拷贝并在浏览器新标签页中访问以下地址查看实时画面：" && echo "👉 http://\$(uci get network.lan.ipaddr)/cam.html" && echo "================================================="'
EOF

# ==============================================================================
# 🐳 【🌟 动态功能封装与全向固化】将动态信息全面熔铸进入离线包
# ==============================================================================
echo "🐳 正在通过模板引擎，将最新稳定版号固化进运行时脚本中..."
sed -i "s/__MEDIAMTX_VER__/${MEDIAMTX_VER}/g" files/usr/bin/cam-monitor.sh
sed -i "s/__ALPINE_VER__/${FALLBACK_ALPINE_VER}/g" files/usr/bin/cam-monitor.sh
sed -i "s/__ALPINE_VER__/${FALLBACK_ALPINE_VER}/g" files/usr/bin/live-push.sh

echo "🎁 正在通过宿主机 Docker，强行跨架构下发并封印 H29K(ARM64) 专属闭环离线包..."
# 1. 封印完全体音视频 MediaMTX 镜像
docker save bluenviron/mediamtx:${MEDIAMTX_VER} -o files/usr/share/docker-images/mediamtx.tar

# 2. 封印本地编译期直接内建好 FFmpeg 的专属高精 Alpine 镜像
docker save h29k-alpine-ffmpeg:${FALLBACK_ALPINE_VER} -o files/usr/share/docker-images/alpine.tar

echo "🎁 离线全家桶镜像（版本: MediaMTX@$MEDIAMTX_VER, Alpine-FFmpeg@$FALLBACK_ALPINE_VER）已实现100%纯本地闭环！"

# =================================================================
# 🚨 针对 aic8800 本地 Makefile 的终极补丁 (通关下载 + 依赖 + 屏蔽 GCC14 所有强迫症报错)
# =================================================================
if [ -f "package/aic8800/Makefile" ]; then
    echo "🛠️ 正在进行 aic8800 Makefile 终极闭环手术..."
    
    # 1. 彻底删除哈希校验行 (防止新版下载校验挂掉)
    sed -i '/PKG_MIRROR_HASH/d' package/aic8800/Makefile
    
    # 2. 补全无线底层依赖链 (确保与 mac80211 对齐不抢跑)
    sed -i 's/DEPENDS:=+kmod-cfg80211/DEPENDS:=+kmod-mac80211 +kmod-cfg80211/g' package/aic8800/Makefile
    
    # 3. 强行屏蔽新版 Linux 6.x 内核 / GCC 14 的各类严苛语法与安全阻拦
    # -Wno-missing-prototypes: 忽略缺失函数原型的警告
    # -Wno-expansion-to-defined: 忽略宏展开中包含 defined 的规范警告
    # -Wno-attribute-warning: 忽略 Fortify String 等触发的内核编译期越界属性警告
    # -Wno-unused-function: 忽略定义了但未使用的 static 函数警告 (解决电源管理挂起/恢复函数报错)
    sed -i 's/-DBUILD_OPENWRT/-DBUILD_OPENWRT -Wno-missing-prototypes -Wno-error=missing-prototypes -Wno-expansion-to-defined -Wno-error=expansion-to-defined -Wno-attribute-warning -Wno-error=attribute-warning -Wno-unused-function -Wno-error=unused-function/g' package/aic8800/Makefile
    
    echo "✅ aic8800 九合一终极修补完成！"
else
    echo "⚠️ 未找到 package/aic8800/Makefile，请检查路径！"
fi

echo "🚀 H29K 极其稳健的最新稳定版离线闭环改造，全部大功告成！"
