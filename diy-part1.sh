#!/bin/sh
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)

# === 1. 软件源与主题配置 ===
# 添加 QModem 软件源
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default

# === 2. 提取无线网卡驱动（从 ImmortalWrt 精准提取标准 Makefile 驱动包） ===
# 使用 Git 稀疏克隆技术，避免下载整个大仓库，只切出 package/kernel/aic8800 文件夹
git clone --depth 1 --filter=blob:none --sparse https://github.com/immortalwrt/immortalwrt.git package/immortalwrt_temp
cd package/immortalwrt_temp
git sparse-checkout set package/kernel/aic8800
cd ../..
cp -r package/immortalwrt_temp/package/kernel/aic8800 package/aic8800
rm -rf package/immortalwrt_temp

# === 3. 安装 argon 主题 ===
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

echo "🚀 [diy-part1.sh] 软件源预处理圆满完成！"
