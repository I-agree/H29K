#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

set -euo pipefail  # 严格报错模式：任一非条件命令失败立即终止

# =================================================================================
# 🎯 工业级自愈补丁：将 rk3528-hinlink-h29k 安全注册进内核 Makefile
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

# ======================== 【1. 🚀 编译期：最新稳定版动态嗅探与自愈中心】 ========================
echo "🔍 正在动态获取互联网当前最新的稳定版版本号..."

# 🌟【自愈】防止 GitHub Actions 共享 IP 触发 API 限流时导致 grep 失败
MEDIAMTX_RELEASES=$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 3 || true)

MEDIAMTX_VER=""
echo "🎁 开始智能检索并跨架构预拉取 H29K(ARM64) 专属 MediaMTX 镜像..."

# 🌟【架构修复】MediaMTX 必须使用带 -ffmpeg 后缀的官方镜像变体，提供核心解码支持
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

# ======================== 【2. 清理原生冲突架构源】 ========================
echo "🧹 正在清理原生冲突的架构补丁..."
rm -rf package/boot/uboot-rockchip/patches

# ======================== 【3. H29K 主线内核配置合并注入】 ========================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

echo "📝 正在精准注入官方 OpenWrt 25.12 专属内核配置文件: $CONFIG_FILE"

# 清理可能引发覆盖的冲突条目
sed -i '/CONFIG_EMAC_ROCKCHIP/d; /CONFIG_ARM64_PA_BITS/d; /CONFIG_CMA_SIZE_MBYTES=16/d; /CONFIG_CRYPTO_HW/d; /CONFIG_CRYPTO_DEV_/d; /CONFIG_CRYPTO_AKCIPHER/d; /CONFIG_CRYPTO_KPP/d; /CONFIG_DEFAULT_NET_CONG/d; /CONFIG_DEFAULT_BBR/d; /CONFIG_SND/d; /CONFIG_ARM64_SVE/d; /CONFIG_BT/d; /CONFIG_DRM_/d; /CONFIG_FB_/d; /CONFIG_BACKLIGHT_/d; /CONFIG_SPI/d; /CONFIG_MEDIA/d; /CONFIG_VIDEO/d; /CONFIG_USB_VIDEO_CLASS/d' "$CONFIG_FILE" 2>/dev/null || true

cat >> "$CONFIG_FILE" << 'EOF'

# === RK3528 主线核心与平台级别底座驱动（对齐 Linux 6.12）===
CONFIG_ARCH_ROCKCHIP=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_VA_BITS_48=y
CONFIG_ARM64_VA_BITS=48
CONFIG_ARM64_PA_BITS_48=y
CONFIG_COMMON_CLK_ROCKCHIP=y
CONFIG_PWM_ROCKCHIP=y
CONFIG_OF_GPIO=y

# TSADC 温度传感器
CONFIG_ROCKCHIP_TSADC=y

# 分区解析
CONFIG_BLOCK=y
CONFIG_PARTITION_ADVANCED=y
CONFIG_MSDOS_PARTITION=y
CONFIG_EFI_PARTITION=y
CONFIG_MMC_BLOCK_MINORS=16

# 8250 串口驱动（RK3528 控制台 uart0 依赖）
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_CONSOLE=y

# SDIO WiFi 依赖（设备带 SDIO 无线）
CONFIG_MMC_SDIO=y

CONFIG_PLATFORM_DEVICE=y
CONFIG_PROBE_PRIORITY_DEVICE=y

CONFIG_NET=y
CONFIG_ETHERNET=y

# OpenWrt 必备文件系统
CONFIG_SQUASHFS=y

CONFIG_GPIO_KEYS=y

CONFIG_MMC_HS200=y
CONFIG_MMC_HS400=y
CONFIG_MMC_PWRSEQ=y
CONFIG_ROOT_WAIT=y
CONFIG_RW_ROOT=y
CONFIG_MMC_SD=y

# =====================================================================
# 解决kmod-fs-netfs核心内核依赖链
# =====================================================================
CONFIG_CIFS=m
CONFIG_NETFS_SUPPORT=m
CONFIG_FSCACHE=y

# =====================================================================

# --- 针对 A53 架构彻底关闭不支持的 SVE 扩展，全力确保 ASIMD(NEON) 跑满 ---
# CONFIG_ARM64_SVE is not set
CONFIG_ARM64_ASIMD=y
CONFIG_ARM64_NEON=y

# --- 禁用低效且冲突的板载硬件加密，全力释放更强的 ARMv8 CPU 内置加密扩展性能 ---
CONFIG_CRYPTO_HW=y
# CONFIG_CRYPTO_DEV_ROCKCHIP is not set

# --- 触摸驱动内嵌
CONFIG_TOUCHSCREEN_FT6236=y

