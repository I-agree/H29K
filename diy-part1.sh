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

echo "🚀 [diy-part1.sh] 软件源与独立包预处理圆满完成！"
