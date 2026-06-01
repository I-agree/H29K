#!/bin/sh
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
cp -r package/immortalwrt_temp/package/kernel/aic8800 package/aic8800
rm -rf package/immortalwrt_temp

# =================================================================
# 🚨 强行物理修复 aic8800 缺少 mac80211 前置依赖的底层硬伤
# =================================================================
echo "🛠️ 正在修复 aic8800 依赖关系，强行注入 +kmod-mac80211..."
find package/ -name "Makefile" -path "*/aic8800/*" -exec sed -i 's/DEPENDS:=+kmod-cfg80211/DEPENDS:=+kmod-mac80211 +kmod-cfg80211/g' {} +
echo "✅ aic8800 依赖链物理修补完成！"

# === 3. 安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

echo "🚀 [diy-part1.sh] 软件源与独立包预处理圆满完成！"
