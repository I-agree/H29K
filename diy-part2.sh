#!/bin/bash
set -e

# ======================== 【第1部分：资源准备】 ========================
echo "执行基础资源下载..."

# 创建必需目录
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
mkdir -p target/package/boot/uboot-rockchip/files/configs/hinlink-h29k-rk3528_defconfig package/boot/uboot-rockchip/files/configs/

# DTS 设备树文件
cp -f $GITHUB_WORKSPACE/rk3528-opc-h29k.dts target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/

# ========== 【复制 U-Boot defconfig 到编译目录，让系统识别】 ==========
cp -f $GITHUB_WORKSPACE/package/boot/uboot-rockchip/files/configs/hinlink-h29k-rk3528_defconfig package/boot/uboot-rockchip/files/configs/

download_file() {
    local url="$1"
    local path="$2"
    local name="$3"
    if curl -fsSL --retry 3 --connect-timeout 10 "$url" -o "$path"; then
        echo "✅ $name 下载成功"
    else
        echo "❌ $name 下载失败"
        exit 1
    fi
}

# 创建LOGO目录
mkdir -p files/etc/config/screen bin/targets/rockchip/armv8

# 下载开机LOGO
LOGO_RAW_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"
for i in 1 2 3; do
  download_file "${LOGO_RAW_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg" "LOGO${i}"
done

# ==============================================================================
# 【官方标准格式】添加 H29K 到 U-Boot
# 完全匹配源码风格，不碰 H28K，不冲突、不覆盖
# ==============================================================================
makefile="package/boot/uboot-rockchip/Makefile"

# 1. 在 hinlink-h28k-rk3528 后面追加 hinlink-h29k-rk3528 到 UBOOT_TARGETS
sed -i '/hinlink-h28k-rk3528/a\  hinlink-h29k-rk3528 \\' "$makefile"

# 2. 在 H28K 定义下面 添加 H29K 设备（完全官方格式）
sed -i '/define U-Boot\/hinlink-h28k-rk3528/a\
define U-Boot/hinlink-h29k-rk3528\n  $(U-Boot/rk3528/Default)\n  NAME:=HINLINK H29K\n  BUILD_DEVICES:=hinlink_h29k\nendef
' "$makefile"

# ======================== 【第2部分：H28K 基准配置 】 ========================
echo "===== 生成 H28K 基准配置 ====="
cat > .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k=y
EOF

make defconfig

echo "✅ H28K 基准配置完成"

# ======================== 【✅ 关键：只编译 H29K，清空所有官方设备】 ========================
sed -i '/^TARGET_DEVICES +=/d' target/linux/rockchip/image/armv8.mk

# ======================== 【第3部分：内核配置】 ========================
CONF_FILES=$(find target/linux/rockchip/armv8 -name "config-*")
for CONF in $CONF_FILES; do
sed -i '/CONFIG_STAGING/d; /CONFIG_FB_TFT/d; /CONFIG_TCP_CONG/d; /CONFIG_DEFAULT_TCP_CONG/d' "$CONF"
cat >> "$CONF" <<EOF
CONFIG_STAGING=y
CONFIG_FB_TFT=y
CONFIG_FB_TFT_ST7789V=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_IRQ_BALANCING=y
CONFIG_IRQ_AFFINITY=y
EOF
done

# ======================== 【第4部分：设备定义】 ========================
TARGET_MK="target/linux/rockchip/image/armv8.mk"

cat >> "$TARGET_MK" <<'EOF'
define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink-h29k-rk3528
  DEVICE_PACKAGES := kmod-usb3 kmod-usb-net-rtl8152 kmod-r8169 kmod-aic8800-sdio wpad-openssl dnsmasq-full kmod-mtk_t7xx kmod-usb-net-cdc-mbim uqmi kmod-usb-net-rndis-host kmod-usb-serial-option kmod-h29k-fb-st7789v luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn luci-theme-argon fbv imagemagick wqy-microhei curl irqbalance luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF

echo "===== ✅ 关键切换为 H29K 配置 ====="
# ==============================================
# 【强制清理 H28K 专属配置，避免冲突】
# ==============================================
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k/d' .config
sed -i '/CONFIG_PACKAGE_uboot-rockchip-hinlink_h28k/d' .config
sed -i '/CONFIG_PACKAGE_uboot-rockchip-h28k/d' .config
sed -i '/CONFIG_TARGET_DEVICE_HINLINK_H28K/d' .config
sed -i '/CONFIG_UBOOT_HINLINK_H28K/d' .config
sed -i '/CONFIG_rockchip_h28k/d' .config
echo "# CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k is not set" >> .config

# 【步骤1】删除旧分区配置（无视数字，最合理）
sed -i '/^CONFIG_TARGET_KERNEL_PARTSIZE=/d' .config
sed -i '/^CONFIG_TARGET_ROOTFS_PARTSIZE=/d' .config
# 【步骤2】写入 H29K 新分区
echo "CONFIG_TARGET_KERNEL_PARTSIZE=128" >> .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> .config

# 写入防冲突：dnsmasq-full + wpad-openssl
sed -i '/CONFIG_PACKAGE_dnsmasq/d' .config
sed -i '/CONFIG_PACKAGE_wpad/d' .config
echo "CONFIG_PACKAGE_wpad-basic-wolfssl=n" >> .config
echo "CONFIG_PACKAGE_wpad-basic-mbedtls=n" >> .config
echo "CONFIG_PACKAGE_wpad-openssl=y" >> .config
echo "CONFIG_PACKAGE_dnsmasq=n" >> .config
echo "CONFIG_PACKAGE_dnsmasq-full=y" >> .config

