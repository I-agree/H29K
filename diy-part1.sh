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

# === 6. axs5106触摸驱动
git clone https://github.com/I-agree/axs5106.git package/kernel/modules/axs5106

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

echo "📝 正在精准注入 H29K 专属内核配置到: $CONFIG_FILE"

# ========== 第一阶段：sed 原位替换（处理已知确切值的条目）==========
# 这些条目在原始 config-6.12 中有确定值，sed 可直接精确匹配
sed -i 's/^CONFIG_ARM64_SVE=y$/# CONFIG_ARM64_SVE is not set/' "$CONFIG_FILE"
sed -i 's/^CONFIG_CMA_SIZE_MBYTES=.*$/CONFIG_CMA_SIZE_MBYTES=32/' "$CONFIG_FILE"

cat >> "$CONFIG_FILE" << 'EOF'

# =================================================================
# 🔄 TCP BBR + FQ
# =================================================================
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_DEFAULT=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_FQ=y
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
# CONFIG_DEFAULT_CUBIC is not set
CONFIG_DEFAULT_BBR=y

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
CONFIG_MMC_PWRSEQ_SIMPLE=y
CONFIG_MMC_PWRSEQ_EMMC=y
CONFIG_BT_HCIBTSDIO=m
# CONFIG_BT_HCIBTUSB is not set
# CONFIG_BT_HCIUART is not set

# =================================================================
# gpio-keys按键驱动 (设备没有按钮，但是保留)
# =================================================================
CONFIG_INPUT=y
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_KEYBOARD=y
# GPIO按键官方标准宏（OpenWrt打包依赖这个）
CONFIG_KEYBOARD_GPIO=y

# =================================================================
# 小屏幕 (ST7789V开启的全套配置)
# =================================================================
# 顶层DRM总开关
CONFIG_DRM=y
# DRM面板框架
CONFIG_DRM_PANEL=y
# 设备树
CONFIG_OF=y
# SPI总线
CONFIG_SPI=y
# 背光驱动
CONFIG_BACKLIGHT_CLASS_DEVICE=y
# ST7789V屏幕驱动
CONFIG_DRM_PANEL_SITRONIX_ST7789V=y

# =================================================================
# TSADC温度 (Rockchip 平台温控核心配置)
# =================================================================
# 基础架构
CONFIG_ARCH_ROCKCHIP=y
CONFIG_HAS_IOMEM=y
CONFIG_RESET_CONTROLLER=y

# 温控框架
CONFIG_THERMAL=y
CONFIG_THERMAL_OF=y
CONFIG_THERMAL_HWMON=y
CONFIG_THERMAL_NETLINK=y

# RK TSADC驱动
CONFIG_ROCKCHIP_THERMAL=y

# 温控冷却
CONFIG_CPU_THERMAL=y
CONFIG_CPU_FREQ_THERMAL=y
CONFIG_THERMAL_DEFAULT_GOV_STEP_WISE=y
CONFIG_THERMAL_GOV_STEP_WISE=y

# =================================================================
# 硬件真随机数 TRNG
# =================================================================
# 基础依赖
CONFIG_ARCH_ROCKCHIP=y
CONFIG_HAS_IOMEM=y
CONFIG_OF=y

# 硬件随机数框架
CONFIG_HW_RANDOM=y
# RK硬件TRNG驱动（DTS rng节点依赖此项）
CONFIG_HW_RANDOM_ROCKCHIP=y

# 推荐配套熵池相关（保证硬件随机数注入系统随机池）
CONFIG_CRYPTO=y
CONFIG_CRYPTO_RNG=y
CONFIG_CRYPTO_DRBG=y

# =================================================================
# rfkill-modem射频
# =================================================================
# 基础依赖
CONFIG_GPIOLIB=y
CONFIG_OF=y

# RFKILL总开关
CONFIG_RFKILL=y
# GPIO射频开关驱动（rfkill-modem DTS节点核心）
CONFIG_RFKILL_GPIO=y

# 推荐配套（默认开启）
CONFIG_RFKILL_LEDS=y
CONFIG_RFKILL_INPUT=y

# =================================================================
# PWM sysfs 相关配置
# =================================================================
# 全局基础
CONFIG_SYSFS=y
CONFIG_OF=y
CONFIG_HAS_IOMEM=y
CONFIG_ARCH_ROCKCHIP=y

# PWM总开关（开启后自动启用PWM sysfs导出）
CONFIG_PWM=y

# RK硬件PWM驱动，匹配DTS pwm节点
CONFIG_PWM_ROCKCHIP=y

# 可选：PWM调试日志
# CONFIG_PWM_DEBUG is not set

# =================================================================
# SPI+MTD+spi-nor 整套相关配置
# =================================================================
# 设备树解析
CONFIG_OF=y
# 寄存器内存映射访问
CONFIG_HAS_IOMEM=y
# RK平台架构
CONFIG_ARCH_ROCKCHIP=y
# sysfs 文件系统，导出MTD设备节点
CONFIG_SYSFS=y