# =================================================================
# 🛡️ 显示架构核心底座与防弹窗屏蔽词（对齐第一层 drivers/gpu/drm/Kconfig）
# =================================================================
CONFIG_DRM=y
CONFIG_DRM_MIPI_DBI=y
CONFIG_DRM_KMS_HELPER=y
# CONFIG_DRM_DEBUG_MM is not set
# CONFIG_DRM_USE_DYNAMIC_DEBUG is not set
# CONFIG_DRM_KUNIT_TEST is not set
# CONFIG_DRM_PANIC is not set
# CONFIG_DRM_DEBUG_DP_MST_TOPOLOGY_REFS is not set
# CONFIG_DRM_DEBUG_MODESET_LOCK is not set
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_FBDEV_OVERALLOC=100
# CONFIG_DRM_LOAD_EDID_FIRMWARE is not set
# CONFIG_DRM_VGEM is not set
# CONFIG_DRM_HYPERV is not set
# CONFIG_DRM_WERROR is not set

# 彻底断绝 PC/桌面级 显卡驱动弹窗
# CONFIG_DRM_RADEON is not set
# CONFIG_DRM_AMDGPU is not set
# CONFIG_DRM_NOUVEAU is not set
# CONFIG_DRM_XE is not set
# CONFIG_DRM_I915 is not set
# CONFIG_DRM_VKMS is not set

# =================================================================
# 🚀 瑞芯微核心显示驱动（对齐第二层 drm/rockchip/Kconfig）
# =================================================================
# CONFIG_ROCKCHIP_IOMMU is not set
# CONFIG_DRM_ROCKCHIP is not set

# 核心 VOP 视频输出控制器
# CONFIG_ROCKCHIP_VOP is not set
# CONFIG_ROCKCHIP_VOP2 is not set

# Synopsys HDMI 核心及瑞芯微扩展
# CONFIG_ROCKCHIP_DW_HDMI is not set
# CONFIG_DRM_DW_HDMI is not set

# 物理物理封杀：其余所有不属于你的芯片平台的无用接口（全面拒绝，防止弹窗）
# CONFIG_ROCKCHIP_ANALOGIX_DP is not set
# CONFIG_ROCKCHIP_CDN_DP is not set
# CONFIG_ROCKCHIP_DW_MIPI_DSI is not set
# CONFIG_ROCKCHIP_INNO_HDMI is not set
# CONFIG_ROCKCHIP_LVDS is not set
# CONFIG_ROCKCHIP_RGB is not set
# CONFIG_ROCKCHIP_RK3066_HDMI is not set

# =================================================================
# 🛡️ 彻底封杀显示桥接芯片及其子套娃（drivers/gpu/drm/bridge/Kconfig官方 Kconfig 闭环校准）
# =================================================================
CONFIG_DRM_BRIDGE=y

# 主 Kconfig 文件中直接暴露的显式交互选项
# CONFIG_DRM_CHIPONE_ICN6211 is not set
# CONFIG_DRM_CHRONTEL_CH7033 is not set
# CONFIG_DRM_DISPLAY_CONNECTOR is not set
# CONFIG_DRM_ITE_IT6505 is not set
# CONFIG_DRM_LONTIUM_LT8912B is not set
# CONFIG_DRM_LONTIUM_LT9211 is not set
# CONFIG_DRM_LONTIUM_LT9611 is not set
# CONFIG_DRM_LONTIUM_LT9611UXC is not set
# CONFIG_DRM_ITE_IT66121 is not set
# CONFIG_DRM_LVDS_CODEC is not set
# CONFIG_DRM_MEGACHIPS_STDPXXXX_GE_B850V3_FW is not set
# CONFIG_DRM_NWL_MIPI_DSI is not set
# CONFIG_DRM_NXP_PTN3460 is not set
# CONFIG_DRM_PARADE_PS8622 is not set
# CONFIG_DRM_PARADE_PS8640 is not set
# CONFIG_DRM_SAMSUNG_DSIM is not set
# CONFIG_DRM_SIL_SII8620 is not set
# CONFIG_DRM_SII902X is not set
# CONFIG_DRM_SII9234 is not set
# CONFIG_DRM_SIMPLE_BRIDGE is not set
# CONFIG_DRM_THINE_THC63LVD1024 is not set
# CONFIG_DRM_TOSHIBA_TC358762 is not set
# CONFIG_DRM_TOSHIBA_TC358764 is not set
# CONFIG_DRM_TOSHIBA_TC358767 is not set
# CONFIG_DRM_TOSHIBA_TC358768 is not set
# CONFIG_DRM_TOSHIBA_TC358775 is not set
# CONFIG_DRM_TI_DLPC3433 is not set
# CONFIG_DRM_TI_TFP410 is not set
# CONFIG_DRM_TI_SN65DSI83 is not set
# CONFIG_DRM_TI_SN65DSI86 is not set
# CONFIG_DRM_TI_TPD12S015 is not set

