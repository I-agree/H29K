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

echo "📝 正在精准注入 H29K 专属内核配置到: $CONFIG_FILE"

# ========== 第一阶段：sed 原位替换（处理已知确切值的条目）==========
# 这些条目在原始 config-6.12 中有确定值，sed 可直接精确匹配
sed -i 's/^CONFIG_ARM64_SVE=y$/# CONFIG_ARM64_SVE is not set/' "$CONFIG_FILE"
sed -i 's/^CONFIG_CMA_SIZE_MBYTES=.*$/CONFIG_CMA_SIZE_MBYTES=128/' "$CONFIG_FILE"
sed -i 's/^CONFIG_CMA_AREAS=.*$/CONFIG_CMA_AREAS=8/' "$CONFIG_FILE"
sed -i 's/^CONFIG_DWMAC_DWC_QOS_ETH=y$/# CONFIG_DWMAC_DWC_QOS_ETH is not set/' "$CONFIG_FILE"
sed -i 's/^# CONFIG_PARTITION_ADVANCED is not set$/CONFIG_PARTITION_ADVANCED=y/' "$CONFIG_FILE"

# ⚠️ 修复：原 sed 只匹配 =y，但实际可能是 =m，改为通配
sed -i 's/^CONFIG_USB_EHCI_HCD=.*$/# CONFIG_USB_EHCI_HCD is not set/' "$CONFIG_FILE"
sed -i 's/^CONFIG_USB_OHCI_HCD=.*$/# CONFIG_USB_OHCI_HCD is not set/' "$CONFIG_FILE"

echo "✅ sed 原位替换完成"

# ========== 第二阶段：scripts/config 注入（替代 cat >> EOF）==========
# scripts/config 直接操作 Kconfig 语法树，自动处理依赖关系
# 在 make defconfig 之前执行，确保所有条目被正确纳入依赖解析
cd "$GITHUB_WORKSPACE/openwrt"  # 确保在 openwrt 根目录

