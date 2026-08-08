#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)

set -euo pipefail  # 严格报错模式：任一非条件命令失败立即终止

# === 1. 软件源配置 ===
# 添加 QModem 软件源
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default

# === 2. 安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# === 3. 安装 glass 主题
git clone https://github.com/rchen14b/luci-theme-glass.git package/luci-theme-glass

# ======================== 【统一下载与文件校验中心】 ========================
echo "📥 开始统一拉取 H29K 编译所需的核心外置资源..."

# 创建全局所需的所有目录架构 (新增 files/www 网页容器支撑)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip \
         package/kernel/axs5106/src \
         target/linux/rockchip/patches-6.18 \
         target/linux/rockchip/image \
         files/etc/uci-defaults \
         gc9307 \
         files/usr/share/splash \
         files/etc/init.d \
         files/usr/share/qmodem/led_scripts \
         files/etc/config \
         files/usr/sbin \
         files/lib/firmware \
         package/boot/uboot-rockchip/patches \
         package/kernel/aic8800/patches \
         files/usr/share/fonts

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
download_and_check "${BASE_URL}/target/linux/rockchip/image/armv8.mk" "target/linux/rockchip/image/armv8.mk"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/Makefile" "package/boot/uboot-rockchip/Makefile"
download_and_check "${BASE_URL}/gc9307/sitronix,gc9307.bin" "files/lib/firmware/sitronix,gc9307.bin"
download_and_check "${BASE_URL}/gc9307/sitronix,gc9307.bin" "gc9307/sitronix,gc9307.bin"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/999-add-hinlink-h29k-rk3528.patch" "package/boot/uboot-rockchip/patches/999-add-hinlink-h29k-rk3528.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/Makefile" "package/kernel/aic8800/Makefile"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/010-fix-fall-through.patch" "package/kernel/aic8800/patches/010-fix-fall-through.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/020-wireless-6.16.patch" "package/kernel/aic8800/patches/020-wireless-6.16.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/030-update-firmware-path.patch" "package/kernel/aic8800/patches/030-update-firmware-path.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/040-rename-module.patch" "package/kernel/aic8800/patches/040-rename-module.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/050-log-level.patch" "package/kernel/aic8800/patches/050-log-level.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/060-fix-read-cpuid.patch" "package/kernel/aic8800/patches/060-fix-read-cpuid.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/070-fix-mips-pc-macro-conflict.patch" "package/kernel/aic8800/patches/070-fix-mips-pc-macro-conflict.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/080-fix-export-symbols-conflict.patch" "package/kernel/aic8800/patches/080-fix-export-symbols-conflict.patch"
download_and_check "${BASE_URL}/package/kernel/aic8800/patches/series" "package/kernel/aic8800/patches/series"
download_and_check "${BASE_URL}/target/linux/rockchip/patches-6.18/999-clk-rk3528-add-hclk_trng-gate.patch" "target/linux/rockchip/patches-6.18/999-clk-rk3528-add-hclk_trng-gate.patch"
download_and_check "${BASE_URL}/JPG/99-bootanim" "files/etc/init.d/99-bootanim"
download_and_check "${BASE_URL}/JPG/drm_play_arm64" "files/usr/sbin/drm_play_arm64"
# download_and_check "${BASE_URL}/target/linux/rockchip/patches-6.18/998-panel-mipi-dbi-debug-log.patch" "target/linux/rockchip/patches-6.18/998-panel-mipi-dbi-debug-log.patch"
download_and_check "${BASE_URL}/fonts/MiSans-Regular.ttf" "files/usr/share/fonts/MiSans-Regular.ttf"
download_and_check "${BASE_URL}/JPG/once-enable-bootanim" "files/etc/uci-defaults/once-enable-bootanim"
download_and_check "${BASE_URL}/qmodem/misectel_led.sh" "files/usr/share/qmodem/led_scripts/misectel_led.sh"
download_and_check "${BASE_URL}/qmodem/qmodem_led" "files/etc/config/qmodem_led"
download_and_check "${BASE_URL}/package/kernel/axs5106/Makefile" "package/kernel/axs5106/Makefile"
download_and_check "${BASE_URL}/package/kernel/axs5106/src/Makefile" "package/kernel/axs5106/src/Makefile"
download_and_check "${BASE_URL}/package/kernel/axs5106/src/chipone_axs5106.c" "package/kernel/axs5106/src/chipone_axs5106.c"
download_and_check "${BASE_URL}/JPG/system" "files/etc/config/system"
download_and_check "${BASE_URL}/JPG/wireless" "files/etc/config/wireless"
download_and_check "${BASE_URL}/JPG/smartdns" "files/etc/config/smartdns"
download_and_check "${BASE_URL}/JPG/minidlna" "files/etc/config/minidlna"
download_and_check "${BASE_URL}/JPG/samba4" "files/etc/config/samba4"