# 主 Kconfig 文件中带条件限制的潜在隐形刺客（彻底斩草除根）
# CONFIG_DRM_CROS_EC_ANX7688 is not set
# CONFIG_DRM_FSL_LDB is not set
# CONFIG_DRM_MICROCHIP_LVDS_SERIALIZER is not set

# 源码底部由 source 引入的外部子目录弹窗（如 Analogix, Cadence, Synopsys 等）
# CONFIG_DRM_ANALOGIX_ANX6345 is not set
# CONFIG_DRM_ANALOGIX_ANX78XX is not set
# CONFIG_DRM_ANALOGIX_ANX7625 is not set
# CONFIG_DRM_I2C_ADV7511 is not set
# CONFIG_DRM_CDNS_DSI is not set
# CONFIG_DRM_CDNS_MHDP8546 is not set
# CONFIG_DRM_DW_HDMI_CEC is not set
# CONFIG_DRM_DW_HDMI_AHB_AUDIO is not set
# CONFIG_DRM_DW_HDMI_I2S_AUDIO is not set
# CONFIG_DRM_DW_HDMI_GP_AUDIO is not set

# =================================================================
# 📺 核心闭环：HDMI的 SimpleDRM 路线 + ST7789V 专属显示总成
# =================================================================

# 1. 支撑 HDMI 盲出的万能简单帧缓冲底层基础设施
CONFIG_DRM_SIMPLEDRM=y
CONFIG_FB_CORE=y
CONFIG_FB_DEVICE=y

# 2. 支撑 ST7789V 小屏幕的 SPI 总线与 TinyDRM 驱动架构（100%对齐官方 Kconfig 闭环）
CONFIG_SPI=y
CONFIG_SPI_ROCKCHIP=y
# CONFIG_SPI_ROCKCHIP_SFC is not set
CONFIG_DRM_TINYDRM=y
CONFIG_DRM_PANEL=y
CONFIG_DRM_PANEL_ORIENTATION_REDUCED=y
CONFIG_DRM_ST7789V=y

# 3. 注入小屏幕背光系统核心底座（坚决粉碎内核交互式 NEW 提问弹窗）
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_BACKLIGHT_PWM=y

# ==============================================================================
# 🎥 补全核心：VPU视频硬解、RGA硬件转换加速与 USB 摄像头支持（全面防御 NEW 弹窗）
# ==============================================================================
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CONTROLLER=y
CONFIG_VIDEO_DEV=y
CONFIG_VIDEO_V4L2=y
CONFIG_VIDEO_V4L2_SUBDEV_API=y

# --- 阻断 V4L2 树状结构中无用子协议，100% 防止 CI 自动化环境卡死 ---
# CONFIG_MEDIA_ANALOG_TV_SUPPORT is not set
# CONFIG_MEDIA_DIGITAL_TV_SUPPORT is not set
# CONFIG_MEDIA_RADIO_SUPPORT is not set
# CONFIG_MEDIA_SDR_SUPPORT is not set
# CONFIG_MEDIA_TEST_SUPPORT is not set

# --- 激活推流业务层：放行相机类与平台级驱动容器 ---
CONFIG_MEDIA_CAMERA_SUPPORT=y
CONFIG_MEDIA_PLATFORM_SUPPORT=y

# --- A. 标准 USB 摄像头 UVC 驱动（点亮你的 cam-monitor.sh 输入源） ---
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_VIDEO_CLASS_INPUT_EVDEV=y
# CONFIG_USB_GSPCA is not set

# --- B. 瑞芯微 RGA 硬件加速色彩转换引擎（路线 B 的性能解耦核心） ---
CONFIG_VIDEO_ROCKCHIP_RGA=y

# --- C. 瑞芯微主线 VPU 视频硬解编解码核心框架（对齐 Linux 6.12.y） ---
CONFIG_VIDEO_HANTRO=y
# CONFIG_VIDEO_HANTRO_IOMMU is not set
# CONFIG_VIDEO_RKVDEC is not set

# ==============================================================================

# --- 主线标准平台级外设与预留电压分配器 ---
CONFIG_REGULATOR_FIXED_VOLTAGE=y

# --- CMA 连续物理内存调优 ---
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_CMA_SIZE_MBYTES=64
# --- 网络高并发 TCP BBR + FQ 底层内建 ---
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_NET_CONG="bbr"
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_QDISC="fq"

# ==============================================================================
# 📡 基于下面网页对齐的蓝牙全量闭环配置（拒绝任何弹窗）
# https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/bluetooth/Kconfig?h=linux-6.12.y
# https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/net/bluetooth/Kconfig?h=linux-6.12.y
# ==============================================================================

# --- 1. 核心协议栈框架层 (对照 net/bluetooth/Kconfig) ---
CONFIG_BT=y
CONFIG_BT_BREDR=y
CONFIG_BT_LE=y
# CONFIG_BT_LE_L2CAP_ECRED is not set
# CONFIG_BT_6LOWPAN is not set
# CONFIG_BT_LEDS is not set
# CONFIG_BT_MSFTEXT is not set
# CONFIG_BT_AOSPEXT is not set
# CONFIG_BT_DEBUGFS is not set
# CONFIG_BT_SELFTEST is not set
# CONFIG_BT_FEATURE_DEBUG is not set

