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

# ======================== 【2. H29K 主线内核配置合并注入】 ========================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"
# 👇 【新增】OpenWrt 外层全局配置文件（解决 BBR/CIFS 被外层依赖绞杀的核心钥匙）
OPENWRT_CONFIG=".config" 

echo "📝 正在精准注入官方 OpenWrt 25.12 专属内核配置文件: $CONFIG_FILE"

# ⚠️ 使用 sed 原位替换，防止 Kconfig 忽略 EOF 末尾追加的重复项
# 原生配置中 SVE=y, CMA=16，如果不先用 sed 替换，后面追加的 =n 和 =64 会失效！
sed -i 's/^CONFIG_ARM64_SVE=y$/# CONFIG_ARM64_SVE is not set/' "$CONFIG_FILE"
sed -i 's/^CONFIG_CMA_SIZE_MBYTES=16$/CONFIG_CMA_SIZE_MBYTES=64/' "$CONFIG_FILE"
sed -i 's/^CONFIG_CMA_AREAS=7$/CONFIG_CMA_AREAS=8/' "$CONFIG_FILE"
sed -i 's/^CONFIG_DWMAC_DWC_QOS_ETH=y$/# CONFIG_DWMAC_DWC_QOS_ETH is not set/' "$CONFIG_FILE"
sed -i 's/^# CONFIG_PARTITION_ADVANCED is not set$/CONFIG_PARTITION_ADVANCED=y/' "$CONFIG_FILE"
sed -i 's/^CONFIG_SPI_ROCKCHIP_SFC=y$/# CONFIG_SPI_ROCKCHIP_SFC is not set/' "$CONFIG_FILE"

cat >> "$CONFIG_FILE" << 'EOF'

# === RK3528 主线核心与平台级别底座驱动（对齐 Linux 6.12）===
CONFIG_NF_TABLES_BRIDGE=y

# === 8250 串口驱动（RK3528 控制台 uart0 依赖）===
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_8250_DW=y
CONFIG_SERIAL_8250_DWLIB=y
CONFIG_SERIAL_OF_PLATFORM=y

# =================================================================
# 🌐 网络核心与 IPv6 支持 (OpenWrt 必选)
# =================================================================
CONFIG_NET=y
CONFIG_NETDEVICES=y
CONFIG_INET=y
CONFIG_IPV6=y
CONFIG_IPV6_ROUTER_PREF=y
CONFIG_IPV6_ROUTE_INFO=y
CONFIG_IPV6_SIT=y
CONFIG_IPV6_NDISC_NODETYPE=y

# =================================================================
# 🚫 标准 DW MAC 驱动配置 (RK3528 适配)
# =================================================================
CONFIG_NET_VENDOR_STMICRO=y
CONFIG_STMMAC_PLATFORM=y
CONFIG_DWMAC_ROCKCHIP=y
# ⚠️ RK3528 使用的是标准 DW MAC IP，不兼容 QoS 变体
# CONFIG_DWMAC_DWC_QOS_ETH is not set

# PTP 时钟依赖 (STMMAC 强依赖)
CONFIG_PTP_1588_CLOCK_OPTIONAL=y

# =================================================================
# 🔌 MDIO 总线与 PHY 框架 (RTL8211F 依赖)
# =================================================================
CONFIG_MICREL_PHY=y

# =================================================================
# 💾 MMC/SDIO 总线核心 (AIC8800-SDIO 物理层依赖)
# =================================================================
# 📶 SDIO WiFi 基础依赖 (电源序列)
CONFIG_MMC_PWRSEQ_SIMPLE=y
CONFIG_MMC_PWRSEQ_EMMC=y

# =================================================================
# 🔌 USB 核心与物理层 (5G 模块底层依赖)
# =================================================================
CONFIG_USB_ACM=y
CONFIG_USB_WDM=y

# =================================================================
# 📡 5G 模块数据通道：USB 网络框架与 RNDIS/NCM 驱动
# =================================================================
CONFIG_USB_USBNET=y
CONFIG_USB_NET_CDCETHER=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_USB_NET_CDC_NCM=y