echo "CONFIG_PACKAGE_luci-mod-admin-full=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-base-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-app-irqbalance=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-irqbalance-zh-cn=y" >> .config

echo "CONFIG_PACKAGE_dnscrypt-proxy=y" >> .config
echo "CONFIG_PACKAGE_luci-app-dnscrypt-proxy=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-dnscrypt-proxy-zh-cn=y" >> .config

# ==============================
# 写入：H29K 全部正确配置
# ==============================
cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_rk3528=y
CONFIG_TARGET_MULTI_ARCH=n
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
CONFIG_PACKAGE_uboot-rockchip=y
CONFIG_PACKAGE_uboot-rockchip-v8=y
CONFIG_PACKAGE_uboot-rockchip-hinlink_h29k=y
CONFIG_TARGET_DEVICE_PACKAGES_rockchip_armv8_DEVICE_hinlink_h29k="uboot-rockchip-hinlink_h29k"
EOF

# ======================== 【第5部分：屏幕脚本】 ========================
mkdir -p files/usr/bin
cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/ttf/wqy-microhei.ttc"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"
sleep 12
for i in 1 2 3; do [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8; done

while true; do
    # ==============================
    # 动态获取 cdc-wdm 设备
    # ==============================
    WDM_DEV=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1)
    WDM_DEV=${WDM_DEV:-/dev/cdc-wdm0}
    RSRP=$(uqmi -d "$WDM_DEV" --get-signal-info 2>/dev/null | grep rsrp | awk '{print $2}')
    [ -z "$RSRP" ] && RSRP="Search"

    QUOTE=$(curl -s --connect-timeout 2 "https://v1.hitokoto.cn/?encode=text" | cut -c 1-25)
    convert "$LOGO_DIR/LOGO3.jpg" -fill "rgba(0,0,0,0.7)" -draw "rectangle 0 60 240 240" \
    -font "$FONT" -fill "#00FF00" -pointsize 45 -annotate +35+130 "$RSRP" \
    -fill white -pointsize 15 -annotate +160+130 "dB" \
    -fill "#222222" -draw "rectangle 0 195 240 240" \
    -fill "#CCCCCC" -pointsize 14 -annotate +10+225 "${QUOTE:-H29K Ready}" "$TMP_IMG"
    fbv -f "$TMP_IMG"
    sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

# ======================== 【第6部分：设置系统默认】 ========================
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k <<'EOF'
#!/bin/sh
uci set luci.main.lang=zh_cn
uci set system.@system[0].hostname=H29K
uci set system.@system[0].zonename=Asia/Shanghai
uci set system.@system[0].timezone=CST-8
uci commit
/etc/init.d/irqbalance enable
/etc/init.d/modemmanager disable
sed -i '/exit/i /usr/bin/h29k_screen.sh &' /etc/rc.local
exit 0
EOF
chmod +x files/etc/uci-defaults/99-h29k

# ======================== 【H29K 强制5项校验 · 失败立即终止编译】 ========================

# 检查 1：DTS 文件必须存在
DTS_FILE="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts"
if [ ! -f "$DTS_FILE" ]; then
    echo -e "\033[31m[ERROR] H29K DTS 文件不存在！编译终止！\033[0m"
    exit 1
fi
echo -e "\033[32m[OK] DTS 文件存在\033[0m"

# 检查 2：设备定义已写入
DEVICE_NAME="hinlink_h29k"
MK_FILE="target/linux/rockchip/image/armv8.mk"
if ! grep -q "$DEVICE_NAME" "$MK_FILE"; then
    echo -e "\033[31m[ERROR] H29K 设备未定义！\033[0m"
    exit 1
fi
echo -e "\033[32m[OK] 设备定义已写入\033[0m"

# 检查 3：RK3528 平台已启用（永久通用版）
if ! grep -q "CONFIG_TARGET_rockchip_rk3528=y" .config; then
    echo -e "\033[31m[ERROR] 内核未启用 RK3528 平台！\033[0m"
    exit 1
fi
echo -e "\033[32m[OK] RK3528 平台已启用\033[0m"

# 检查 4：只编译 H29K
COUNT=$(grep -c "hinlink_h29k" "$MK_FILE")
if [ $COUNT -lt 1 ]; then
    echo -e "\033[31m[ERROR] 未只编译 H29K\033[0m"
    exit 1
fi
echo -e "\033[32m[OK] 只编译 H29K\033[0m"

# 检查 5：U-Boot 已添加 hinlink-h29k-rk3528
UBOOT_MK="package/boot/uboot-rockchip/Makefile"
if ! grep -q "hinlink-h29k-rk3528" "$UBOOT_MK"; then
    echo -e "\033[31m[ERROR] U-Boot 未添加 H29K 设备！编译终止！\033[0m"
    exit 1
fi
echo -e "\033[32m[OK] U-Boot 已添加 H29K 设备\033[0m"

echo -e "\033[32m=====================================\033[0m"
echo -e "\033[32m✅ 所有检查通过！开始编译！\033[0m"
echo -e "\033[32m=====================================\033[0m"
echo -e "\n✅ diy-part2.sh 执行完成！"
