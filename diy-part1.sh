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

# === 6. axs5106触摸驱动
# git clone https://github.com/I-agree/axs5106.git package/kernel/modules/axs5106

# ======================== 【统一下载与文件校验中心】 ========================
echo "📥 开始统一拉取 H29K 编译所需的核心外置资源..."

# 创建全局所需的所有目录架构 (新增 files/www 网页容器支撑)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip \
         package/boot/uboot-rockchip/configs/hinlink/h29k \
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
         package/boot/uboot-rockchip/BUG66 \
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
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"
download_and_check "${BASE_URL}/target/linux/rockchip/image/armv8.mk" "target/linux/rockchip/image/armv8.mk"
download_and_check "${BASE_URL}/target/linux/rockchip/Makefile" "target/linux/rockchip/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/Makefile" "package/boot/uboot-rockchip/Makefile"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k-u-boot.dtsi" "package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k-u-boot.dtsi"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts" "package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts"
# download_and_check "${BASE_URL}/package/boot/rkbin/Makefile" "package/boot/rkbin/Makefile"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink/h29k/h29k.env" "package/boot/uboot-rockchip/configs/hinlink/h29k/h29k.env"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink/h29k/Makefile" "package/boot/uboot-rockchip/configs/hinlink/h29k/Makefile"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink/h29k/Kconfig" "package/boot/uboot-rockchip/configs/hinlink/h29k/Kconfig"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink/h29k/board.c" "package/boot/uboot-rockchip/configs/hinlink/h29k/board.c"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink/Kconfig" "package/boot/uboot-rockchip/configs/hinlink/Kconfig"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/900-fix-mb-missing-header.patch" "package/boot/uboot-rockchip/patches/900-fix-mb-missing-header.patch"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/901-fix-dwc3-dma-proto.patch" "package/boot/uboot-rockchip/patches/901-fix-dwc3-dma-proto.patch"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/902-fix-binman-remove-unused-empty-arg.patch" "package/boot/uboot-rockchip/patches/902-fix-binman-remove-unused-empty-arg.patch"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/904-fix-dts-remove-tee-fit.patch" "package/boot/uboot-rockchip/patches/904-fix-dts-remove-tee-fit.patch"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/998-add-hinlink-h29k-board-files.patch" "package/boot/uboot-rockchip/patches/998-add-hinlink-h29k-board-files.patch"
# download_and_check "${BASE_URL}/package/boot/uboot-rockchip/patches/999-add-hinlink-h29k-support.patch" "package/boot/uboot-rockchip/patches/999-add-hinlink-h29k-support.patch"

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
sed -i 's/^CONFIG_CMA_SIZE_MBYTES=.*$/CONFIG_CMA_SIZE_MBYTES=32/' "$CONFIG_FILE"

cat >> "$CONFIG_FILE" << 'EOF'

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

EOF
echo "✅ H29K 内核参数注入完成"