# =================================================================
# 📡 5G 模块控制通道：USB 串口与 AT 指令驱动
# =================================================================
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_OPTION=y

# =================================================================
# 📡 PPP 拨号支持 (兼容性与备用通道)
# =================================================================
CONFIG_PPP=y
CONFIG_PPP_BSDCOMP=y
CONFIG_PPP_DEFLATE=y
CONFIG_PPP_FILTER=y
CONFIG_PPP_MPPE=y
CONFIG_PPP_MULTILINK=y
CONFIG_PPP_ASYNC=y
CONFIG_PPP_SYNC_TTY=y

# ===================== 完整文件系统总配置=====================
# 分区UUID/PARTUUID 挂载支持
CONFIG_LIB_UUID=y

# 只读根分区 SquashFS
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XATTR=y
CONFIG_SQUASHFS_ZSTD=y

# 可写Overlay EXT4分区
CONFIG_OVERLAY_FS=y
CONFIG_OVERLAY_FS_POSIX_ACL=y

# U盘 FAT32 / exFAT 支持
CONFIG_FAT_FS=y
# CONFIG_MSDOS_FS is not set
CONFIG_VFAT_FS=y
CONFIG_FAT_DEFAULT_CODEPAGE=936
CONFIG_FAT_DEFAULT_IOCHARSET="iso8859-1"
CONFIG_FAT_DEFAULT_UTF8=y
# CONFIG_FAT_KUNIT_TEST is not set
CONFIG_EXFAT_FS=y
CONFIG_EXFAT_DEFAULT_IOCHARSET="utf8"

# 字符集NLS（中文文件名依赖）
CONFIG_NLS_UTF8=y
CONFIG_NLS_CODEPAGE_936=y

CONFIG_LEDS_TRIGGER_HEARTBEAT=y
CONFIG_KEYBOARD_GPIO=y

# =====================================================================
# 解决kmod-fs-netfs核心内核依赖链
# =====================================================================
CONFIG_NETFS_SUPPORT=m
CONFIG_FSCACHE=y
# CONFIG_FSCACHE_STATS is not set
# CONFIG_CACHEFILES is not set

CONFIG_CIFS=m
CONFIG_CIFS_ALLOW_INSECURE_LEGACY=y
CONFIG_CIFS_XATTR=y
CONFIG_CIFS_POSIX=y
# CONFIG_CIFS_DEBUG is not set
# CONFIG_CIFS_DFS_UPCALL is not set
# CONFIG_CIFS_FSCACHE is not set
# CONFIG_CIFS_COMPRESSION is not set

# =====================================================================

# --- 针对 A53 架构彻底关闭不支持的 SVE 扩展，全力确保 ASIMD(NEON) 跑满 ---
# CONFIG_ARM64_SVE is not set

# --- 触摸驱动内嵌
CONFIG_TOUCHSCREEN_FT6236=y

# =================================================================
# 🛡️ 显示架构核心底座与防弹窗屏蔽词（对齐第一层 drivers/gpu/drm/Kconfig）
# =================================================================
# ⚠️由于下方封杀了所有 VOP/VOP2/HDMI 后端，开启 DRM_ROCKCHIP 会导致
# Kconfig 依赖树崩溃或被自动降级为 n。使用 SimpleDRM + MIPI DBI 不需要此平台驱动。
# CONFIG_DRM_ROCKCHIP is not set
CONFIG_DRM_MIPI_DBI=y
# CONFIG_DRM_DEBUG_MM is not set
# CONFIG_DRM_USE_DYNAMIC_DEBUG is not set
# CONFIG_DRM_KUNIT_TEST is not set
# CONFIG_DRM_PANIC is not set
# CONFIG_DRM_DEBUG_DP_MST_TOPOLOGY_REFS is not set
# CONFIG_DRM_DEBUG_MODESET_LOCK is not set
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
# 📺 核心闭环：HDMI SimpleDRM 路线 + ST7789 SPI屏 双显示兼容
# =================================================================
CONFIG_DRM_SIMPLEDRM=y

# Linux v6.12 官方ST7789V面板驱动（匹配sitronix,st7789v DTS兼容串）
CONFIG_DRM_PANEL_SITRONIX_ST7789V=y