# --- 统一拉取应用层开机 LOGO 组 ---
for i in 1 2 3; do
    download_and_check "${LOGO_URL}/LOGO${i}.jpg" "files/usr/share/splash/LOGO${i}.jpg"
done

# ==============================================================================
echo "🚀 [diy-part1.sh] 软件源与独立包与配置文件下载圆满完成！"

# ======================== 【H29K 主线内核配置合并注入】 ========================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.18"

echo "📝 正在精准注入 H29K 专属内核配置到: $CONFIG_FILE"

# ========== 第一阶段：sed 原位替换（处理已知确切值的条目）==========
# 这些条目在原始 config-6.18 中有确定值，sed 可直接精确匹配
sed -i 's/^CONFIG_ARM64_SVE=y$/# CONFIG_ARM64_SVE is not set/' "$CONFIG_FILE"
sed -i 's/^# CONFIG_BLK_DEV_INITRD is not set$/CONFIG_BLK_DEV_INITRD=y/' "$CONFIG_FILE"

cat >> "$CONFIG_FILE" << 'EOF'

# =================================================================
# 🔄 补充到内核以支持启动 OpenWrt
# =================================================================
CONFIG_TMPFS=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_TMPFS_POSIX_ACL=y

CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_DEVTMPFS_SAFE=y
# CONFIG_UEVENT_HELPER is not set
# CONFIG_DEBUG_DRIVER is not set
# CONFIG_DEBUG_DEVRES is not set
# CONFIG_ALLOW_DEV_COREDUMP is not set

CONFIG_BLK_DEV=y
CONFIG_BLK_DEV_RAM=y
CONFIG_BLK_DEV_RAM_COUNT=16
CONFIG_BLK_DEV_RAM_SIZE=4096
CONFIG_BLK_DEV_LOOP=y
# 其余无关块设备全部关闭
# CONFIG_BLK_DEV_FD is not set
# CONFIG_BLK_DEV_NBD is not set
# CONFIG_BLK_DEV_NULL_BLK is not set
# CONFIG_ZRAM is not set
# CONFIG_BLK_DEV_DRBD is not set
# CONFIG_BLK_DEV_PCIESSD_MTIP32XX is not set
# CONFIG_XEN_BLKDEV_FRONTEND is not set
# CONFIG_VIRTIO_BLK is not set
# CONFIG_BLK_DEV_RBD is not set

CONFIG_INITRAMFS_SOURCE=""
# CONFIG_INITRAMFS_FORCE is not set
CONFIG_RD_GZIP=y
CONFIG_RD_BZIP2=y
CONFIG_RD_LZMA=y
CONFIG_RD_XZ=y
CONFIG_RD_LZO=y
CONFIG_RD_LZ4=y
CONFIG_RD_ZSTD=y
# CONFIG_INITRAMFS_COMPRESSION_GZIP is not set
# CONFIG_INITRAMFS_COMPRESSION_BZIP2 is not set
# CONFIG_INITRAMFS_COMPRESSION_LZMA is not set
# CONFIG_INITRAMFS_COMPRESSION_XZ is not set
# CONFIG_INITRAMFS_COMPRESSION_LZO is not set
# CONFIG_INITRAMFS_COMPRESSION_LZ4 is not set
# CONFIG_INITRAMFS_COMPRESSION_ZSTD is not set
# CONFIG_INITRAMFS_COMPRESSION_NONE is not set

CONFIG_BLK_DEV_INITRD=y
CONFIG_INITRAMFS_PRESERVE_MTIME=y
# CONFIG_BOOT_CONFIG is not set

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
# 🔄 加密加速 + 硬件随机
# =================================================================
CONFIG_CRYPTO=y
CONFIG_CRYPTO_HW=y
CONFIG_ARCH_ROCKCHIP=y

CONFIG_RESET_CONTROLLER=y
CONFIG_RESET_SIMPLE=y
CONFIG_CLK_ROCKCHIP=y

CONFIG_CRYPTO_DEV_ROCKCHIP=y
CONFIG_RANDOM=y
CONFIG_HW_RANDOM=y
CONFIG_HW_RANDOM_ROCKCHIP=y
# CONFIG_CRYPTO_DEV_ROCKCHIP_DEBUG is not set

# =================================================================
# 🔄 Thermal + TSADC
# =================================================================
CONFIG_THERMAL=y
CONFIG_THERMAL_OF=y
CONFIG_ROCKCHIP_THERMAL=y
CONFIG_THERMAL_HWMON=y
CONFIG_NVMEM=y
CONFIG_CPU_THERMAL=y
CONFIG_CPU_FREQ_THERMAL=y
CONFIG_DEVFREQ_THERMAL=y
CONFIG_THERMAL_GOV_STEP_WISE=y
CONFIG_THERMAL_GOV_POWER_ALLOCATOR=y
CONFIG_THERMAL_NETLINK=y

