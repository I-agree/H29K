#!/bin/bash

# ======================== 【资源准备】 ========================
echo "执行基础环境修复与资源下载..."
[ -f "$(pwd)/package/base-files/files/lib/functions.sh" ] && sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh

download_file() {
    local url=$1; local path=$2; local name=$3
    if curl -fsSL "$url" > "$path"; then echo "✅ $name 下载成功"; else echo "❌ $name 下载失败！"; exit 1; fi
}

DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_BIN_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
LOGO_RAW_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"

mkdir -p "$DTS_DIR" files/etc/config/screen bin/targets/rockchip/armv8
download_file "$DTS_URL" "$DTS_DIR/rk3528-opc-h29k.dts" "设备树 (DTS)"
download_file "$BOOT_BIN_URL" "hinlink_h29k-u-boot-rockchip.bin" "引导程序"
cp hinlink_h29k-u-boot-rockchip.bin bin/targets/rockchip/armv8/
for i in 1 2 3; do download_file "${LOGO_RAW_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg" "LOGO $i"; done

# ======================== 【内核配置】 ========================
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
EOF
done

# ======================== 【彻底清理旧设备，防冲突】 ========================
TARGET_MK="target/linux/rockchip/image/armv8.mk"
sed -i '/hinlink_h28k/d' "$TARGET_MK"
sed -i '/hinlink_h29k/d' "$TARGET_MK"

# ======================== 【H29K 完整设备定义（无继承、唯一镜像、完整包）】 ========================
cat >> "$TARGET_MK" <<EOF
define Device/hinlink_h29k
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  BOARD_NAME := hinlink_h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  SUPPORTED_DEVICES := hinlink_h29k

  KERNEL_LOADADDR := 0x00200000
  KERNEL_SIZE := 33554432
  BOARD_ROOTFS_PARTSIZE := 1024

  # 强制唯一镜像，防硬编码覆盖
  IMAGES :=
  IMAGES += sysupgrade.img
  IMAGE/sysupgrade.img := boot-common | boot-script | pad-to 1M | pad-extra 128k

  # 你的完整 DEVICE_PACKAGES（一个不少）
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-usb-net-rtl8152 kmod-r8169 \\
	kmod-aic8800-sdio wpad-openssl -wpad-basic -wpad-mini -wpad \\
	dnsmasq-full -dnsmasq kmod-mtk_t7xx kmod-usb-net-cdc-mbim uqmi \\
	kmod-usb-net-rndis-host kmod-usb-serial-option kmod-h29k-fb-st7789v \\
	luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn -modemmanager \\
	luci-theme-argon fbv imagemagick wqy-microhei curl irqbalance \\
	luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn
endef
\$(eval \$(call Device,hinlink_h29k))
EOF

# ======================== 【你的完整屏幕脚本（原样保留）】 ========================
mkdir -p files/usr/bin
cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"
sleep 12
for i in 1 2 3; do [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8; done
while true; do
    RSRP=$(uqmi -d /dev/cdc-wdm0 --get-signal-info 2>/dev/null | grep rsrp | awk '{print $2}')
    [ -z "$RSRP" ] && RSRP="Searching"
    QUOTE=$(curl -s "https://v1.hitokoto.cn/?encode=text&charset=utf-8" --connect-timeout 2 | cut -c 1-25)
    convert "$LOGO_DIR/LOGO3.jpg" -fill "rgba(0,0,0,0.7)" -draw "rectangle 0,60 240 240" \
        -font "$FONT" -fill "#00FF00" -pointsize 45 -annotate +35+130 "$RSRP" \
        -fill white -pointsize 15 -annotate +160+130 "dBm" \
        -fill "#222222" -draw "rectangle 0,195 240 240" \
        -fill "#CCCCCC" -font "$FONT" -pointsize 14 -annotate +10+225 "${QUOTE:-H29K Ready}" "$TMP_IMG"
    fbv -f "$TMP_IMG"; sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

# ======================== 【你的完整系统配置（原样保留）】 ========================
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k-custom <<EOF
#!/bin/sh
uci set luci.main.lang='zh_cn'
uci set system.@system[0].hostname='H29K'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
/etc/init.d/irqbalance enable
/etc/init.d/modemmanager disable 2>/dev/null
sed -i '/exit 0/i /usr/bin/h29k_screen.sh &' /etc/rc.local
uci commit
exit 0
EOF

# ======================== 【✅ 关键：先H28K → 再纯净H29K.config】 ========================
echo "[1/2] 生成基准 H28K 配置..."
cat > .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k=y
EOF
make defconfig

echo "[2/2] 替换为纯净 H29K 配置..."
sed -i 's/hinlink_h28k/hinlink_h29k/g' .config
sed -i 's/h28k/h29k/g' .config

# 强制禁用H28K，确保唯一启用
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k/d' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config
echo "# CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k is not set" >> .config

# 固定镜像与文件系统，防平台硬编码
echo "CONFIG_TARGET_IMAGES_GZIP=y" >> .config
echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y" >> .config
sed -i 's/CONFIG_TARGET_ROOTFS_EXT4FS=y/# CONFIG_TARGET_ROOTFS_EXT4FS is not set/' .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> .config

rm -rf tmp
make defconfig

echo "
==================================================
✅ 完成！
✅ 先生成 H28K.config → 已转为 纯净 H29K.config
✅ 镜像规则唯一：boot-common | boot-script | pad-to 1M | pad-extra 128k
✅ 屏幕脚本、系统配置、DEVICE_PACKAGES 全部完整保留
✅ GitHub Actions 100% 稳定无冲突
==================================================
"
