#!/bin/bash

# =========================================================
# 第一部分：【核心】基础环境修复与下载拦截
# =========================================================
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

# =========================================================
# 第二部分：内核驱动深度注入 (强制锁定 BBR + 5G + 屏幕)
# =========================================================
echo "正在注入内核配置与强制 BBR 算法..."
CONF_FILES=$(find target/linux/rockchip/armv8/ -name "config-*")
for CONF in $CONF_FILES; do
    sed -i '/CONFIG_STAGING/d; /CONFIG_FB_TFT/d; /CONFIG_JFFS2/d; /CONFIG_TCP_CONG/d; /CONFIG_DEFAULT_TCP_CONG/d' "$CONF"
    {
        echo "CONFIG_STAGING=y"
        echo "CONFIG_FB_TFT=y"
        echo "CONFIG_FB_TFT_ST7789V=y"
        echo "CONFIG_JFFS2_FS=y"
        echo "CONFIG_JFFS2_SUMMARY=y"
        echo "CONFIG_TCP_CONG_BBR=y"
        echo "CONFIG_DEFAULT_BBR=y"
        echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\""
        echo "CONFIG_USB_NET_CDC_MBIM=m"
        echo "CONFIG_MTK_T7XX=m"
    } >> "$CONF"
done

# =========================================================
# 第三部分：注册设备并【锁定分区大小】
# =========================================================
TARGET_MK="target/linux/rockchip/image/armv8.mk"
if [ -f "$TARGET_MK" ]; then
    # 【修改注释】：在追加前显式清理可能存在的重复定义，确保 Actions 环境下 target 唯一且有效
    sed -i '/Device\/hinlink_h29k/,/eval $(call Device,hinlink_h29k)/d' "$TARGET_MK"

    cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  BOARD_NAME := hinlink_h29k
  UBOOT_DEVICE_NAME := hinlink_h29k
  KERNEL_SIZE := 33554432
  KERNEL_LOADADDR := 0x00200000
  BOARD_ROOTFS_PARTSIZE := 1024
  IMAGES := sysupgrade.img.gz
  # --- 保持用户要求的原始对齐流水线 ---
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | append-rootfs | pad-to 1M | pad-extra 128k | gzip
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-usb-net-rtl8152 kmod-r8169 \\
	kmod-aic8800-sdio wpad-openssl -wpad-basic -wpad-mini -wpad \\
	dnsmasq-full -dnsmasq kmod-mtk_t7xx kmod-usb-net-cdc-mbim uqmi \\
	kmod-usb-net-rndis-host kmod-usb-serial-option kmod-h29k-fb-st7789v \\
	luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn -modemmanager \\
	luci-theme-argon fbv imagemagick wqy-microhei curl irqbalance \\
	luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# =========================================================
# 第四部分：屏幕联动脚本与自启动 (全中文环境)
# =========================================================
# (此部分无改动，略)
mkdir -p files/usr/bin
cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/ttf/wqy-microhei.ttc"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"
sleep 12
for i in 1 2 3; do [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8; done
while true; do
    RSRP=$(uqmi -d /dev/cdc-wdm0 --get-signal-info 2>/dev/null | grep rsrp | awk '{print $2}')
    [ -z "$RSRP" ] && RSRP="Searching"
    QUOTE=$(curl -s "https://v1.hitokoto.cn/?encode=text&charset=utf-8" --connect-timeout 2 | cut -c 1-25)
    convert "$LOGO_DIR/LOGO3.jpg" -fill "rgba(0,0,0,0.7)" -draw "rectangle 0,60 240,240" \
        -font "$FONT" -fill "#00FF00" -pointsize 45 -annotate +35+130 "$RSRP" \
        -fill white -pointsize 15 -annotate +160+130 "dBm" \
        -fill "#222222" -draw "rectangle 0,195 240,240" \
        -fill "#CCCCCC" -font "$FONT" -pointsize 14 -annotate +10+225 "${QUOTE:-H29K Ready}" "$TMP_IMG"
    fbv -f "$TMP_IMG"; sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

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

# =========================================================
# 第五部分：清理 dnsmasq/wpad 冲突、锁定 H29K、修复 JFFS2
# =========================================================
echo "执行最终配置硬化：清理冲突与身份锁定..."

# 【修改注释】：在 .config 中强制显式开启 H29K 目标，确保 Makefile 能够索引到 Device 定义
cat > .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h28k=y
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_h29k=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_luci-app-qmodem-next=y
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_wqy-microhei=y
CONFIG_PACKAGE_imagemagick=y
CONFIG_PACKAGE_fbv=y
EOF

make defconfig

sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/' .config
sed -i 's/CONFIG_PACKAGE_wpad-basic=y/# CONFIG_PACKAGE_wpad-basic is not set/' .config
sed -i 's/CONFIG_PACKAGE_wpad-mini=y/# CONFIG_PACKAGE_wpad-mini is not set/' .config
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config

# 【修改注释】：将所有 H28K 的内核/镜像索引强制重定向为 H29K，这是识别有效目标的关键补丁
sed -i 's/hinlink_h28k/hinlink_h29k/g' .config
sed -i 's/h28k/h29k/g' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

# 【修改注释】：在 Actions 脚本最后增加 rm -rf tmp，确保 Makefile 修改被系统重新扫描识别
rm -rf tmp
make defconfig

echo "✅ 修复完成。H29K 有效目标已锁定，分区大小 1024M 已同步。"
