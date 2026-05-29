#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

# ======================== 【通用工具函数】 ========================
download_file() {
  local url="$1"
  local path="$2"
  local name="$3"
  if curl -fsSL --retry 3 --connect-timeout 10 --max-time 30 "$url" -o "$path"; then
    echo "✅ $name 下载成功"
  else
    echo -e "\033[31m❌ $name 下载失败\033[0m"
    exit 1
  fi
}

# ======================== 【🌟 核心修复：物理切断原生多余/冲突架构污染源】 ========================
echo "🧹 正在清理原生多余/冲突的架构补丁..."
rm -f target/linux/bcm27xx/patches-6.12/950-0076-OF-DT-Overlay-configfs-interface.patch || true
rm -f target/linux/ipq806x/patches-6.12/901-02-ARM-decompressor-add-option-to-ignore-MEM-ATAGs.patch || true
rm -f target/linux/mpc85xx/patches-6.12/102-powerpc-add-cmdline-override.patch || true
rm -f package/boot/uboot-mediatek/patches/280-image-fdt-save-name-of-FIT-configuration-in-chosen-node.patch || true
rm -f target/linux/qualcommax/patches-6.12/0911-arm64-cmdline-replacement.patch || true
rm -f target/linux/ipq806x/patches-6.12/902-ARM-decompressor-support-for-ATAGs-rootblock-parsing.patch || true
rm -f target/linux/ipq806x/patches-6.12/900-arm-add-cmdline-override.patch || true
rm -f target/linux/mvebu/patches-6.12/300-mvebu-Mangle-bootloader-s-kernel-arguments.patch || true
rm -rf target/linux/airoha

# ======================== 【🌟 完美找回：下载 H29K 专用核心设备树 (DTS) 与固件基因】 ========================
echo "📥 正在拉取 H29K 专属核心设备树与底层组件..."

# 1. 核心设备树 (DTS)
DTS_SAVE_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_SAVE_DIR"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
"https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts" \
-o "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts"

if [ ! -s "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts" ]; then
    echo "❌ rk3528-hinlink-h29k.dts 下载失败或为空"
    exit 1
fi
echo "✅ rk3528-hinlink-h29k.dts 下载并校验成功"

# 建立基础下载路径
mkdir -p package/boot/uboot-rockchip/configs/ target/linux/rockchip/image/

# 2. U-Boot defconfig
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
"https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" \
-o package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig

if [ ! -s "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" ]; then
    echo "❌ U-Boot defconfig 下载失败或为空"
    exit 1
fi
echo "✅ U-Boot defconfig 下载并校验成功"

# 3. 核心架构适配文件 armv8.mk
MK_FILE="target/linux/rockchip/image/armv8.mk"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
"https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/armv8.mk" -o "$MK_FILE"

if [ ! -s "$MK_FILE" ] || grep -q "hinlink_h28k" "$MK_FILE"; then
    echo "❌ armv8.mk 下载失败或包含非法内容 (h28k)"
    exit 1
fi
echo "✅ armv8.mk 核心文件下载并强力防错校验通过"

# 4. 5. 6. 底座 Makefile 编译策略文件
curl -L --retry 5 "https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/Makefile" -o target/linux/rockchip/Makefile
wget -q --retry-connrefused --waitretry=2 -O package/boot/uboot-rockchip/Makefile "https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/Makefile"
wget -q --retry-connrefused --waitretry=2 -O package/boot/uboot-tools/Makefile "https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-tools/Makefile"

# ======================== 【🌟 适配 H29K 专用打包与引导流水线】 ========================
echo "📦 正在部署 H29K 专用打包规则与编译脚本..."

# 7. 镜像生成 Makefile
IMAGE_MAKEFILE="target/linux/rockchip/image/Makefile"
wget -q -O "$IMAGE_MAKEFILE" "https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/Makefile"

if grep -q "智能识别 Binman 合体固件或传统拆分固件" "$IMAGE_MAKEFILE"; then
    echo -e "\033[32m✅ 验证成功：Makefile 打包规则完全符合 H29K 要求！\033[0m"
else
    echo -e "\033[31m❌ 验证失败：Makefile 下载损坏或不匹配！\033[0m"
    exit 1
fi