./scripts/config --file "$CONFIG_FILE" \
    --enable DEVTMPFS \
    --enable DEVTMPFS_MOUNT \
    --disable DEVTMPFS_SAFE \
    --disable ARM64_SVE \
    --disable DWMAC_DWC_QOS_ETH \
    --enable PARTITION_ADVANCED \
    --set-val CMA_SIZE_MBYTES 128 \
    --set-val CMA_AREAS 8 \
    --disable USB_EHCI_HCD \
    --disable USB_OHCI_HCD \
    --disable DRM_SIMPLEDRM \
    --enable BT \
    --enable BT_BREDR \
    --enable BT_LE \
    --enable BT_RFCOMM \
    --enable BT_RFCOMM_TTY \
    --enable BT_BNEP \
    --enable BT_BNEP_MC_FILTER \
    --enable BT_BNEP_PROTO_FILTER \
    --enable BT_HIDP \
    --module BT_HCIBTSDIO \
    --disable BT_HCIBTUSB \
    --disable BT_HCIUART \
    --module CFG80211 \
    --disable NL80211_TESTMODE \
    --disable CFG80211_DEVELOPER_WARNINGS \
    --disable CFG80211_CERTIFICATION_ONUS \
    --disable CFG80211_DEBUGFS \
    --disable CFG80211_REQUIRE_SIGNED_REGDB \
    --enable CFG80211_DEFAULT_PS \
    --enable CFG80211_CRDA_SUPPORT \
    --enable CFG80211_WEXT \
    --enable CFG80211_USE_KERNEL_REGDB_KEYS \
    --enable CFG80211_DEFAULT_REGDOM \
    --set-str CFG80211_EXTRA_REGDB_KEYDIR "" \
    --module MAC80211 \
    --enable MAC80211_RC_MINSTREL \
    --enable MAC80211_RC_DEFAULT_MINSTREL \
    --disable MAC80211_MESH \
    --disable MAC80211_LEDS \
    --disable MAC80211_DEBUGFS \
    --disable MAC80211_MESSAGE_TRACING \
    --disable MAC80211_DEBUG_MENU \
    --disable MAC80211_HWSIM \
    --enable WLAN \
    --disable WLAN_VENDOR_ADMTEK \
    --disable WLAN_VENDOR_ATH \
    --disable WLAN_VENDOR_ATMEL \
    --disable WLAN_VENDOR_BROADCOM \
    --disable WLAN_VENDOR_INTEL \
    --disable WLAN_VENDOR_INTERSIL \
    --disable WLAN_VENDOR_MARVELL \
    --disable WLAN_VENDOR_MEDIATEK \
    --disable WLAN_VENDOR_MICROCHIP \
    --disable WLAN_VENDOR_PURELIFI \
    --disable WLAN_VENDOR_RALINK \
    --disable WLAN_VENDOR_REALTEK \
    --disable WLAN_VENDOR_RSI \
    --disable WLAN_VENDOR_SILABS \
    --disable WLAN_VENDOR_ST \
    --disable WLAN_VENDOR_TI \
    --disable WLAN_VENDOR_ZYDAS \
    --disable WLAN_VENDOR_QUANTENNA \
    --disable VIRT_WIFI \
    --disable MEDIATEK_GE_PHY \
    --disable MICREL_PHY \
    --disable REALTEK_PHY \
    --disable MOTORCOMM_PHY \
    --enable INPUT_GPIO_KEYS \
    --disable KEYBOARD_GPIO \
    --enable FW_LOADER \
    --enable FW_LOADER_COMPRESS \
    --disable FW_LOADER_PAGED_BUF \
    --disable FW_LOADER_SYSFS \
    --disable FW_LOADER_COMPRESS_XZ \
    --disable FW_LOADER_COMPRESS_ZSTD \
    --disable FW_LOADER_DEBUG \
    --disable RUST_FW_LOADER_ABSTRACTIONS \
    --disable FW_CACHE \
    --disable FW_UPLOAD \
    --set-str EXTRA_FIRMWARE "" \
    --set-str EXTRA_FIRMWARE_DIR "/lib/firmware" \
    --enable MTD_OF_PARTS \
    --enable NET_VENDOR_STMICRO \
    --enable STMMAC_PLATFORM \
    --enable DWMAC_ROCKCHIP \
    --enable PTP_1588_CLOCK_OPTIONAL \
    --enable MMC_PWRSEQ_SIMPLE \
    --enable MMC_PWRSEQ_EMMC \
    --enable SQUASHFS \
    --enable SQUASHFS_XATTR \
    --enable SQUASHFS_ZSTD \
    --enable OVERLAY_FS \
    --enable OVERLAY_FS_POSIX_ACL \
    --enable FAT_FS \
    --enable VFAT_FS \
    --set-val FAT_DEFAULT_CODEPAGE 936 \
    --set-str FAT_DEFAULT_IOCHARSET "utf8" \
    --enable FAT_DEFAULT_UTF8 \
    --enable EXFAT_FS \
    --set-str EXFAT_DEFAULT_IOCHARSET "utf8" \
    --enable NLS_UTF8 \
    --enable NLS_CODEPAGE_936 \
    --enable SPI \
    --enable SPI_ROCKCHIP \
    --enable SPI_ROCKCHIP_SFC \
    --enable MTD \
    --enable MTD_BLOCK \
    --enable MTD_SPI_NOR \
    --enable GPIOLIB \
    --enable DRM \
    --enable DRM_KMS_HELPER \
    --enable DRM_PANEL \
    --enable DRM_BRIDGE \
    --enable DRM_PANEL_BRIDGE \
    --enable FB \
    --enable FB_SYS_FILLRECT \
    --enable FB_SYS_COPYAREA \
    --enable FB_SYS_IMAGEBLIT \
    --enable FB_SYS_FOPS \
    --enable FB_DEFERRED_IO \
    --enable FB_MODE_HELPERS \
    --enable FB_BACKLIGHT \
    --enable BACKLIGHT_CLASS_DEVICE \
    --enable BACKLIGHT_PWM \
    --enable DRM_PANEL_SITRONIX_ST7789V \
    --enable MEDIA_SUPPORT \
    --enable MEDIA_CONTROLLER \
    --enable VIDEO_DEV \
    --enable VIDEO_V4L2_SUBDEV_API \
    --enable MEDIA_CAMERA_SUPPORT \
    --enable MEDIA_PLATFORM_SUPPORT \
    --enable USB_VIDEO_CLASS \
    --enable USB_VIDEO_CLASS_INPUT_EVDEV \
    --enable VIDEO_ROCKCHIP_RGA \
    --enable V4L_MEM2MEM_DRIVERS \
    --enable VIDEO_HANTRO \
    --enable VIDEO_HANTRO_ROCKCHIP \
    --disable VIDEO_HANTRO_HEVC_RFC \
    --enable THERMAL \
    --enable THERMAL_OF \
    --enable THERMAL_HWMON \
    --enable ROCKCHIP_THERMAL \
    --enable HW_RANDOM \
    --enable HW_RANDOM_ROCKCHIP \
    --enable IR_CORE \
    --enable IR_GPIO \
    --enable IR_GPIO_CIR \
    --enable RFKILL \
    --enable RFKILL_GPIO \
    --enable LEDS_TRIGGER_HEARTBEAT \
    --enable SERIAL_8250 \
    --enable SERIAL_8250_CONSOLE \
    --enable SERIAL_8250_DW \
    --enable SERIAL_8250_DWLIB \
    --enable SERIAL_OF_PLATFORM \
    --module NETFS_SUPPORT \
    --enable FSCACHE \
    --module CIFS \
    --enable CIFS_ALLOW_INSECURE_LEGACY \
    --enable CIFS_XATTR \
    --enable CIFS_POSIX \
    --enable TCP_CONG_ADVANCED \
    --enable TCP_CONG_BBR \
    --enable DEFAULT_BBR \
    --set-str DEFAULT_NET_CONG "bbr" \
    --enable NET_SCHED \
    --enable NET_SCH_FQ \
    --set-str DEFAULT_QDISC "fq" \
    --enable USB_SUPPORT \
    --enable USB \
    --enable USB_GADGET \
    --enable USB_OTG \
    --enable USB_ROLE_SWITCH \
    --enable USB_ULPI_BUS \
    --enable USB_DEFAULT_PERSIST \
    --set-val USB_AUTOSUSPEND_DELAY 2 \
    --set-val USB_DEFAULT_AUTHORIZATION_MODE 1 \
    --enable USB_DWC3 \
    --enable USB_DWC3_DUAL_ROLE \
    --disable USB_DWC3_HOST \
    --disable USB_DWC3_GADGET \
    --disable USB_DWC3_ULPI \
    --disable USB_DWC3_OMAP \
    --disable USB_DWC3_EXYNOS \
    --disable USB_DWC3_PCI \
    --disable USB_DWC3_HAPS \
    --disable USB_DWC3_KEYSTONE \
    --disable USB_DWC3_MESON_G12A \
    --disable USB_DWC3_OF_SIMPLE \
    --disable USB_DWC3_ST \
    --disable USB_DWC3_QCOM \
    --disable USB_DWC3_IMX8MP \
    --disable USB_DWC3_XILINX \
    --disable USB_DWC3_AM62 \
    --disable USB_DWC3_OCTEON \
    --disable USB_DWC3_RTK \
    --enable USB_DWC3_ROCKCHIP \
    --enable USB_XHCI_HCD \
    --enable USB_XHCI_DWC3 \
    --enable USB_XHCI_PLATFORM \
    --disable USB_C67X00_HCD \
    --disable USB_OXU210HP_HCD \
    --disable USB_ISP116X_HCD \
    --disable USB_MAX3421_HCD \
    --disable USB_UHCI_HCD \
    --disable USB_SL811_HCD \
    --disable USB_R8A66597_HCD \
    --disable USB_HCD_TEST_MODE \
    --enable USB_STORAGE \
    --disable USB_UAS \
    --enable USB_ACM \
    --enable USB_WDM \
    --disable USB_PRINTER \
    --disable USB_TMC \
    --disable USB_MDC800 \
    --disable USB_MICROTEK \
    --disable USBIP_CORE \
    --disable USB_CDNS_SUPPORT \
    --disable USB_MUSB_HDRC \
    --enable USB_USBNET \
    --enable USB_NET_CDCETHER \
    --enable USB_NET_RNDIS_HOST \
    --enable USB_NET_CDC_NCM \
    --enable USB_SERIAL \
    --enable USB_SERIAL_CONSOLE \
    --enable USB_SERIAL_GENERIC \
    --enable USB_SERIAL_OPTION \
    --enable PPP \
    --enable PPP_BSDCOMP \
    --enable PPP_DEFLATE \
    --enable PPP_FILTER \
    --enable PPP_MPPE \
    --enable PPP_MULTILINK \
    --enable PPP_ASYNC \
    --enable PPP_SYNC_TTY \
    --enable MODULES \
    --enable MODVERSIONS \
    --enable MODULE_UNLOAD \
    --disable USB_KEYBOARD \
    --disable USB_MOUSE \
    --disable USB_HID \
    --enable KEYS \
    --disable KEYS_REQUEST_CACHE \
    --disable PERSISTENT_KEYRINGS \
    --disable BIG_KEYS \
    --disable TRUSTED_KEYS \
    --disable ENCRYPTED_KEYS \
    --disable USER_DECRYPTED_DATA \
    --disable KEY_DH_OPERATIONS \
    --disable KEY_NOTIFICATIONS \
    --enable ASYMMETRIC_KEY_TYPE \
    --enable ASYMMETRIC_PUBLIC_KEY_SUBTYPE \
    --enable X509_CERTIFICATE_PARSER \
    --disable PKCS8_PRIVATE_KEY_PARSER \
    --disable PKCS7_MESSAGE_PARSER \
    --disable SIGNED_PE_FILE_VERIFICATION \
    --disable PKCS7_TEST_KEY \
    --disable FIPS_SIGNATURE_SELFTEST \
    --enable SYSTEM_TRUSTED_KEYRING \
    --set-str SYSTEM_TRUSTED_KEYS "" \
    --disable SYSTEM_EXTRA_CERTIFICATE \
    --disable SECONDARY_TRUSTED_KEYRING \
    --disable SECONDARY_TRUSTED_KEYRING_SIGNED_BY_BUILTIN \
    --disable SYSTEM_BLACKLIST_KEYRING \
    --disable SYSTEM_BLACKLIST_HASH_LIST \
    --disable SYSTEM_REVOCATION_LIST \
    --disable SYSTEM_REVOCATION_KEYS \
    --disable SYSTEM_BLACKLIST_AUTH_UPDATE \
    --disable MODULE_SIG_KEY \
    --disable MODULE_SIG \
    --disable MODULE_SIG_ALL \
    --disable STAGING

echo "✅ H29K 内核参数通过 scripts/config 注入完成"
