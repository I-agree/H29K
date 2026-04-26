#!/bin/bash
set -e

# ==============================================
# 【永久通用版】自动匹配所有内核版本
# 彻底杜绝未来所有递归依赖循环
# ==============================================
FILE="package/kernel/linux/modules/video.mk"

echo "== 永久修复：自动移除 drm-client-lib 内核版本依赖 =="
if grep -q 'DEPENDS:=@DISPLAY_SUPPORT +@LINUX_[0-9]*_[0-9]*' "$FILE"; then
    echo "✅ 找到内核版本依赖，执行永久修复..."
    sed -i 's/DEPENDS:=@DISPLAY_SUPPORT +@LINUX_[0-9]*_[0-9]*/DEPENDS:=@DISPLAY_SUPPORT/' "$FILE"
    echo "✅ 永久修复完成！未来任何内核升级都不会再触发循环！"
else
    echo "❌ 错误：未找到需要修复的依赖！脚本停止！"
    exit 1
fi

# ======================== 【第一部分：资源准备】 ========================
echo "执行基础资源下载..."

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

DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_DIR" files/etc/config/screen bin/targets/rockchip/armv8

download_file "https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts" "$DTS_DIR/rk3528-opc-h29k.dts" "设备树"

LOGO_RAW_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"
for i in 1 2 3; do
  download_file "${LOGO_RAW_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg" "LOGO${i}"
done

# ======================== 【第二部分：内核配置】 ========================
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

# ======================== 【第三部分：设备定义】 ========================
TARGET_MK="target/linux/rockchip/image/armv8.mk"

# ========== 保留H28K定义（不影响其框架）增加H29K定义 ==========
cat >> "$TARGET_MK" <<'EOF'
define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_ALT0_VENDOR := HINLINK恒领科技
  DEVICE_DTS := rk3528-opc-h29k
  UBOOT_DEVICE_NAME := hinlink-h29k
  DEVICE_PACKAGES := kmod-usb3 kmod-usb-net-rtl8152 kmod-r8169 kmod-aic8800-sdio wpad-openssl dnsmasq-full kmod-mtk_t7xx kmod-usb-net-cdc-mbim uqmi kmod-usb-net-rndis-host kmod-usb-serial-option kmod-h29k-fb-st7789v luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn luci-theme-argon fbv imagemagick wqy-microhei curl irqbalance luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF

# ======================== 【第四部分：屏幕脚本】 ========================
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

# ======================== 【第五部分：设置系统默认】 ========================
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

# ======================== 【第六部分：H28K 基准配置 → H29K 纯净配置】 ========================
echo "===== 生成 H28K 基准配置 ====="
cat > .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k=y
EOF
make defconfig

# ==============================================================================
# 自动配置 U-Boot for HINLINK H29K
# ==============================================================================
UBOOT_MAKEFILE="package/boot/uboot-rockchip/Makefile"

echo "== 配置 U-Boot：hinlink-h29k"

# 1. 删除 Makefile 里已有的 H29K 配置（防止重复）
sed -i '/define U-Boot\/hinlink-h29k/,/endef/d' "$UBOOT_MAKEFILE"

# 2. 在 RK3528 区域插入 H29K 配置
sed -i '/define U-Boot\/hinlink-h28k-rk3528/a\
define U-Boot/hinlink-h29k\
  $(U-Boot/rk3528/Default)\
  NAME:=HINLINK H29K\
  BUILD_DEVICES := hinlink_h29k\
endef\
' "$UBOOT_MAKEFILE"

# 3. 把 hinlink-h29k 加入 UBOOT_TARGETS
sed -i '/hinlink-h28k-rk3528/a\  hinlink-h29k' "$UBOOT_MAKEFILE"

# 4. 清理旧 uboot config，添加 H29K 专用 CONFIG
sed -i '/CONFIG_PACKAGE_uboot-rockchip/d' .config
echo "CONFIG_PACKAGE_uboot-rockchip-hinlink_h29k=y" >> .config
echo "✅ U-Boot 配置完成：hinlink-h29k"

echo "===== 切换为 H29K 纯净配置 ====="
# ========== 修改点：仅替换设备名，保留H28K的rk3528内核配置框架 ==========
sed -i 's/CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k=y/CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y/' .config
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k/d' .config
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

rm -rf tmp
make defconfig

echo -e "\n✅ 代码运行完成，祝你好运！\n"