# =================================================================
# SDIO 整套相关配置
# =================================================================
# MMC总开关+SDIO协议
CONFIG_MMC=y
CONFIG_MMC_SDIO=y
CONFIG_MMC_SDIO_IRQ=y

# SDIO模组GPIO上电复位
CONFIG_PWRSEQ_SIMPLE=y

# RK DW MMC控制器
CONFIG_MMC_DW=y
CONFIG_MMC_DW_PLTFM=y
CONFIG_MMC_DW_ROCKCHIP=y

# 全局基础依赖
CONFIG_OF=y
CONFIG_HAS_IOMEM=y
CONFIG_HAS_DMA=y

# =================================================================
# RK 平台 GPIO LED
# =================================================================
# LED总开关
CONFIG_NEW_LEDS=y
# LED sysfs类核心
CONFIG_LEDS_CLASS=y
# GPIO指示灯驱动（DTS gpio-leds）
CONFIG_LEDS_GPIO=y
# LED触发器总开关
CONFIG_LEDS_TRIGGERS=y
# 常用触发器
CONFIG_LEDS_TRIG_HEARTBEAT=y
CONFIG_LEDS_TRIG_NETDEV=y
CONFIG_LEDS_TRIG_MMC=y

# 全局前置依赖
CONFIG_GPIOLIB=y
CONFIG_OF=y

# =================================================================
# RGA 2D 硬件加速
# =================================================================
# media顶层
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_SUPPORT_FILTER=y
CONFIG_MEDIA_SUBDRV_AUTOSELECT=y
CONFIG_MEDIA_PLATFORM_SUPPORT=y
# 关闭其余多媒体类型
# CONFIG_MEDIA_CAMERA_SUPPORT is not set
# CONFIG_MEDIA_ANALOG_TV_SUPPORT is not set
# CONFIG_MEDIA_DIGITAL_TV_SUPPORT is not set
# CONFIG_MEDIA_RADIO_SUPPORT is not set
# CONFIG_MEDIA_SDR_SUPPORT is not set
# CONFIG_MEDIA_TEST_SUPPORT is not set

# V4L2核心
CONFIG_VIDEO_DEV=y
# CONFIG_MEDIA_CONTROLLER is not set
CONFIG_V4L_MEM2MEM_DRIVERS=y

# v4l2-core 缓冲依赖
CONFIG_VIDEOBUF2_CORE=y

# RGA驱动
CONFIG_VIDEO_ROCKCHIP_RGA=y

# DMA内存必备
CONFIG_DMA_CMA=y
CONFIG_DMA_SHARED_BUFFER=y

# =================================================================
# Mali-450 GPU 2D/3D 图形硬件加速  RK3528 开源 Lima
# =================================================================
# DRM总开关
CONFIG_DRM=y
# 关闭调试类DRM配置
# CONFIG_DRM_DEBUG_MM is not set
# CONFIG_DRM_PANIC is not set
# CONFIG_DRM_DEBUG_DP_MST_TOPOLOGY_REFS is not set
# CONFIG_DRM_DEBUG_MODESET_LOCK is not set

# 传统fb0兼容 + 固化缓冲比例
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_FBDEV_OVERALLOC=100
# 禁用物理地址泄露
# CONFIG_DRM_FBDEV_LEAK_PHYS_SMEM is not set

CONFIG_DRM_LOAD_EDID_FIRMWARE=y
# DRM GEM DMA内存管理
CONFIG_DRM_GEM_DMA_HELPER=y

# 瑞芯VOP+HDMI显示驱动
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_VOP=y
# CONFIG_ROCKCHIP_VOP2 is not set
CONFIG_ROCKCHIP_DW_HDMI=y
# RK平台HDMI I2S音频配置，关闭IMX专用AHB/GP音频
# CONFIG_DRM_DW_HDMI_AHB_AUDIO is not set
# CONFIG_DRM_DW_HDMI_GP_AUDIO is not set
CONFIG_DRM_DW_HDMI_I2S_AUDIO=y
# CONFIG_DRM_DW_HDMI_CEC is not set

# 关闭未使用显示接口
# CONFIG_ROCKCHIP_DW_MIPI_DSI is not set
# CONFIG_ROCKCHIP_LVDS is not set
# CONFIG_ROCKCHIP_RGB is not set
# CONFIG_ROCKCHIP_ANALOGIX_DP is not set
# CONFIG_ROCKCHIP_CDN_DP is not set
# CONFIG_ROCKCHIP_INNO_HDMI is not set
# CONFIG_ROCKCHIP_RK3066_HDMI is not set

# RK3528 Mali-450 专用开源LIMA驱动
CONFIG_DRM_LIMA=y
# 禁用G52/T860的Panfrost，避免冲突
# CONFIG_DRM_PANFROST is not set

# 基础内存与IOMMU
CONFIG_DMA_CMA=y
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_ROCKCHIP_IOMMU=y

# ALSA音频全套固化
CONFIG_SND=y
CONFIG_SND_SOC=y
CONFIG_SND_PCM=y
CONFIG_SND_PCM_ELD=y
CONFIG_SND_PCM_IEC958=y

EOF
echo "✅ H29K 内核参数注入完成"