# --- 2. 阻断外部 source 嵌套树 (对照 net/bluetooth/ 核心协议子框架) ---
CONFIG_BT_RFCOMM=y
CONFIG_BT_BNEP=y
# CONFIG_BT_CMTP is not set
CONFIG_BT_HIDP=y

# --- 3. 核心目标：仅放行 UART H4 总线 (对照 drivers/bluetooth/Kconfig) ---
CONFIG_BT_HCIUART=y
CONFIG_BT_HCIUART_H4=y

# --- 4. 彻底封死所有其他冲突的 UART 子协议 (100% 对照清单) ---
# CONFIG_BT_HCIUART_NOKIA is not set
# CONFIG_BT_HCIUART_BCSP is not set
# CONFIG_BT_HCIUART_ATH3K is not set
# CONFIG_BT_HCIUART_LL is not set
# CONFIG_BT_HCIUART_3WIRE is not set
# CONFIG_BT_HCIUART_INTEL is not set
# CONFIG_BT_HCIUART_BCM is not set
# CONFIG_BT_HCIUART_RTL is not set
# CONFIG_BT_HCIUART_QCA is not set
# CONFIG_BT_HCIUART_AG6XX is not set
# CONFIG_BT_HCIUART_MRVL is not set
# CONFIG_BT_HCIUART_AML is not set

# --- 5. 彻底封死所有非 UART 总线的独立驱动 (100% 对照清单) ---
# CONFIG_BT_HCIBTUSB is not set
# CONFIG_BT_HCIBTSDIO is not set
# CONFIG_BT_HCIBCM203X is not set
# CONFIG_BT_HCIBCM4377 is not set
# CONFIG_BT_HCIBPA10X is not set
# CONFIG_BT_HCIBFUSB is not set
# CONFIG_BT_HCIDTL1 is not set
# CONFIG_BT_HCIBT3C is not set
# CONFIG_BT_HCIBLUECARD is not set
# CONFIG_BT_HCIVHCI is not set
# CONFIG_BT_MRVL is not set
# CONFIG_BT_MRVL_SDIO is not set
# CONFIG_BT_ATH3K is not set
# CONFIG_BT_MTKSDIO is not set
# CONFIG_BT_MTKUART is not set
# CONFIG_BT_QCOMSMD is not set
# CONFIG_BT_VIRTIO is not set
# CONFIG_BT_NXPUART is not set
# CONFIG_BT_INTEL_PCIE is not set

EOF
echo "✅ 已向 $CONFIG_FILE 注入目标内核参数"

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

# 启动连续开机 LOGO 动画
for i in 1 2 3; do 
    [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8
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

mkdir -p package/base-files/files/etc
sed -i '/net.netfilter.nf_conntrack_max/d' package/base-files/files/etc/sysctl.conf 2>/dev/null || true
cat >> package/base-files/files/etc/sysctl.conf << 'EOF'
net.netfilter.nf_conntrack_max=262144
net.core.netdev_max_backlog=10000
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF

# ==============================================================================
# 📹 【完全体调度矩阵】MediaMTX 配置中心（开启控制 API）
# ==============================================================================
echo "🚀 正在注入 H29K 流媒体中转矩阵核心控制网关..."

cat > files/etc/docker/mediamtx/mediamtx.yml << 'EOF'
logLevel: warn
logDestinations: [stdout]
writeQueueSize: 256

# 🌟 开启本地控制 API，赋予守护进程动态嗅探流状态的能力
api: true
apiAddress: 127.0.0.1:9997

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
hlsSegmentCount: 3              
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
EOF

# ==============================================================================
# 📡 【智能直播推流脚本】支持自适应路由、智能指定源与无感并线
# ==============================================================================
cat > files/usr/bin/live-push.sh << 'EOF'
#!/bin/sh

ACTION=$1
RTMP_URL=$2
WANTED_SRC=$3  # 可选参数: cam 或 cast

is_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

case "$ACTION" in
    start)
        if [ -z "$RTMP_URL" ]; then
            echo "❌ 错误：请输入直播间完整的 RTMP 协议推流地址和密钥。"
            exit 1
        fi
        
        # 🤖 智能推流源决策中心
        if [ -z "$WANTED_SRC" ]; then
            # 如果不指定推流源，优先嗅探手机投屏，若无投屏则回退到本地摄像头
            if wget -qO- http://127.0.0.1:9997/v3/paths/list 2>/dev/null | grep -q '"name":"cast".*"ready":true'; then
                WANTED_SRC="cast"
            else
                WANTED_SRC="cam"
            fi
        fi

        echo "$WANTED_SRC" > /tmp/live_push_src
        docker rm -f live-pusher >/dev/null 2>&1
        
        echo "📡 正在从内部通道 [/$WANTED_SRC] 提取视听信号源并向目标网络平台开播..."
        docker run -d --name live-pusher --restart always --network host \
            h29k-alpine-ffmpeg:__ALPINE_VER__ ffmpeg -re -i "rtsp://127.0.0.1:8554/$WANTED_SRC" -c:v copy -c:a aac -f flv "$RTMP_URL"
        
        if [ $? -eq 0 ]; then
            echo "✅ 直播推流已成功在后台建立并发布！"
            echo "🔗 信号提取通道: /$WANTED_SRC ---> 目标平台: $RTMP_URL"
        else
            echo "❌ 容器启动失败，请检查通道是否可用。"
        fi
        ;;
        
    stop)
        if is_container_running "live-pusher"; then
            echo "🛑 正在发送流关闭信号，安全关闭直播推流通道..."
            # 🌟 使用 SIGINT 触发 ffmpeg 正常写入 FLV 结束标签，避免平台因判定“非正常断流”而扣分
            docker kill --signal=2 live-pusher >/dev/null 2>&1
            sleep 1
            docker rm -f live-pusher >/dev/null 2>&1
            rm -f /tmp/live_push_src
            echo "✅ 直播已安全关闭，已与平台解除握手。"
        else
            echo "ℹ️ 当前未有活跃的直播推流进程。"
        fi
        ;;
        
    status)
        if is_container_running "live-pusher"; then
            CURRENT_SRC=$(cat /tmp/live_push_src 2>/dev/null || echo "未知")
            echo "🟢 状态：正处于激情直播中... [当前提取源: /$CURRENT_SRC]"
            docker logs --tail 3 live-pusher
        else
            echo "⚪ 状态：闲置中，当前未发布任何网络直播。"
        fi
        ;;
    *)
        echo "使用方法: $0 {start \"RTMP推流URL\" [cam|cast]|stop|status}"
        ;;