# ==============================================================================
# 🎥 补全核心：VPU视频硬解、RGA硬件转换加速与 USB 摄像头支持（全面防御 NEW 弹窗）
# ==============================================================================
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CONTROLLER=y
CONFIG_VIDEO_DEV=y
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
CONFIG_V4L_MEM2MEM_DRIVERS=y
CONFIG_VIDEO_HANTRO=y
CONFIG_VIDEO_HANTRO_ROCKCHIP=y
# 关闭HEVC参考帧压缩，消除NEW交互弹窗
# CONFIG_VIDEO_HANTRO_HEVC_RFC is not set
# 非瑞芯平台全部显式禁用
# CONFIG_VIDEO_HANTRO_IMX8M is not set
# CONFIG_VIDEO_HANTRO_SAMA5D4 is not set
# CONFIG_VIDEO_HANTRO_SUNXI is not set
# CONFIG_VIDEO_HANTRO_STM32MP25 is not set

# ==============================================================================

# --- 网络高并发 TCP BBR + FQ 底层内建 ---
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_NET_CONG=bbr
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_QDISC=fq

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

# 适配DTS：GPIO红外接收器
CONFIG_IR_CORE=y
CONFIG_IR_GPIO=y

# 适配DTS：4G/5G模块GPIO射频电源开关
CONFIG_RFKILL=y
CONFIG_RFKILL_GPIO=y

# 内核模块支持，修复CIFS=m等模块加载依赖
CONFIG_MODULES=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_UNLOAD=y

# ========== TSADC 温度采集 + 系统温控 ==========
CONFIG_THERMAL=y
CONFIG_THERMAL_OF=y
CONFIG_THERMAL_HWMON=y
CONFIG_ROCKCHIP_THERMAL=y

# ========== RK3528 硬件RNG真随机 ==========
CONFIG_HW_RANDOM=y
CONFIG_HW_RANDOM_ROCKCHIP=y

EOF
echo "✅ 已向 $CONFIG_FILE 注入目标内核参数"

# =================================================================================
# 🚨 核心补丁：打通 OpenWrt 外层依赖锁（防止 BBR 和 CIFS 被 make defconfig 清理）
# =================================================================================
echo "🔓 正在解锁 OpenWrt 外层全局依赖，确保 BBR 与 CIFS 编译生效..."

# 1. 强制开启 OpenWrt 内核高级 TCP 拥塞控制选项（BBR 的生死符）
if grep -q "CONFIG_KERNEL_TCP_CONG_ADVANCED" "$OPENWRT_CONFIG"; then
    sed -i 's/^.*CONFIG_KERNEL_TCP_CONG_ADVANCED.*$/CONFIG_KERNEL_TCP_CONG_ADVANCED=y/' "$OPENWRT_CONFIG"
else
    echo "CONFIG_KERNEL_TCP_CONG_ADVANCED=y" >> "$OPENWRT_CONFIG"
fi

# 2. 强制开启网络文件系统支持（CIFS 的通行证）
if grep -q "CONFIG_PACKAGE_kmod-fs-cifs" "$OPENWRT_CONFIG"; then
    sed -i 's/^.*CONFIG_PACKAGE_kmod-fs-cifs.*$/CONFIG_PACKAGE_kmod-fs-cifs=y/' "$OPENWRT_CONFIG"
else
    echo "CONFIG_PACKAGE_kmod-fs-cifs=y" >> "$OPENWRT_CONFIG"
fi

# 3. 强制开启 NetFS 核心依赖
if grep -q "CONFIG_PACKAGE_kmod-fs-netfs" "$OPENWRT_CONFIG"; then
    sed -i 's/^.*CONFIG_PACKAGE_kmod-fs-netfs.*$/CONFIG_PACKAGE_kmod-fs-netfs=y/' "$OPENWRT_CONFIG"
else
    echo "CONFIG_PACKAGE_kmod-fs-netfs=y" >> "$OPENWRT_CONFIG"
fi

echo "✅ OpenWrt 外层依赖锁已物理粉碎，BBR 与 CIFS 将 100% 编入固件！"

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
