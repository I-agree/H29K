#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)

set -euo pipefail  # 严格报错模式：任一非条件命令失败立即终止

# === 1. 软件源配置 ===
# 添加 QModem 软件源
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default

# === 2. 提取无线网卡驱动（精准对齐 25.12 分支时代） ===
git clone --depth 1 -b openwrt-25.12 --filter=blob:none --sparse https://github.com/immortalwrt/immortalwrt.git package/immortalwrt_temp
cd package/immortalwrt_temp
git sparse-checkout set package/kernel/aic8800
cd ../..
cp -r package/immortalwrt_temp/package/kernel/aic8800 package/kernel/aic8800
rm -rf package/immortalwrt_temp

# === 3. 安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# === 4. 管理蓝牙设备的LuCI
git clone https://github.com/I-agree/luci-app-bluetooth.git package/luci-app-bluetooth

# === 5. 磁盘扩容
git clone https://github.com/sirpdboy/luci-app-partexp.git package/luci-app-partexp

# ======================== 【统一下载与文件校验中心】 ========================
echo "📥 开始统一拉取 H29K 编译所需的核心外置资源..."

# 创建全局所需的所有目录架构 (新增 files/www 网页容器支撑)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip \
         package/boot/uboot-rockchip/configs \
         package/boot/uboot-rockchip/dts \
         target/linux/rockchip/image \
         package/boot/rkbin \
         files/etc/config/screen \
         files/etc/docker/mediamtx \
         files/etc/init.d \
         files/etc/fonts/conf.d \
         files/usr/bin \
         files/www \
         package/boot/uboot-rockchip/patches \
         files/usr/share/docker-images

BASE_URL="https://raw.githubusercontent.com/I-agree/H29K/main"
LOGO_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"

# [工具函数] 统一的下载与基础大小校验
download_and_check() {
    local url="$1"
    local dest="$2"
    echo "正在下载: $dest ..."
    if ! curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$url" -o "$dest"; then
        echo "❌ 错误: $url 网络请求或连接失败！"
        exit 1
    fi
    if [ ! -s "$dest" ]; then
        echo "❌ 错误: $dest 下载成功但文件为空！"
        exit 1
    fi
}

# --- 批量下载核心底座组件 ---
download_and_check "${BASE_URL}/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-hinlink-h29k.dts" "target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-hinlink-h29k.dts"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"
download_and_check "${BASE_URL}/target/linux/rockchip/image/armv8.mk" "target/linux/rockchip/image/armv8.mk"
download_and_check "${BASE_URL}/target/linux/rockchip/Makefile" "target/linux/rockchip/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/Makefile" "package/boot/uboot-rockchip/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k-u-boot.dtsi" "package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k-u-boot.dtsi"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/900-fix-mb-missing-header.patch" "package/boot/uboot-rockchip/patches/900-fix-mb-missing-header.patch"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/901-fix-dwc3-dma-proto.patch" "package/boot/uboot-rockchip/patches/901-fix-dwc3-dma-proto.patch"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts" "package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts"
download_and_check "${BASE_URL}/package/boot/rkbin/Makefile" "package/boot/rkbin/Makefile"

# --- 统一拉取应用层开机 LOGO 组 ---
for i in 1 2 3; do
    download_and_check "${LOGO_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg"
done

# ==============================================================================
echo "🚀 [diy-part1.sh] 软件源与独立包与配置文件下载圆满完成！"

# ======================== 【H29K 主线内核配置合并注入】 ========================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

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

# === RK3528 主线核心与平台级别底座驱动===
CONFIG_NF_TABLES_BRIDGE=y

# === 8250 串口驱动 ===
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_8250_DW=y
CONFIG_SERIAL_8250_DWLIB=y
CONFIG_SERIAL_OF_PLATFORM=y

# =================================================================
# 🌐 网络核心与 IPv6 支持
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
# SMB/CIFS 客户端 + FSCACHE 文件缓存 防弹窗完整配置
CONFIG_NETFS_SUPPORT=m
CONFIG_FSCACHE=y
# CONFIG_FSCACHE_STATS is not set

# 关闭cachefiles缓存后端，避免新增NEW交互项
# CONFIG_CACHEFILES is not set
# CONFIG_CACHEFILES_DEBUG is not set
# CONFIG_CACHEFILES_ERROR_INJECTION is not set
# CONFIG_CACHEFILES_ONDEMAND is not set

CONFIG_CIFS=m
# CONFIG_CIFS_STATS2 is not set
CONFIG_CIFS_ALLOW_INSECURE_LEGACY=y
# CONFIG_CIFS_UPCALL is not set
CONFIG_CIFS_XATTR=y
CONFIG_CIFS_POSIX=y
# CONFIG_CIFS_DEBUG is not set
# CONFIG_CIFS_DEBUG2 is not set
# CONFIG_CIFS_DEBUG_DUMP_KEYS is not set
# CONFIG_CIFS_DFS_UPCALL is not set
# CONFIG_CIFS_SWN_UPCALL is not set
# CONFIG_CIFS_NFSD_EXPORT is not set
# CONFIG_CIFS_SMB_DIRECT is not set
# CONFIG_CIFS_FSCACHE is not set
# CONFIG_CIFS_ROOT is not set
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
