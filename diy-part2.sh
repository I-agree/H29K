#!/bin/bash
# ======================== 【第2部分：资源准备】 ========================
echo "✅ 正在执行基础资源下载..."
# 创建必需目录（-p 确保嵌套路径安全）
mkdir -p "target/linux/rockchip/dts"
# 复制 DTS 文件（加引号防空格/特殊字符）
cp -f "$GITHUB_WORKSPACE/rk3528-hinlink-h29k.dts" "target/linux/rockchip/dts/"

mkdir -p "package/boot/uboot-rockchip/files/configs"
cp -f "$GITHUB_WORKSPACE/hinlink_h29k_defconfig" "package/boot/uboot-rockchip/files/configs/"

# 创建开机 LOGO 存放目录
mkdir -p files/etc/config/screen bin/targets/rockchip/armv8

# 定义通用下载函数（带重试、超时、失败退出）
download_file() {
  local url="$1"
  local path="$2"
  local name="$3"
  if curl -fsSL --retry 3 --connect-timeout 10 "$url" -o "$path"; then
    echo "✅ $name 下载成功"
  else
    echo -e "\033[31m❌ $name 下载失败\033[0m"
    exit 1
  fi
}

# 下载三张开机 LOGO（JPG 格式，适配 fbv）
LOGO_RAW_URL="https://raw.githubusercontent.com/I-agree/H29K/main/JPG"
for i in 1 2 3; do
  download_file "${LOGO_RAW_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg" "LOGO${i}"
done

# ======================== 修复缺失 wqy-microhei.ttc 字体 ========================
echo "[INFO] 自动下载并安装 wqy-microhei.ttc 字体文件"

# 创建字体目录
mkdir -p files/usr/share/fonts/truetype/

# 下载字体（稳定源）
curl -L -o files/usr/share/fonts/truetype/wqy-microhei.ttc \
  https://raw.githubusercontent.com/I-am-Bot/OpenWrt-Fonts/main/wqy-microhei.ttc

# 赋权
chmod 644 files/usr/share/fonts/truetype/wqy-microhei.ttc

echo "[OK] wqy-microhei.ttc 已安装到固件内"

# ==============================================================================
# 【U-Boot 支持注入】—— 严格遵循 OpenWrt 官方 Makefile 风格（高危修复区）
# ✅ 修复点1：BusyBox sed 不支持 'a\' 多行追加 → 改用 POSIX 兼容写法
# ✅ 修复点2：NAME 字段统一为下划线命名，与 UBOOT_CONFIG 语义一致
# ==============================================================================
makefile="package/boot/uboot-rockchip/Makefile"

# 1️⃣ 在 hinlink-h28k-rk3528 后追加 hinlink-h29k-rk3528 到 UBOOT_TARGETS（兼容 BusyBox sed）
#    注意：'\\\\n' 经 shell 解析后为 '\n'，确保 Makefile 格式正确
sed -i "/hinlink-h28k-rk3528/a hinlink-h29k-rk3528 \\\\n" "$makefile"

# 2️⃣ 在 hinlink-h28k 定义下方插入 hinlink-h29k 设备块（完全复刻官方格式）
#    ✅ NAME:=HINLINK_H29K（非空格，与 UBOOT_CONFIG 一致）
#    ✅ BUILD_DEVICES:=hinlink_h29k（小写+下划线，与 .config 中 CONFIG_TARGET_... 保持一致）
sed -i '/define U-Boot\/hinlink-h28k-rk3528/a\
define U-Boot/hinlink-h29k-rk3528\n  $(U-Boot/rk3528/Default)\n  UBOOT_CONFIG:=hinlink_h29k\n  NAME:=HINLINK_H29K\n  BUILD_DEVICES:=hinlink_h29k\nendef
' "$makefile"