# =================================================================
# 🔄 rfkill-modem射频
# =================================================================
CONFIG_GPIOLIB=y
CONFIG_OF=y
CONFIG_RFKILL=y
CONFIG_RFKILL_GPIO=y
CONFIG_RFKILL_LEDS=y
# CONFIG_RFKILL_INPUT is not set

# =================================================================
# 🔄 PWM sysfs 相关配置
# =================================================================
CONFIG_SYSFS=y
CONFIG_OF=y
CONFIG_HAS_IOMEM=y
CONFIG_PWM=y
CONFIG_PWM_SYSFS=y
# CONFIG_PWM_GPIO is not set
CONFIG_PWM_ROCKCHIP=y
# CONFIG_PWM_DEBUG is not set

# =================================================================
# 🔄 RGA 2D 硬件加速
# =================================================================
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_SUPPORT_FILTER=y
CONFIG_MEDIA_SUBDRV_AUTOSELECT=y
CONFIG_MEDIA_PLATFORM_SUPPORT=y
# CONFIG_MEDIA_CAMERA_SUPPORT is not set
# CONFIG_MEDIA_ANALOG_TV_SUPPORT is not set
# CONFIG_MEDIA_DIGITAL_TV_SUPPORT is not set
# CONFIG_MEDIA_RADIO_SUPPORT is not set
# CONFIG_MEDIA_SDR_SUPPORT is not set
# CONFIG_MEDIA_TEST_SUPPORT is not set
CONFIG_VIDEO_DEV=y
# CONFIG_MEDIA_CONTROLLER is not set
CONFIG_V4L_MEM2MEM_DRIVERS=y
CONFIG_VIDEOBUF2_CORE=y
CONFIG_VIDEO_ROCKCHIP_RGA=y
CONFIG_ROCKCHIP_RGA=y
CONFIG_ROCKCHIP_RGA_IOMMU=y
CONFIG_HAS_IOMEM=y
CONFIG_OF=y
CONFIG_DMA_CMA=y
CONFIG_DMA_SHARED_BUFFER=y

# =================================================================
# 🔄 GPU + 小屏幕
# =================================================================
CONFIG_DRM=y
CONFIG_DRM_LIMA=y
CONFIG_DRM_MIPI_DBI=y
CONFIG_DRM_PANEL_MIPI_DBI=y
CONFIG_DRM_PANEL_MIPI_DBI_SPI=y
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_BACKLIGHT_GPIO=y
CONFIG_CMA_SIZE_MBYTES=64
CONFIG_DMABUF_HEAPS=y
CONFIG_DMABUF_HEAPS_SYSTEM=y
CONFIG_DMABUF_HEAPS_CMA=y
CONFIG_DMABUF_HEAPS_CMA_LEGACY=y
CONFIG_SPI=y
CONFIG_SPI_ROCKCHIP=y
CONFIG_FW_LOADER=y
CONFIG_DRM_CLIENT_SELECTION=y
CONFIG_DRM_CLIENT=y
# CONFIG_DRM_FBDEV_EMULATION is not set
# CONFIG_DRM_FBDEV_LEAK_PHYS_SMEM is not set
# CONFIG_DRM_CLIENT_DEFAULT_FBDEV is not set
# CONFIG_DRM_CLIENT_LOG is not set
# CONFIG_DRM_CLIENT_DEFAULT_LOG is not set
# CONFIG_LOGO is not set
CONFIG_EXTRA_FIRMWARE="sitronix,gc9307.bin"
CONFIG_EXTRA_FIRMWARE_DIR="/workdir/openwrt/gc9307"

# CONFIG_DRM_SIMPLEDRM is not set
# CONFIG_DRM_SYSFB_HELPER is not set
# CONFIG_APERTURE_HELPERS is not set
# CONFIG_FB is not set

CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_GEM_DMA_HELPER=y
CONFIG_VIDEOMODE_HELPERS=y
CONFIG_OF_VIDEOMODE=y
CONFIG_OF=y
CONFIG_GPIOLIB=y
CONFIG_REGULATOR=y
CONFIG_CMA=y
CONFIG_DMA_CMA=y

# =================================================================
# 🔄 usb(rndis) 支持
# =================================================================
CONFIG_NETDEVICES=y
CONFIG_USB=y
CONFIG_USB_HOST=y
CONFIG_USB_ACM=y
CONFIG_USB_SERIAL=y
# CONFIG_USB_SERIAL_CONSOLE is not set
CONFIG_USB_SERIAL_OPTION=y
CONFIG_USB_USBNET=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_PPP=y
CONFIG_TUN=y

# =================================================================
# 🔄 内核触摸驱动支持
# =================================================================
CONFIG_OF=y
CONFIG_GPIOLIB=y
CONFIG_I2C=y
CONFIG_I2C_RK3X=y
CONFIG_INPUT=y
CONFIG_INPUT_EVDEV=y

EOF
echo "✅ H29K 内核参数注入完成"