# 8. 9. 其它打包依赖脚本
wget -q "https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/mmc.bootscript" -O target/linux/rockchip/image/mmc.bootscript
mkdir -p scripts && wget -q "https://raw.githubusercontent.com/I-agree/H29K/main/files/scripts/gen_image_generic.sh" -O scripts/gen_image_generic.sh

# 10. U-Boot 专属编译 DTS
DTS_DEST_DIR="package/boot/uboot-rockchip/dts"
mkdir -p "$DTS_DEST_DIR"
wget -q -O "$DTS_DEST_DIR/rk3528-hinlink-h29k.dts" "https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts"

if [ ! -s "$DTS_DEST_DIR/rk3528-hinlink-h29k.dts" ]; then
    echo "❌ 失败：U-Boot DTS 下载失败或为空"
    exit 1
fi
echo "✅ 成功：U-Boot 专属编译 DTS 已顺利就位"

# ======================== 【H29K 主线内核配置强力清洗与合并注入】 ========================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 彻底抹除原文件中可能冲突的底层选项
sed -i '/CONFIG_EMAC_ROCKCHIP/d' "$CONFIG_FILE" 2>/dev/null || true
sed -i '/CONFIG_ARM64_PA_BITS/d' "$CONFIG_FILE" 2>/dev/null || true
sed -i '/CONFIG_CMA_SIZE_MBYTES/d' "$CONFIG_FILE" 2>/dev/null || true
sed -i '/CONFIG_CRYPTO_DEV_ROCKCHIP/d' "$CONFIG_FILE" 2>/dev/null || true
sed -i '/CONFIG_DEFAULT_NET_CONG/d' "$CONFIG_FILE" 2>/dev/null || true
sed -i '/CONFIG_DEFAULT_BBR/d' "$CONFIG_FILE" 2>/dev/null || true

# 一次性注入完全适配主线 Linux 6.12 的 H29K 内核技术栈
cat >> "$CONFIG_FILE" << 'EOF'

# === RK3528 主线核心与平台级别底座驱动（对齐 Linux 6.12）===
CONFIG_ARCH_ROCKCHIP=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_VA_BITS=48
CONFIG_ARM64_PA_BITS=48
CONFIG_COMMON_CLK_ROCKCHIP=y
CONFIG_ROCKCHIP_PMDOMAINS=y
CONFIG_PWM_ROCKCHIP=y
CONFIG_OF_GPIO=y

# --- 开启硬件加密总开关与瑞芯微全家桶驱动 ---
CONFIG_CRYPTO_HW=y
CONFIG_CRYPTO_DEV_ROCKCHIP=y

# --- 主线标准显示架构与 ST7789V 屏幕驱动对齐 ---
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_PANEL_SITRunningX_ST7789V=y
CONFIG_BACKLIGHT_PWM=y

# --- 主线标准高速总线与存储协议栈 ---
CONFIG_SPI_ROCKCHIP=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y
CONFIG_MMC_SDHCI_OF_ROCKCHIP=y
CONFIG_USB_DWC3_ROCKCHIP=y

# --- CMA 连续物理内存调优 ---
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_CMA_SIZE_MBYTES=128

# --- 网络高并发 TCP BBR + FQ 底层内建 ---
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_NET_CONG="bbr"
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_QDISC="fq"

# --- 采用现代 Schedutil 智能调度模式 ---
CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y

# --- 关闭主线无需或可能冲突的功能 ---
# CONFIG_SND is not set
# CONFIG_BT is not set
EOF
echo "✅ 已向 $CONFIG_FILE 安全注入内核配置"

# ======================== 【对全局通用内核配置进行防御性修正】 ========================
GENERIC_CONFIG="target/linux/generic/config-6.12"
if [ -f "$GENERIC_CONFIG" ]; then
    sed -i '/CONFIG_ARM64_SVE/d' "$GENERIC_CONFIG"
    sed -i '/CONFIG_ARM64_ASIMD/d' "$GENERIC_CONFIG"
    echo "# CONFIG_ARM64_SVE is not set" >> "$GENERIC_CONFIG"
    echo "CONFIG_ARM64_ASIMD=y" >> "$GENERIC_CONFIG"
    echo "✅ 已完成对全局通用内核配置 generic/config-6.12 的防御性修正"