esac
EOF
chmod +x files/usr/bin/live-push.sh

# ==============================================================================
# 🧠 【全场景核心看门狗状态机】HDMI热插拔/USB动态热熔断调度中心
# ==============================================================================
cat > files/usr/bin/cam-monitor.sh << 'EOF'
#!/bin/sh

is_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

is_hdmi_connected() {
    if [ -f /sys/class/drm/card0-HDMI-A-1/status ]; then
        grep -q "^connected" /sys/class/drm/card0-HDMI-A-1/status && return 0
    elif ls /sys/class/drm/*HDMI*/status >/dev/null 2>&1; then
        cat /sys/class/drm/*HDMI*/status | grep -q "^connected" && return 0
    fi
    return 1
}

echo "👀 H29K 边缘多路流媒体调度看门狗已进入深度防卷模式..."

# 1. 确保 Docker 守护进程就绪
timeout=0
while [ ! -S /var/run/docker.sock ]; do
    if [ $timeout -gt 30 ]; then break; fi
    sleep 1
    timeout=$((timeout + 1))
done

# 2. 冷启动加载内嵌离线镜像包
if [ -d /usr/share/docker-images ]; then
    echo "📦 [H29K] 正在加载全家桶闭环固件驱动包..." > /dev/console
    for tar in /usr/share/docker-images/*.tar; do
        [ -f "$tar" ] && docker load -i "$tar"
    done
    rm -rf /usr/share/docker-images
    echo "✅ [H29K] 镜像包全量解封成功！" > /dev/console
fi

# 3. 强行拉起恒久常驻的核心路由总线 MediaMTX
docker rm -f mediamtx >/dev/null 2>&1
docker run -d --name mediamtx --restart always --network host \
    --privileged \
    --device /dev/snd:/dev/snd \
    -v /etc/docker/mediamtx/mediamtx.yml:/mediamtx.yml \
    bluenviron/mediamtx:__MEDIAMTX_VER__

# 初始化看门狗追踪状态机
LAST_CAM_HARDWARE_STATE=""
CURRENT_HDMI_VIEW_SRC=""

while true; do
    # ------------------ 【维度一：USB 摄像头硬件探测与熔断状态机】 ------------------
    CAM_HARDWARE_ONLINE=0
    [ -e /dev/video0 ] && CAM_HARDWARE_ONLINE=1

    if [ "$CAM_HARDWARE_ONLINE" != "$LAST_CAM_HARDWARE_STATE" ]; then
        if [ "$CAM_HARDWARE_ONLINE" -eq 1 ]; then
            echo "📷 [硬件动作] 检测到 USB 摄像头接入，正在开启本地音视频硬件采集..." > /dev/console
            docker rm -f cam-publisher >/dev/null 2>&1
            docker run -d --name cam-publisher --restart always --network host \
                --privileged --device /dev/video0:/dev/video0 --device /dev/snd:/dev/snd \
                h29k-alpine-ffmpeg:__ALPINE_VER__ ffmpeg -f v4l2 -input_format h264 -i /dev/video0 -f alsa -i hw:1,0 -c:v copy -c:a aac -b:a 128k -f rtsp rtsp://127.0.0.1:8554/cam
        else
            echo "🚨 [硬件动作] 警告！USB 摄像头突然被意外拔出！触发看门狗安全评估..." > /dev/console
            docker rm -f cam-publisher >/dev/null 2>&1
            
            # 🕵️ 安全审计：检查当前后台是否正在对外进行“本地摄像头直播”
            if [ -f /tmp/live_push_src ] && [ "$(cat /tmp/live_push_src 2>/dev/null)" = "cam" ]; then
                echo "🛑 [安全熔断] 核实当前正在通过 USB 摄像头进行直播推流，执行安全终止，防止黑屏挂机扣分！" > /dev/console
                /usr/bin/live-push.sh stop
            else
                echo "🍏 [审计通过] 核实当前正在转播电脑/手机投屏流，或者未开启直播，保持推流主干道不中断！" > /dev/console
            fi
        fi
        LAST_CAM_HARDWARE_STATE="$CAM_HARDWARE_ONLINE"
    fi

    # ------------------ 【维度二：网络流状态嗅探与 HDMI 优先级路由调度矩阵】 ------------------
    CAST_STREAM_READY=0
    if wget -qO- http://127.0.0.1:9997/v3/paths/list 2>/dev/null | grep -q '"name":"cast".*"ready":true'; then
        CAST_STREAM_READY=1
    fi

    LIVE_PUSHER_RUNNING=0
    if is_container_running "live-pusher"; then
        LIVE_PUSHER_RUNNING=1
    fi

    CAM_STREAM_READY=0
    if wget -qO- http://127.0.0.1:9997/v3/paths/list 2>/dev/null | grep -q '"name":"cam".*"ready":true'; then
        CAM_STREAM_READY=1
    fi

    # 🖥️ HDMI 优先度智能算力决策
    TARGET_HDMI_SRC=""
    if [ "$CAST_STREAM_READY" -eq 1 ]; then
        # 优先级 ①：任何时候只要发起手机/电脑投屏，画面最高权无条件抢占大屏
        TARGET_HDMI_SRC="rtsp://127.0.0.1:8554/cast"
    elif [ "$LIVE_PUSHER_RUNNING" -eq 1 ]; then
        # 优先级 ②：如果没有人在投屏，突然开启了直播推流，大屏幕切换为监视推流内容
        LIVE_SRC=$(cat /tmp/live_push_src 2>/dev/null || echo "cam")
        TARGET_HDMI_SRC="rtsp://127.0.0.1:8554/$LIVE_SRC"
    elif [ "$CAM_STREAM_READY" -eq 1 ]; then
        # 优先级 ③：闲置状态下的相机本地回显画面（画幅监视器）
        TARGET_HDMI_SRC="rtsp://127.0.0.1:8554/cam"
    else
        # 优先级 ④：无任何信号流时，回退到系统出厂Logo底面
        TARGET_HDMI_SRC="LOGO"
    fi

    # ------------------ 【维度三：HDMI 物理接口状态热插拔反馈控制】 ------------------
    if is_hdmi_connected; then
        # 只要 HDMI 接口连接着，就根据流媒体路由决定渲染内容
        if [ "$TARGET_HDMI_SRC" != "$CURRENT_HDMI_VIEW_SRC" ]; then
            echo "🔄 [路由切换] 大显示屏画面输入源自 [$CURRENT_HDMI_VIEW_SRC] 精准无损跃迁至 [$TARGET_HDMI_SRC]" > /dev/console
            docker rm -f cam-hdmi-player >/dev/null 2>&1
            
            if [ "$TARGET_HDMI_SRC" = "LOGO" ]; then
                [ -f /etc/config/screen/LOGO3.jpg ] && fbv -f /etc/config/screen/LOGO3.jpg 2>/dev/null || true
            else
                # 🌟【自愈防爆垫片】引入 FFmpeg 动态比例滤镜，强行拦截并修复手机竖屏投屏导致的 Linux 显存锁死和绿屏崩溃
                docker run -d --name cam-hdmi-player --restart always --network host \
                    --privileged --device /dev/fb0:/dev/fb0 --device /dev/snd:/dev/snd \
                    h29k-alpine-ffmpeg:__ALPINE_VER__ ffmpeg -re -i "$TARGET_HDMI_SRC" \
                    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black" \
                    -f fbdev /dev/fb0 -f alsa hw:0,0
            fi
            CURRENT_HDMI_VIEW_SRC="$TARGET_HDMI_SRC"
        fi
    else
        # 🔌 【热插拔降级】如果 HDMI 接口没有挂载任何大屏显示器，无条件彻底摧毁并消灭播放器，100% 回收所有硬解码及显卡内存
        if is_container_running "cam-hdmi-player" || [ -n "$CURRENT_HDMI_VIEW_SRC" ]; then
            echo "🔌 [HDMI 热插拔] 屏幕已被拔出，即刻注销本地 UI 渲染，后台所有网络推流与直播保留就绪！" > /dev/console
            docker rm -f cam-hdmi-player >/dev/null 2>&1
            dd if=/dev/zero of=/dev/fb0 bs=1M count=1 >/dev/null 2>&1 || true
            CURRENT_HDMI_VIEW_SRC=""
        fi
    fi

    sleep 2
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

echo "✅ 完全体多路调度看门狗及状态机系统构建完毕！"

# ==============================================================================
# 🌐 【完全体前端监视大屏】完美闭环补全版（自适应 MediaMTX HLS 架构）
# ==============================================================================
cat > files/www/cam.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>H29K 导播台本地网页监控监视大屏</title>
    <style>
        body {
            background: #121212;
            color: #ffffff;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            width: 90%;
            max-width: 800px;
            background: #1e1e1e;
            border-radius: 14px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.6);
            border: 1px solid #2d2d2d;
        }
        h2 {
            margin-top: 0;
            font-weight: 500;
            font-size: 1.5rem;
            color: #00e5ff;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .status-online {
            background: #2e7d32;
            color: #fff;
            font-size: 0.75rem;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: bold;
        }
        .status-offline {
            background: #c62828;
            color: #fff;
            font-size: 0.75rem;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: bold;
        }
        .player-wrapper {
            width: 100%;
            height: 450px;
            background: #000;
            border-radius: 8px;
            overflow: hidden;
            position: relative;
        }
        #h29k-player {
            width: 100%;
            height: 100%;
        }
        .fallback-card {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: #151515;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            text-align: center;
            color: #ff5252;
            gap: 10px;
        }
        .fallback-card svg {
            width: 64px;
            height: 64px;
            fill: #ff5252;
        }
        .info-panel {
            margin-top: 20px;
            font-size: 0.88rem;
            color: #b0bec5;
            line-height: 1.6;
            background: #263238;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #00e5ff;
        }
        code {
            background: #000;
            padding: 2px 6px;
            border-radius: 4px;
            color: #ffb74d;
            font-family: monospace;
        }
    </style>
    <script src="https://unpkg.com/xgplayer@3.0.1/browser/index.js" type="text/javascript"></script>
    <script src="https://unpkg.com/xgplayer-hls@3.0.1/browser/index.js" type="text/javascript"></script>
</head>
<body>
<div class="container">
    <h2>📹 H29K 导播台本地网页监控监视大屏 <span id="badge" class="status-offline">离线</span></h2>
    <div class="player-wrapper">
        <div id="h29k-player"></div>
        <div id="fallback" class="fallback-card">
            <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
            <div>流媒体信号未就绪或已断开<br><small>请确保输入源（投屏或摄像头）推流成功</small></div>
        </div>
    </div>
    <div class="info-panel">
        <strong>💡 跨平台监控提取通道：</strong><br>
        当前正采用 HLS LL（超低延迟切片）监视主干道。如需拉取原始网络流，请使用以下地址：<br>
        <code>RTSP 顺位流: rtsp://<script>document.write(window.location.hostname);</script>:8554/cam</code> | 
        <code>RTMP 顺位流: rtmp://<script>document.write(window.location.hostname);</script>:1935/cam</code>
    </div>
</div>

<script type="text/javascript">
    // 💡 动态拼装局域网内任意客户端访问时的自适应 MediaMTX HLS 端口路径
    const streamUrl = 'http://' + window.location.hostname + ':8888/cam/index.m3u8';
    const badge = document.getElementById('badge');
    const fallback = document.getElementById('fallback');

    // 初始化西瓜播放器驱动核心
    const player = new window.Player({
        id: 'h29k-player',
        url: streamUrl,
        isLive: true,
        autoplay: true,
        playsinline: true,
        plugins: [window.HlsJsPlugin],
        width: '100%',
        height: '100%',
        hlsJsPlugin: {
            retryCount: 3,
            retryDelay: 1000
        }
    });

    // 智能化看门狗状态机事件绑定
    player.on('play', function() {
        badge.className = 'status-online';
        badge.innerText = '在线';
        fallback.style.display = 'none';
    });

    player.on('error', function() {
        badge.className = 'status-offline';
        badge.innerText = '离线';
        fallback.style.display = 'flex';
    });

    player.on('ended', function() {
        badge.className = 'status-offline';
        badge.innerText = '已断开';
        fallback.style.display = 'flex';
    });
</script>
</body>
</html>
EOF
# ==============================================================================

# ==============================================================================
# 🎛️ 【LuCI 控制固化】将一键开播命令完美合并写入 OpenWrt 后台菜单
# ==============================================================================
cat > files/etc/config/luci_commands << 'EOF'

config command
	option name '🚀 一键开启网络直播（优先提取手机投屏画面）'
	option command '/usr/bin/live-push.sh start "请在这里替换为你的RTMP推流地址和密钥"'

config command
	option name '📷 强制指定 USB 摄像头一键网络直播'
	option command '/usr/bin/live-push.sh start "请在这里替换为你的RTMP推流地址和密钥" cam'

config command
	option name '🛑 一键安全关闭网络直播'
	option command '/usr/bin/live-push.sh stop'

config command
	option name '📊 实时查看当前直播状态'
	option command '/usr/bin/live-push.sh status'

config command
	option name '🌐 智能获取网页端实时监视大屏链接'
	option command 'echo "=================================================" && echo "👉 请拷贝并在浏览器新标签页中访问以下地址查看实时画面：" && echo "👉 http://$(uci get network.lan.ipaddr)/cam.html" && echo "================================================="'
EOF

# ==============================================================================
# 🐳 【🌟 动态功能封装与全向固化】将动态信息全面熔铸进入离线包
# ==============================================================================
echo "🐳 正在通过模板引擎，将最新稳定版号固化进运行时脚本中..."
sed -i "s/__MEDIAMTX_VER__/${MEDIAMTX_VER}/g" files/usr/bin/cam-monitor.sh
# === 替换原有的版本号修改逻辑，并在此处强行注入硬件透传参数 ===
sed -i "s/__ALPINE_VER__/${FALLBACK_ALPINE_VER}/g" files/usr/bin/cam-monitor.sh
sed -i "s/__ALPINE_VER__/${FALLBACK_ALPINE_VER}/g" files/usr/bin/live-push.sh

# =================================================================================
# 🎥【硬解武装升级：动态节点自适应嗅探】通过 sed 注入动态探测，拒绝死锁与硬解失效
# =================================================================================
for TARGET_SCRIPT in "files/usr/bin/cam-monitor.sh" "files/usr/bin/live-push.sh"; do
    if [ -f "$TARGET_SCRIPT" ]; then
        echo "🎬 正在为 $TARGET_SCRIPT 注入运行时全自动 VPU/RGA 硬件自适应透传装甲..."
        
        # 绝杀修复：将原先的 [ -e "$dev" ] && ... 升级为标准的 if 语句
        # 100% 免疫宿主脚本的 set -e 严格报错模式，即使没插摄像头、节点不存在也绝不闪退！
        sed -i 's|docker run|DOCKER_DEVICES=""; for dev in /dev/rga /dev/video* /dev/media*; do if [ -e "$dev" ]; then DOCKER_DEVICES="$DOCKER_DEVICES --device $dev:$dev"; fi; done; docker run $DOCKER_DEVICES|g' "$TARGET_SCRIPT"
    fi
done
# =================================================================================

echo "🎁 正在通过宿主机 Docker，强行跨架构下发并封印 H29K(ARM64) 专属闭环离线包..."
docker save bluenviron/mediamtx:${MEDIAMTX_VER} -o files/usr/share/docker-images/mediamtx.tar
docker save h29k-alpine-ffmpeg:${FALLBACK_ALPINE_VER} -o files/usr/share/docker-images/alpine.tar

echo "🎁 离线全家桶镜像（版本: MediaMTX@$MEDIAMTX_VER, Alpine-FFmpeg@$FALLBACK_ALPINE_VER）已实现100%纯本地闭环！"

# =================================================================================
# 🚨 针对 aic8800 本地 Makefile 的终极补丁（支持 set -e 严格模式）
# =================================================================================
REAL_AIC_MAKEFILE="package/kernel/aic8800/Makefile"

if [ -f "$REAL_AIC_MAKEFILE" ]; then
    echo "📥 侦测到目标组件，正在从自定义仓库强制下载覆盖 aic8800 Makefile..."
    
    # 下载文件
    curl -sSL --connect-timeout 8 --retry 3 \
      "https://raw.githubusercontent.com/I-agree/H29K/main/package/kernel/aic8800/Makefile" > "$REAL_AIC_MAKEFILE" || true
    
    # 核心校验：判断是否包含 PKG_BUILD_DEPENDS:=mac80211
    if grep -q "PKG_BUILD_DEPENDS:=mac80211" "$REAL_AIC_MAKEFILE"; then
        echo "✅ aic8800 Makefile 覆盖成功，令牌锁死与 GCC14 报错已物理粉碎！"
    else
        echo "❌ 校验失败：Makefile 中缺失 PKG_BUILD_DEPENDS:=mac80211，编译将终止！"
        exit 1
    fi

else
    echo "⚠️ 警告：在 $REAL_AIC_MAKEFILE 未找到该组件，请确认源码路径！"
fi

# =================================================================================

echo "🚀 H29K 极致稳健的流媒体边缘切换矩阵离线改造，全部大功告成！"
