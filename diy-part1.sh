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

# ===================== AIC8800修复补丁 =====================
mkdir -p package/aic8800/patches/
cat > package/aic8800/patches/999-fix-kernel-6.12.patch << 'EOF'
--- a/aic8800.h
+++ b/aic8800.h
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 typedef unsigned char  u8;
 typedef unsigned short u16;
 typedef unsigned int   u32;
--- a/aic8800_core.c
+++ b/aic8800_core.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/init.h>
 #include <linux/pci.h>
--- a/aic8800_main.c
+++ b/aic8800_main.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/core.c
+++ b/core.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/hw.c
+++ b/hw.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/tx.c
+++ b/tx.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/skbuff.h>
--- a/rx.c
+++ b/rx.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/skbuff.h>
--- a/debug.c
+++ b/debug.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/regd.c
+++ b/regd.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/wext.c
+++ b/wext.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/led.c
+++ b/led.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/ethtool.c
+++ b/ethtool.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/debugfs.c
+++ b/debugfs.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/cfg80211.c
+++ b/cfg80211.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/usb.c
+++ b/usb.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/sdio.c
+++ b/sdio.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
--- a/pcie.c
+++ b/pcie.c
@@ -1,3 +1,4 @@
+#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
 #include <linux/module.h>
 #include <linux/kernel.h>
 #include <linux/init.h>
EOF

# === 3. 安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

echo "🚀 [diy-part1.sh] 软件源与独立包预处理圆满完成！"
