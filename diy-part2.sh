#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# --- 第一部分：编译环境补丁 (环境先行) ---
# 解决 GitHub Actions 宿主机缺失 functions.sh 导致的脚本执行报错
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
    echo "成功建立宿主机 /lib/functions.sh 软链接"
fi

# --- 第二部分：源码级修改 (设备与驱动注入) ---

# 1. 动态查找目标 Makefile
TARGET_MK=$(find target/linux/rockchip/image -name "*.mk" | xargs grep -l "Device/rk3528" | head -n 1)

# 2. 准备 DTS 文件
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_PATH"
curl -fsSL https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts > "$DTS_PATH/rk3528-opc-h29k.dts"

# 3. 准备 Loader 文件并注入编译指令
if [ -n "$TARGET_MK" ]; then
    LOADER_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
    mkdir -p dl
    curl -fsSL "$LOADER_URL" > dl/hinlink_h29k-u-boot-rockchip.bin

    # 注入 Makefile 依赖逻辑
    echo '
$(STAGING_DIR_IMAGE)/hinlink_h29k-u-boot-rockchip.bin: dl/hinlink_h29k-u-boot-rockchip.bin
	mkdir -p $(dir $@)
	cp $< $@
' >> "$TARGET_MK"

# 4. 在 Makefile 中注册设备 (优化插入位置)
if ! grep -q "Device/hinlink_h29k" "$TARGET_MK"; then
    echo "正在精准注入 H29K 设备定义..."
    
    # 创建一个临时文件存放设备定义
    cat > h29k_device.txt <<'EOF'

define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  IMAGE/sysupgrade.img.gz := rockchip-combined | rockchip-u-boot
  KERNEL_SIZE := 33554432
  BOARD_ROOTFS_PARTSIZE := 1024
  DEVICE_PACKAGES := kmod-r8169 kmod-fb kmod-drm-rockchip kmod-console-font \
    kmod-usb3 kmod-usb-dwc3-rockchip \
    kmod-usb-net-rndis kmod-usb-net-cdc-ether kmod-usb-net-rtl8152 \
    kmod-usb-serial-option uqmi \
    luci-i18n-base-zh-cn luci-i18n-qmodem-next-zh-cn kmod-usb-net-cdc-mbim kmod-usb-net-cdc-ncm \
    luci-theme-argon luci-app-argon-config luci-app-turboacc luci-app-sqm
endef
TARGET_DEVICES += hinlink_h29k

EOF

    # 寻找第一个 "define Device" 出现的位置，并在其上方插入
    # 这样可以确保我们的定义位于 Makefile 的核心逻辑区
    sed -i '/define Device/r h29k_device.txt' "$TARGET_MK"
    rm h29k_device.txt
fi

# 5. 内核直播优化 (BBR + 5G驱动强制注入)
KERNEL_CONF="target/linux/rockchip/config-default"
if [ -f "$KERNEL_CONF" ]; then
    sed -i '/CONFIG_MHI/d' "$KERNEL_CONF"
    sed -i '/CONFIG_TCP_CONG_BBR/d' "$KERNEL_CONF"
    cat >> "$KERNEL_CONF" <<EOF
CONFIG_PCI=y
CONFIG_PCIE_ROCKCHIP=y
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_MHI_NET=y
CONFIG_MHI_WWAN_CTRL=y
CONFIG_WWAN=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
EOF
fi

# --- 第三部分：系统 UI 与个性化设置 ---

# 6. 系统设置 (语言、时区、主机名)
sed -i 's/auto/zh_hans/g' package/base-files/files/bin/config_generate
sed -i "s/'UTC'/'CST-8'\n\t\tset system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate
sed -i 's/hostname=".*"/hostname="H29K"/g' package/base-files/files/bin/config_generate

# 7. SSID 默认名修改
WIFI_SH=$(find package -name "mac80211.sh" | head -n 1)
[ -n "$WIFI_SH" ] && sed -i 's/ssid=".*"/ssid="H29K"/g' "$WIFI_SH"

# --- 第四部分：配置生成与终极锁定 (锁定收尾) ---

# 8. 刷新 .config 并处理语言包依赖
make defconfig
if [ -f .config ]; then
    echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config
    grep "=y" .config | grep "CONFIG_PACKAGE_luci-app-" | sed 's/CONFIG_PACKAGE_luci-app-//g;s/=y//g' | while read -r app; do
        echo "CONFIG_PACKAGE_luci-i18n-$app-zh-cn=y" >> .config
    done
fi

# 9. 移除残留的 JFFS2 任务
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config 2>/dev/null

# 10. 锁定分区大小 (放在最后确保覆盖 defconfig 的默认设置)
sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/g' .config
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/g' .config
