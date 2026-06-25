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
sed -i 's/^CONFIG_ARM64_SVE=y$/# CONFIG_ARM64_SVE is not set/' "$CONFIG_FILE"
sed -i 's/^CONFIG_CMA_SIZE_MBYTES=16$/CONFIG_CMA_SIZE_MBYTES=128/' "$CONFIG_FILE"
sed -i 's/^CONFIG_CMA_AREAS=7$/CONFIG_CMA_AREAS=8/' "$CONFIG_FILE"
sed -i 's/^CONFIG_DWMAC_DWC_QOS_ETH=y$/# CONFIG_DWMAC_DWC_QOS_ETH is not set/' "$CONFIG_FILE"
sed -i 's/^# CONFIG_PARTITION_ADVANCED is not set$/CONFIG_PARTITION_ADVANCED=y/' "$CONFIG_FILE"

cat >> "$CONFIG_FILE" << 'EOF'

# =================================================================
# 🔧 H29K 硬件对齐修正 (RK3528 内置 Naneng CombPHY)
# =================================================================
# ❌ 移除所有外置 PHY 驱动 (H29K 无独立 RTL8211/Micrel/KSZ PHY)
# CONFIG_MICREL_PHY is not set
# CONFIG_REALTEK_PHY is not set
# CONFIG_MOTORCOMM_PHY is not set
# CONFIG_MEDIATEK_GE_PHY is not set

# ✅ RK3528 内置千兆 RGMII PHY (Naneng CombPHY)
CONFIG_PHY_ROCKCHIP_NANENG_COMBO_PHY=y
CONFIG_PHYLINK=y
CONFIG_FIXED_PHY=y

# =================================================================
# 📡 蓝牙完整协议栈 (AIC8800 SDIO WiFi+BT二合一)
# =================================================================
CONFIG_BT=y
CONFIG_BT_BREDR=y
CONFIG_BT_LE=y
CONFIG_BT_RFCOMM=y
CONFIG_BT_RFCOMM_TTY=y
CONFIG_BT_BNEP=y
CONFIG_BT_BNEP_MC_FILTER=y
CONFIG_BT_BNEP_PROTO_FILTER=y
CONFIG_BT_HIDP=y

# 启用SDIO蓝牙，适配AIC8800复合模组
CONFIG_BT_HCIBTSDIO=y

# 禁用USB、UART类型蓝牙传输
# CONFIG_BT_HCIBTUSB is not set
# CONFIG_BT_HCIUART is not set

# AIC8800 SDIO蓝牙硬件支持开关
CONFIG_AIC8800_SDIO_BT_SUPPORT=y

# =================================================================
# 🚫 关闭 SimpleDRM (避免与 ST7789V SPI 屏抢占 fb0)
# =================================================================
# CONFIG_DRM_SIMPLEDRM is not set

# =================================================================
# 🔧 前次分析缺失项修复 + 【关键修复：全部cfg80211配置固化防交互弹窗】
# =================================================================
# SFC MTD 分区解析
CONFIG_MTD_CHAR=y
CONFIG_MTD_OF_PARTS=y

# WiFi 协议栈 (AIC8800 SDIO 必需)
CONFIG_CFG80211=y
CONFIG_NL80211=y
CONFIG_CFG80211_HEADERS=y
# 禁用nl80211工厂测试命令，消除NEW交互式弹窗
# CONFIG_NL80211_TESTMODE is not set
CONFIG_CFG80211_WEXT=y
CONFIG_CFG80211_CRDA_SUPPORT=y
CONFIG_CFG80211_USE_KERNEL_REGDB_KEYS=y
CONFIG_CFG80211_DEFAULT_REGDOM=y
# 无线默认省电模式，规避NEW弹窗
CONFIG_CFG80211_DEFAULT_PS=y
# 关闭无线开发调试警告
# CONFIG_CFG80211_DEVELOPER_WARNINGS is not set
# 关闭无线认证高级选项
# CONFIG_CFG80211_CERTIFICATION_ONUS is not set
# 关闭cfg80211调试文件系统节点
# CONFIG_CFG80211_DEBUGFS is not set
CONFIG_MAC80211=y
CONFIG_WLAN=y
CONFIG_FW_LOADER_COMPRESS=y

# gpio-keys 驱动修正 (替代错误的 KEYBOARD_GPIO)
# CONFIG_KEYBOARD_GPIO is not set
CONFIG_INPUT_GPIO_KEYS=y

# =================================================================
# 🌐 网络核心与 IPv6
# =================================================================
CONFIG_NET=y
CONFIG_NETDEVICES=y
CONFIG_INET=y
CONFIG_IPV6=y
CONFIG_IPV6_ROUTER_PREF=y
CONFIG_IPV6_ROUTE_INFO=y
CONFIG_IPV6_SIT=y
CONFIG_IPV6_NDISC_NODETYPE=y
CONFIG_NF_TABLES_BRIDGE=y

# =================================================================
# 🚀 RK3528 GMAC (Synopsys DWMAC 4.20a)
# =================================================================
CONFIG_NET_VENDOR_STMICRO=y
CONFIG_STMMAC_PLATFORM=y
CONFIG_DWMAC_ROCKCHIP=y
CONFIG_PTP_1588_CLOCK_OPTIONAL=y

# =================================================================
# 💾 MMC/SDIO (AIC8800 WiFi)
# =================================================================
CONFIG_MMC_PWRSEQ_SIMPLE=y
CONFIG_MMC_PWRSEQ_EMMC=y