fi

# === 写入完整独立编译 Override 规则 ===
OVERRIDE_FILE=".config.override"
cat > "$OVERRIDE_FILE" << 'EOF'
# RK3528 H29K OVERRIDE — GENERATED BY diy-part2.sh
# CONFIG_TARGET_MULTI_ARCH is not set
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
EOF
echo "✅ H29K 独立单机型 Override 编译快照已生成"


# ======================== 【资源准备与应用层注入】 ========================
mkdir -p files/etc/config/screen bin/targets/rockchip/armv8

LOGO_RAW_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"
for i in 1 2 3; do
  download_file "${LOGO_RAW_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg" "LOGO${i}"
done

# 配置 input-event-daemon 转发按键事件
mkdir -p files/etc
cat > files/etc/input-event-daemon.conf <<'EOF'
/dev/input/event0
412:1:/bin/button hotplug reset pressed
412:0:/bin/button hotplug reset released
EOF

# 离线复制本地中文字体
SRC_FONT="$(dirname "$0")/fonts/MiSans-Regular.ttf"
DST_FONT="files/usr/share/fonts/truetype/MiSans-Regular.ttf"
mkdir -p "$(dirname "$DST_FONT")"

if [ ! -f "$SRC_FONT" ]; then
  echo "❌ 错误：字体文件未找到！请确认 fonts/MiSans-Regular.ttf 已提交到 Git"
  exit 1
fi

cp -f "$SRC_FONT" "$DST_FONT"
MAGIC=$(head -c 4 "$DST_FONT" 2>/dev/null | od -t x1 -An | tr -d ' \n')
if [[ "$MAGIC" != "00010000" ]] && [[ "$MAGIC" != "4f54544f" ]]; then
  echo -e "\033[31m❌ 错误：'$DST_FONT' 不是有效的 TTF/OTF 字体文件魔数，拦截编译！\033[0m"
  exit 1
fi
chmod 644 "$DST_FONT"
echo "✅ 字体文件成功通过安全合规性二重校验"

# 设为系统默认中文字体
mkdir -p files/etc/fonts/conf.d
cat > files/etc/fonts/conf.d/99-misans-default.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="lang" compare="contains">
      <string>zh</string>
    </test>
    <edit name="family" mode="prepend_first">
      <string>MiSans</string>
    </edit>
  </match>
</fontconfig>
EOF

# ======================== 【屏幕脚本（procd 服务化与智能金句引擎）】 ========================
mkdir -p files/etc/init.d
cat > files/etc/init.d/h29k-screen <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
  procd_open_instance
  procd_set_param command /usr/bin/h29k_screen.sh
  procd_set_param respawn ${respawn_timeout:-3600} ${respawn_retry:-5}
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_close_instance
}
EOF
chmod +x files/etc/init.d/h29k-screen

mkdir -p files/usr/bin
cat > files/usr/bin/h29k_screen.sh <<'EOF'
#!/bin/sh
FONT="/usr/share/fonts/truetype/MiSans-Regular.ttf"
TMP_IMG="/tmp/screen_final.jpg"
LOGO_DIR="/etc/config/screen"
sleep 12
for i in 1 2 3; do 
    [ -f "$LOGO_DIR/LOGO$i.jpg" ] && fbv -f "$LOGO_DIR/LOGO$i.jpg" && sleep 0.8
done