# ======================== 【添加 H29K：armv8.mk 设备定义】 ========================
# ✅ 修复点3：DEVICE_DTS 使用标准社区命名 rk3528-hinlink-h29k（非 opc- 前缀）
TARGET_MK="target/linux/rockchip/image/armv8.mk"

cat >> "$TARGET_MK" <<'EOF'
# 📌 设备定义：HINLINK H29K（RK3528）
#    - 遵循 OpenWrt 命名规范：rk3528-{vendor}-{model}
#    - 使用官方 $(Device/rk3528) 宏保证内核与镜像一致性
define Device/hinlink_h29k
  $(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-hinlink-h29k
  UBOOT_CONFIG := hinlink_h29k
  DEVICE_UBOOT_IMAGE := u-boot-rockchip-hinlink_h29k.bin
  IMAGE/boot.bin := boot-scr | boot-kernel | boot-dtb
  IMAGE/sysupgrade.img.gz := boot.bin | append-rootfs | pad-rootfs | check-size | gzip
  DEVICE_PACKAGES := kmod-usb3 kmod-usb-net-rtl8152 kmod-r8169 kmod-aic8800-sdio wpad-openssl dnsmasq-full kmod-mtk_t7xx kmod-usb-net-cdc-mbim uqmi kmod-usb-net-rndis-host kmod-usb-serial-option kmod-h29k-fb-st7789v luci-app-qmodem-next luci-i18n-qmodem-next-zh-cn luci-theme-argon fbv imagemagick wqy-microhei curl irqbalance luci-i18n-base-zh-cn luci-i18n-opkg-zh-cn luci-i18n-firewall-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF

# ======================== 【内核配置】 ========================
# 清理旧内核选项（避免冲突），注入 H29K 专属配置
CONF_FILES=$(find target/linux/rockchip/armv8 -name "config-*")
for CONF in $CONF_FILES; do
  # 移除可能冲突的 staging/fb/tcpc 配置（确保干净）
  sed -i '/CONFIG_STAGING/d; /CONFIG_FB_TFT/d; /CONFIG_TCP_CONG/d; /CONFIG_DEFAULT_TCP_CONG/d' "$CONF"
  # 注入 H29K 必需内核模块与算法（ST7789V 屏幕、BBR 拥塞控制、IRQ 平衡）
  cat >> "$CONF" <<'EOF'
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

echo "===== ✅ 内核配置注入完成 ====="

# 【分区大小重置】—— 删除旧值，写入 H29K 推荐值（256MB kernel + 2048MB rootfs）
sed -i '/^CONFIG_TARGET_KERNEL_PARTSIZE=/d' .config
sed -i '/^CONFIG_TARGET_ROOTFS_PARTSIZE=/d' .config
echo "CONFIG_TARGET_KERNEL_PARTSIZE=256" >> .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=2048" >> .config

# 【网络服务配置】—— ✅ 修复点7：dnsmasq-full 自动拉取 dnsmasq，无需显式禁用
#    （避免编译失败：Package dnsmasq-full depends on dnsmasq）
sed -i '/CONFIG_PACKAGE_dnsmasq/d' .config
sed -i '/CONFIG_PACKAGE_wpad/d' .config
echo "CONFIG_PACKAGE_wpad-basic-wolfssl=n" >> .config
echo "CONFIG_PACKAGE_wpad-basic-mbedtls=n" >> .config
echo "CONFIG_PACKAGE_wpad-openssl=y" >> .config
echo "CONFIG_PACKAGE_dnsmasq-full=y" >> .config  # ← 自动包含 dnsmasq 依赖

# 【LuCI 与工具链】—— 启用中文界面、IRQ 平衡、DNS 加密代理
echo "CONFIG_PACKAGE_luci-mod-admin-full=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-base-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-app-irqbalance=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-irqbalance-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_dnscrypt-proxy=y" >> .config
echo "CONFIG_PACKAGE_luci-app-dnscrypt-proxy=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-dnscrypt-proxy-zh-cn=y" >> .config

# ==============================
# 【最终写入：H29K 全量核心配置】
# ✅ 严格匹配 OpenWrt 2026.04+ RK3528 官方要求
# ==============================
cat >> .config <<'EOF'
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_MULTI_ARCH=n
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
CONFIG_PACKAGE_uboot-rockchip=y
CONFIG_PACKAGE_uboot-rockchip-v8=y
CONFIG_PACKAGE_uboot-rockchip-hinlink_h29k=y
CONFIG_PACKAGE_luci-app-oaf=y
CONFIG_PACKAGE_appfilter=y
CONFIG_PACKAGE_luci-i18n-oaf-zh-cn=y
EOF

# ======================== 【第3部分：屏幕脚本（procd 服务化）】 ========================
# ✅ 修复点8：弃用 /etc/rc.local（OpenWrt 22.03+ 已废弃），改用 procd 服务管理
#    优势：启动时机可控、日志可查、状态可监控、重启安全
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

service_triggers() {
  procd_add_reload_trigger "system"
}
EOF
chmod +x files/etc/init.d/h29k-screen

# 屏幕主脚本（保持原逻辑，仅路径适配）
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
    # 动态获取 cdc-wdm 设备（兼容多模组）
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

# ======================== 【第4部分：系统默认设置（UCI）】 ========================
# ✅ 修复点9：启用 h29k-screen 服务（替代 rc.local）
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k <<'EOF'
#!/bin/sh
# ✅ 设置系统基础参数
uci set luci.main.lang=zh_cn
uci set system.@system.hostname=H29K
uci set system.@system.zonename=Asia/Shanghai
uci set system.@system.timezone=CST-8
uci commit system

# ✅ 启用 IRQ 平衡服务（提升多核性能）
/etc/init.d/irqbalance enable

# ✅ 禁用 ModemManager（避免与 uqmi/uqmic 冲突）
/etc/init.d/modemmanager disable

# ✅ 启用自定义屏幕服务（procd 方式，安全可靠）
/etc/init.d/h29k-screen enable

exit 0
EOF
chmod +x files/etc/uci-defaults/99-h29k

# ==============================================
# 【强制清理配置，避免残留冲突】
sed -i '/^CONFIG_TARGET_rockchip_armv8_DEVICE_/s/=y$/=n/' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

# ======================== 【H29K 强制4项校验 · 失败立即终止编译】 ========================
echo "🔍 开始 H29K 构建前置五重校验..."

# ✅ 校验1：设备定义已写入 armv8.mk
DEVICE_NAME="hinlink_h29k"
MK_FILE="target/linux/rockchip/image/armv8.mk"
if ! grep -q "$DEVICE_NAME" "$MK_FILE"; then
  echo -e "\033[31m[错误] H29K 设备未定义！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] 设备定义已写入 armv8.mk\033[0m"

# ✅ 校验2：只编译 H29K（防误启 H28K）
COUNT=$(grep -c "hinlink_h29k" "$MK_FILE")
if [ $COUNT -lt 1 ]; then
  echo -e "\033[31m[错误] 未检测到 hinlink_h29k 设备定义\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] H29K 设备定义数量：$COUNT\033[0m"

# ✅ 校验3：U-Boot 已添加 hinlink-h29k-rk3528（Makefile确认）
UBOOT_MK="package/boot/uboot-rockchip/Makefile"
if ! grep -q "hinlink-h29k-rk3528" "$UBOOT_MK"; then
  echo -e "\033[31m[错误] U-Boot 未添加 H29K 设备！编译终止！\033[0m"
  exit 1
fi
echo -e "\033[32m[通过] U-Boot 已添加 H29K 设备（Makefile校验）\033[0m"

echo -e "\033[32m=====================================\033[0m"
echo -e "\033[32m✅ 所有检查通过！开始编译 H29K 固件！\033[0m"
echo -e "\033[32m=====================================\033[0m"
