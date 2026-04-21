#!/bin/bash

# --- 1. 编译环境底层修复 ---
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 2. 硬件支持文件下载与重命名 (匹配 UBOOT_DEVICE_NAME) ---
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_BIN_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"

mkdir -p "$DTS_PATH"
curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts"
# 下载并更名为标准格式
curl -fsSL "$BOOT_BIN_URL" > hinlink_h29k-u-boot-rockchip.bin

# --- 3. 注册设备到 Makefile (hinlink_h29k) ---
TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
if [ -n "$TARGET_MK" ]; then
    if ! grep -q "hinlink_h29k" "$TARGET_MK"; then
        cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_ALT0_VENDOR := LinkStar
  DEVICE_ALT0_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | pine64-img | gzip | append-metadata
  KERNEL_SIZE := 33554432
  BOARD_ROOTFS_PARTSIZE := 1024
  KERNEL_LOADADDR := 0x02000000
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-r8169 kmod-usb-net-rtl8152 kmod-aic8800 aic8800-firmware kmod-mtk_t7xx
endef
TARGET_DEVICES += hinlink_h29k
EOF
    fi
fi

# --- 4. 核心配置注入 (BBR + 屏幕 + 5G/网卡底层) ---
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    cat >> "$KERNEL_CONF" <<EOF
# 性能与中断
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"

# H29K 屏幕支持 (ST7789V)
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ST7789V=m
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_DW_HDMI=y

# 有线网卡支持
CONFIG_R8169=y
CONFIG_REALTEK_NET_COMMON=y

# 无线网卡 (aic8800) 底层支持
CONFIG_WLAN=y
CONFIG_CFG80211=y
CONFIG_CFG80211_WEXT=y

# 5G FM350-GL (T7XX) 核心驱动
CONFIG_MTK_T7XX=m
CONFIG_WWAN=y
EOF
fi

# --- 5. 软件包注入与 5G 模块锁定 ---
cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y

# 仅保留 FM350-GL 驱动，不选其他 5G 模块
CONFIG_PACKAGE_kmod-mtk_t7xx=y

# Irqbalance 中断均衡
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_luci-app-irqbalance=y
CONFIG_PACKAGE_luci-i18n-irqbalance-zh-cn=y

# 锁定 H29K 板载网卡驱动
CONFIG_PACKAGE_kmod-r8169=y
CONFIG_PACKAGE_kmod-aic8800=y
CONFIG_PACKAGE_aic8800-firmware=y

# 简体中文与主题
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-theme-argon=y
EOF

# --- 6. 执行生成配置 (首次刷新) ---
make defconfig

# --- 7. 个性化设置注入 ---
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i "s/timezone='.*'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s/zonename='.*'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 无线 SSID 与 地区
sed -i 's/SSID/H29K/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
sed -i "s/country='.*'/country='CN'/g" package/kernel/mac80211/files/lib/wifi/mac80211.sh

# --- 8. 修复 BUG、分区锁定与 5G 唯一性过滤 ---

# 移除 JFFS2 以修复 BUG
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config

# 强制锁定分区大小
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config || echo "CONFIG_TARGET_KERNEL_PARTSIZE=32" >> .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config || echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> .config

# 【核心锁定】：移除 FM350-GL (mtk_t7xx) 以外的所有 5G 驱动包
sed -i '/kmod-usb-net-quectel/d' .config
sed -i '/kmod-usb-net-meig/d' .config
sed -i '/kmod-usb-net-huawei/d' .config
sed -i '/kmod-mhi-wwan/d' .config

# 确保单选 H29K
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_/d' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

# 最终刷新
make defconfig