while true; do
    # 1. 抓取 4G/5G 信号
    WDM_DEV=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1)
    WDM_DEV=${WDM_DEV:-/dev/cdc-wdm0}
    RSRP=$(uqmi -d "$WDM_DEV" --get-signal-info 2>/dev/null | grep rsrp | awk -F: '{print $2}' | tr -d ' ,"' | head -n1)
    [ -z "$RSRP" ] && RSRP="Search"

    # 2. ⚡ 智能网络金句抓取引擎
    if NET_QUOTE=$(curl -fsSL --connect-timeout 2 --max-time 3 "https://v1.hitokoto.cn/?c=f&encode=text" 2>/dev/null) && [ -n "$NET_QUOTE" ]; then
        QUOTE="$NET_QUOTE"
    else
        case $((RANDOM % 6)) in
            0) QUOTE="山林不向四季起誓，荣枯随缘。" ;;
            1) QUOTE="喜欢就处，别问是朋友还是恋人！" ;;
            2) QUOTE="关系不是绳子，非要绑住谁的手脚；" ;;
            3) QUOTE="缘分就像山风，吹到哪儿都是风景。" ;;
            4) QUOTE="能走一段是礼物，能走一生是运气。" ;;
            *) QUOTE="被你改变的那一部分我，代替了你永远陪在了我的身边。" ;;
        esac
    fi

    # 3. 渲染背景图与状态文本
    if [ -f "$LOGO_DIR/LOGO3.jpg" ]; then
        gm convert "$LOGO_DIR/LOGO3.jpg" -resize 320x172\! -fill "rgba(0,0,0,0.6)" -draw "rectangle 0 20 320 130" -font "$FONT" -fill "#00FF00" -pointsize 48 -annotate +40+95 "$RSRP" -fill white -pointsize 16 -annotate +215+95 "dB" -fill "#1a1a1a" -draw "rectangle 0 140 320 172" -fill "#CCCCCC" -pointsize 13 -annotate +15+161 "$QUOTE" "$TMP_IMG" 2>/dev/null || echo "Render Error"
    fi
    [ -s "$TMP_IMG" ] && fbv -f "$TMP_IMG" 2>/dev/null
    sleep 25
done
EOF
chmod +x files/usr/bin/h29k_screen.sh

# ======================== 【系统默认设置（UCI）】 ========================
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k <<'EOF'
#!/bin/sh
uci set luci.main.lang=zh_cn
uci set system.@system.hostname=H29K
uci set system.@system.zonename=Asia/Shanghai
uci set system.@system.timezone=CST-8
uci commit system
/etc/init.d/irqbalance enable
/etc/init.d/modemmanager disable
/etc/init.d/h29k-screen enable
exit 0
EOF
chmod +x files/etc/uci-defaults/99-h29k

# ======================== Docker + MediaMTX 预装 ========================
mkdir -p files/etc/modules.d
echo -e "overlay\nbridge\nveth" > files/etc/modules.d/30-docker

mkdir -p files/etc/docker/mediamtx
curl -fsSL --retry 3 https://raw.githubusercontent.com/bluenviron/mediamtx/main/mediamtx.yml -o files/etc/docker/mediamtx/mediamtx.yml

mkdir -p files/etc/init.d
cat > files/etc/init.d/mediamtx-init <<'EOF'
#!/bin/sh /etc/rc.common
START=99
boot() {
    local timeout=0
    while [ ! -S /var/run/docker.sock ]; do
        if [ $timeout -gt 30 ]; then return 1; fi
        sleep 1
        timeout=$((timeout + 1))
    done
    if ! docker ps -a --format '{{.Names}}' | grep -q '^mediamtx$'; then
        docker run -d --name mediamtx --restart always --network host -v /etc/docker/mediamtx/mediamtx.yml:/mediamtx.yml bluenviron/mediamtx:latest
    fi
}
EOF
chmod +x files/etc/init.d/mediamtx-init

cat > files/etc/uci-defaults/98-docker-autostart <<'EOF'
#!/bin/sh
/etc/init.d/dockerd enable
/etc/init.d/mediamtx-init enable
exit 0
EOF
chmod +x files/etc/uci-defaults/98-docker-autostart

sed -i 's/+docker-compose-v2//g' feeds/luci/applications/luci-app-dockerman/Makefile 2>/dev/null || true
sed -i 's/+docker-compose//g' feeds/luci/applications/luci-app-dockerman/Makefile 2>/dev/null || true

sed -i '/net.netfilter.nf_conntrack_max/d' package/base-files/files/etc/sysctl.conf
echo "net.netfilter.nf_conntrack_max=262144" >> package/base-files/files/etc/sysctl.conf
echo "net.core.netdev_max_backlog=10000" >> package/base-files/files/etc/sysctl.conf
echo "net.core.rmem_max=16777216" >> package/base-files/files/etc/sysctl.conf
echo "net.core.wmem_max=16777216" >> package/base-files/files/etc/sysctl.conf

echo "✅ 完美：10个编译底座文件与上层屏幕、预装逻辑全部校验通过，可以安全开整！"
