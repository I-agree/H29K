#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)

set -euo pipefail  # 严格报错模式：任一非条件命令失败立即终止

# === 1. 软件源配置 ===
# 添加 QModem 软件源
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default

# === 2. 安装网页端文件管理器
git clone https://github.com/sbwml/luci-app-quickfile package/quickfile

# === 3. 安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# === 4. 管理蓝牙设备的LuCI
# git clone https://github.com/I-agree/luci-app-bluetooth.git package/luci-app-bluetooth

# === 5. 磁盘扩容
git clone https://github.com/sirpdboy/luci-app-partexp.git package/luci-app-partexp

# === 6. axs5106触摸驱动
# git clone https://github.com/I-agree/axs5106.git package/kernel/modules/axs5106

# ======================== 【统一下载与文件校验中心】 ========================
echo "📥 开始统一拉取 H29K 编译所需的核心外置资源..."

# 创建全局所需的所有目录架构 (新增 files/www 网页容器支撑)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip \
         package/boot/uboot-rockchip/configs/hinlink/h29k \
         package/boot/uboot-rockchip/dts \
         target/linux/rockchip/image \
         files/etc \
         gc9307 \
         files/usr/share/splash \
         files/etc/init.d \
         files/etc/fonts/conf.d \
         files/usr/bin \
         files/lib/firmware \
         package/boot/uboot-rockchip/patches \
         package/kernel/aic8800/patches \
         files/usr/share/fonts

# 新建空白rc.local
touch files/etc/rc.local
chmod +x files/etc/rc.local
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
# download_and_check "${BASE_URL}/JPG/splash_anim" "files/etc/init.d/splash_anim"
# download_and_check "${BASE_URL}/JPG/splash_loop.py" "files/usr/bin/splash_loop.py"
# download_and_check "${BASE_URL}/fonts/MiSans-Regular.ttf" "files/usr/share/fonts/MiSans-Regular.ttf"
# download_and_check "${BASE_URL}/fonts/show_sentence.py" "files/usr/bin/show_sentence.py"

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
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_FBDEV_OVERALLOC=100
# CONFIG_DRM_FBDEV_LEAK_PHYS_SMEM is not set
CONFIG_DRM_CLIENT_DEFAULT_FBDEV=y
# CONFIG_DRM_CLIENT_LOG is not set
# CONFIG_DRM_CLIENT_DEFAULT_LOG is not set
# CONFIG_LOGO is not set
CONFIG_DUMMY_CONSOLE_COLUMNS=80
CONFIG_DUMMY_CONSOLE_ROWS=25
CONFIG_FRAMEBUFFER_CONSOLE=y
# CONFIG_FRAMEBUFFER_CONSOLE_LEGACY_ACCELERATION is not set
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER=y
CONFIG_FRAMEBUFFER_CONSOLE_ROTATION=y
CONFIG_EXTRA_FIRMWARE="sitronix,gc9307.bin"
CONFIG_EXTRA_FIRMWARE_DIR="/workdir/openwrt/gc9307"

# CONFIG_DRM_SIMPLEDRM is not set
# CONFIG_DRM_SYSFB_HELPER is not set
# CONFIG_APERTURE_HELPERS is not set
# CONFIG_FB is not set
CONFIG_FB_CORE=y
CONFIG_FB_DEVICE=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_IMAGEBLIT=y
CONFIG_FB_SYSMEM_FOPS=y
CONFIG_FB_DEFERRED_IO=y
CONFIG_FB_DMAMEM_HELPERS=y
CONFIG_FB_DMAMEM_HELPERS_DEFERRED=y
CONFIG_FB_SYSMEM_HELPERS=y
CONFIG_FB_SYSMEM_HELPERS_DEFERRED=y

# === 调试前置基础 ===
CONFIG_DEBUG_KERNEL=y
CONFIG_DYNAMIC_DEBUG=y
CONFIG_DYNAMIC_DEBUG_CORE=y
CONFIG_DEBUG_FS=y
# CONFIG_SPI_DEBUG is not set
# === 固件加载调试 ===
CONFIG_FW_LOADER_DEBUG=y

EOF
echo "✅ H29K 内核参数注入完成"