# =================================================================
# 🔌 USB 5G 模块全量支持（匹配DTS关闭XHCI，仅保留USB2）
# =================================================================
CONFIG_USB_ACM=y
CONFIG_USB_WDM=y
CONFIG_USB_USBNET=y
CONFIG_USB_NET_CDCETHER=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_USB_NET_CDC_NCM=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_OPTION=y
CONFIG_PPP=y
CONFIG_PPP_BSDCOMP=y
CONFIG_PPP_DEFLATE=y
CONFIG_PPP_FILTER=y
CONFIG_PPP_MPPE=y
CONFIG_PPP_MULTILINK=y
CONFIG_PPP_ASYNC=y
CONFIG_PPP_SYNC_TTY=y

# =================================================================
# 📂 文件系统
# =================================================================
CONFIG_LIB_UUID=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XATTR=y
CONFIG_SQUASHFS_ZSTD=y
CONFIG_OVERLAY_FS=y
CONFIG_OVERLAY_FS_POSIX_ACL=y
CONFIG_FAT_FS=y
CONFIG_VFAT_FS=y
CONFIG_FAT_DEFAULT_CODEPAGE=936
CONFIG_FAT_DEFAULT_IOCHARSET="utf8"
CONFIG_FAT_DEFAULT_UTF8=y
CONFIG_EXFAT_FS=y
CONFIG_EXFAT_DEFAULT_IOCHARSET="utf8"
CONFIG_NLS_UTF8=y
CONFIG_NLS_CODEPAGE_936=y

# =================================================================
# 🖥️ 显示: ST7789V SPI 屏 (无 HDMI/SimpleDRM)
# =================================================================
CONFIG_SPI=y
CONFIG_SPI_ROCKCHIP=y
CONFIG_SPI_ROCKCHIP_SFC=y
CONFIG_MTD=y
CONFIG_MTD_BLOCK=y
CONFIG_MTD_SPI_NOR=y
CONFIG_GPIOLIB=y
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_PANEL=y
CONFIG_DRM_BRIDGE=y
CONFIG_DRM_PANEL_BRIDGE=y
CONFIG_FB=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_IMAGEBLIT=y
CONFIG_FB_SYS_FOPS=y
CONFIG_FB_DEFERRED_IO=y
CONFIG_FB_MODE_HELPERS=y
CONFIG_FB_BACKLIGHT=y
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_BACKLIGHT_PWM=y
CONFIG_DRM_PANEL_SITRONIX_ST7789V=y

# =================================================================
# 🎥 VPU/RGA/UVC
# =================================================================
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CONTROLLER=y
CONFIG_VIDEO_DEV=y
CONFIG_VIDEO_V4L2_SUBDEV_API=y
CONFIG_MEDIA_CAMERA_SUPPORT=y
CONFIG_MEDIA_PLATFORM_SUPPORT=y
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_VIDEO_CLASS_INPUT_EVDEV=y
CONFIG_VIDEO_ROCKCHIP_RGA=y
CONFIG_V4L_MEM2MEM_DRIVERS=y
CONFIG_VIDEO_HANTRO=y
CONFIG_VIDEO_HANTRO_ROCKCHIP=y
# CONFIG_VIDEO_HANTRO_HEVC_RFC is not set

# =================================================================
# 🛡️ 温控/RNG/IR/RFKill/LEDs/串口
# =================================================================
CONFIG_THERMAL=y
CONFIG_THERMAL_OF=y
CONFIG_THERMAL_HWMON=y
CONFIG_ROCKCHIP_THERMAL=y
CONFIG_HW_RANDOM=y
CONFIG_HW_RANDOM_ROCKCHIP=y
CONFIG_IR_CORE=y
CONFIG_IR_GPIO=y
CONFIG_RFKILL=y
CONFIG_RFKILL_GPIO=y
CONFIG_LEDS_TRIGGER_HEARTBEAT=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_8250_DW=y
CONFIG_SERIAL_8250_DWLIB=y
CONFIG_SERIAL_OF_PLATFORM=y

# =================================================================
# 📦 CIFS/NetFS 模块
# =================================================================
CONFIG_NETFS_SUPPORT=m
CONFIG_FSCACHE=y
CONFIG_CIFS=m
CONFIG_CIFS_ALLOW_INSECURE_LEGACY=y
CONFIG_CIFS_XATTR=y
CONFIG_CIFS_POSIX=y

# =================================================================
# 🔄 TCP BBR + FQ
# =================================================================
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_NET_CONG=bbr
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_QDISC=fq

# =================================================================
# 🔌 USB OTG/Dual Role（匹配DTS关闭XHCI，仅USB2控制器）
# =================================================================
CONFIG_USB_SUPPORT=y
CONFIG_USB=y
CONFIG_USB_GADGET=y
CONFIG_USB_OTG=y
CONFIG_USB_ROLE_SWITCH=y
# 关闭DWC3/XHCI，和DTS usb_host0_xhci=disabled保持一致
# CONFIG_USB_DWC3 is not set
# CONFIG_USB_XHCI_HCD is not set
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_EHCI_HCD_PLATFORM=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_OHCI_HCD_PLATFORM=y
CONFIG_USB_STORAGE=y

# =================================================================
# 📦 模块支持
# =================================================================
CONFIG_MODULES=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_UNLOAD=y

EOF
echo "✅ H29K 内核参数注入完成"
