#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)

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

# ==============================================================================
# 🛠️ [diy-part1.sh] 自动同步官方 main 分支最新的 uboot-tools 文件夹
# ==============================================================================

# 1. 强力清理本地原有的 uboot-tools 文件夹（防止旧文件残留）
rm -rf package/boot/uboot-tools

# 2. 确保创建临时工作目录
mkdir -p tmp

# 3. 使用 Git 稀疏模式克隆官方仓库的 main 分支
git clone --branch main --depth=1 --filter=blob:none --sparse https://github.com/openwrt/openwrt.git tmp/openwrt-main

# 4. 进入临时目录，精准命中并只检出 package/boot/uboot-tools 文件夹
cd tmp/openwrt-main
git sparse-checkout set package/boot/uboot-tools
cd ../..

# 5. 确保本地父目录存在，将完美的 uboot-tools 移动到本地核心包目录
mkdir -p package/boot
mv tmp/openwrt-main/package/boot/uboot-tools package/boot/

# 6. 彻底销毁临时垃圾，绝不污染源码树
rm -rf tmp/openwrt-main

# ==============================================================================

# ======================== 【统一下载与文件校验中心】 ========================
echo "📥 开始统一拉取 H29K 编译所需的核心外置资源..."

# 创建全局所需的所有目录架构 (新增 files/www 网页容器支撑)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip \
         package/boot/uboot-rockchip/configs \
         package/boot/uboot-rockchip/dts \
         target/linux/rockchip/image \
         scripts \
         files/etc/config/screen \
         files/etc/docker/mediamtx \
         files/etc/init.d \
         files/etc/fonts/conf.d \
         files/usr/bin \
         files/www \
         files/usr/share/docker-images

BASE_URL="https://raw.githubusercontent.com/I-agree/H29K/main/files"
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
download_and_check "${BASE_URL}/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts" "target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-hinlink-h29k.dts"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"
download_and_check "${BASE_URL}/target/linux/rockchip/image/armv8.mk" "target/linux/rockchip/image/armv8.mk"
download_and_check "${BASE_URL}/target/linux/rockchip/Makefile" "target/linux/rockchip/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/Makefile" "package/boot/uboot-rockchip/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-tools/Makefile" "package/boot/uboot-tools/Makefile"
download_and_check "${BASE_URL}/package/boot/uboot-tools/uboot-envtools/files/rockchip_armv8" "package/boot/uboot-tools/uboot-envtools/files/rockchip_armv8"
download_and_check "${BASE_URL}/target/linux/rockchip/image/Makefile" "target/linux/rockchip/image/Makefile"
download_and_check "${BASE_URL}/target/linux/rockchip/image/mmc.bootscript" "target/linux/rockchip/image/mmc.bootscript"
download_and_check "${BASE_URL}/scripts/gen_image_generic.sh" "scripts/gen_image_generic.sh"
download_and_check "${BASE_URL}/package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts" "package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts"

# --- 深度内容专项校验 ---
if grep -q "hinlink_h28k" "target/linux/rockchip/image/armv8.mk"; then
    echo "❌ 错误: armv8.mk 包含非法内容 (h28k)" && exit 1
fi
if ! grep -q "智能识别 Binman 合体固件或传统拆分固件" "target/linux/rockchip/image/Makefile"; then
    echo "❌ 错误: Makefile 核心打包规则不匹配" && exit 1
fi

# ===================== 更新：校验 uboot-tools 核心修改点 =====================
UBOOT_MAKEFILE="package/boot/uboot-tools/Makefile"

# 校验1：PKG_CONFIG_SYSROOT_DIR 已安全置空（不能是原版的 STAGING_DIR_HOST，也不能被彻底删掉导致语法断裂）
if ! grep -q 'PKG_CONFIG_SYSROOT_DIR=""' "$UBOOT_MAKEFILE"; then
    echo "❌ 校验失败：$UBOOT_MAKEFILE 未找到 PKG_CONFIG_SYSROOT_DIR=\"\"，环境未安全置空！"
    exit 1
fi

# 校验2：已禁用 EFI 胶囊工具
if ! grep -F -- "--disable TOOLS_MKEFICAPSULE" "$UBOOT_MAKEFILE"; then
    echo "❌ 校验失败：$UBOOT_MAKEFILE 未找到 --disable TOOLS_MKEFICAPSULE，EFI 工具未禁用！"
    exit 1
fi

# 校验3：死循环拦截参数已挂载（无空格安全命令）
if ! grep -q "cmd_genenv=:" "$UBOOT_MAKEFILE"; then
    echo "❌ 校验失败：$UBOOT_MAKEFILE 未找到 cmd_genenv=:，死循环拦截未生效！"
    exit 1
fi

# 校验4：提前伪造环境文件逻辑已注入
if ! grep -q "touch \$(PKG_BUILD_DIR)/u-boot-initial-env" "$UBOOT_MAKEFILE"; then
    echo "❌ 校验失败：$UBOOT_MAKEFILE 未找到 touch 伪造环境命令，编译将因缺少环境文件报错！"
    exit 1
fi

echo "✅ uboot-tools/Makefile 核心修改点校验通过"

# 校验5：检查 rockchip_armv8 已适配 H29K
ENV_FILE="package/boot/uboot-tools/uboot-envtools/files/rockchip_armv8"

if ! grep -q "hinlink,h29k-rk3528" "$ENV_FILE"; then
    echo "❌ 校验失败：未找到 H29K 适配配置"
    exit 1
fi

echo "✅ rockchip_armv8 H29K 适配校验通过"

# ============================================================================

# --- 统一拉取应用层开机 LOGO 组 ---
for i in 1 2 3; do
    download_and_check "${LOGO_URL}/LOGO${i}.jpg" "files/etc/config/screen/LOGO${i}.jpg"
done

echo "✅ 所有外部资源下载并校验通过！"
# ==============================================================================
echo "🚀 [diy-part1.sh] 软件源与独立包与配置文件预处理圆满完成！"
