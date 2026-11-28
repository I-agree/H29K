#!/bin/bash
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

set -euo pipefail  # 严格报错模式：任一非条件命令失败立即终止

# =================================================================================
# 1. 🎯 工业级自愈补丁：将 rk3528-hinlink-h29k 安全注册进内核 Makefile
# =================================================================================
# 使用原生 Shell 循环替代 ls/find 管道，100% 免疫 set -e 报错自杀机制
PATCH_DIR=""
for d in target/linux/rockchip/patches-6.18 target/linux/rockchip/patches-*; do
    if [ -d "$d" ]; then
        PATCH_DIR="$d"
        break
    fi
done

if [ -n "$PATCH_DIR" ]; then
    echo "📥 侦测到目标内核补丁阵列: $PATCH_DIR，正在注入 H29K 标准差分补丁..."
    
    # 写入数学计数严密对齐的 Unified Diff 补丁，严防 Quilt 报 Hunk Header 错误
    cat << 'EOF' > "$PATCH_DIR/999-add-rk3528-hinlink-h29k-makefile.patch"
--- a/arch/arm64/boot/dts/rockchip/Makefile
+++ b/arch/arm64/boot/dts/rockchip/Makefile
@@ -93,1 +93,2 @@
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3528-hinlink-h28k.dtb
+dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3528-hinlink-h29k.dtb
EOF

    echo "✅ 严格数学对齐内核补丁已成功封印至 Quilt 队列！"
else
    echo "⚠️ 提示：未探测到 rockchip 补丁目录，跳过内核补丁修改。"
fi

# =================================================================================

# =================================================================================
# 2. 🎯 给 gst1-plugins-bad 启用 kmssink（HDMI 直出必需）
# =================================================================================
GST_BAD="feeds/packages/multimedia/gst1-plugins-bad"
GST_BAD_COMPILED="package/feeds/packages/gst1-plugins-bad"
KMS_PATCH="$(pwd)/package/multimedia/gmediarender/extras/0001-gst1-plugins-bad-enable-kmssink.patch"

if [ ! -f "$GST_BAD/Makefile" ]; then
    echo "❌ 未找到 $GST_BAD/Makefile，feeds 还没装好"
    exit 1
fi
if [ ! -f "$KMS_PATCH" ]; then
    echo "❌ 未找到补丁 $KMS_PATCH（diy-part1 的 download_and_check 可能失败了）"
    exit 1
fi

echo "🔧 正在为 gst1-plugins-bad 启用 kmssink..."
patch -p1 -d feeds/packages --forward < "$KMS_PATCH"

# package/feeds/*/gst1-plugins-bad 通常是软链（此时上面那一步已经生效）；
# 若它是实体目录，必须单独再打一遍，否则编译用的那份还是 disabled。
if [ -f "$GST_BAD_COMPILED/Makefile" ] && [ ! -L "$GST_BAD_COMPILED" ]; then
    grep -q "GstBuildPlugin,kms" "$GST_BAD_COMPILED/Makefile" \
        || patch -p3 -d "$GST_BAD_COMPILED" --forward < "$KMS_PATCH"
fi

grep -q "GstBuildPlugin,kms" "$GST_BAD/Makefile" || {
    echo "❌ kmssink 补丁未生效（$GST_BAD/Makefile）"
    exit 1
}
if [ -f "$GST_BAD_COMPILED/Makefile" ]; then
    grep -q "GstBuildPlugin,kms" "$GST_BAD_COMPILED/Makefile" || {
        echo "❌ kmssink 补丁未落到实际编译的 Makefile（$GST_BAD_COMPILED/Makefile）"
        exit 1
    }
fi

echo "✅ kmssink 已启用"
echo "   源文件:     $(grep -n 'GstBuildPlugin,kms' "$GST_BAD/Makefile")"
echo "   编译用:     $(grep -n 'GstBuildPlugin,kms' "${GST_BAD_COMPILED}/Makefile" 2>/dev/null || echo '（软链，同上）')"
echo "   插件开关:   $(grep -n '\-Dkms=' "$GST_BAD/Makefile")"

# =================================================================================

# =================================================================================
# 3. 🎯 MPD curl 输入插件：http/https 流一律按可 seek 处理
#    （修手机端拖进度条报 "Not seekable"、播放位置与进度条不符）
# =================================================================================
MPD_FEED="feeds/packages/sound/mpd"
MPD_FEED_COMPILED="package/feeds/packages/mpd"
MPD_PATCH="$(pwd)/package/mpd/extras/001-curl-http-seekable.patch"

if [ ! -f "$MPD_FEED/Makefile" ]; then
	echo "❌ 未找到 $MPD_FEED/Makefile，feeds 还没装好"
	exit 1
fi
if [ ! -f "$MPD_PATCH" ]; then
	echo "❌ 未找到补丁 $MPD_PATCH（diy-part1 的 download_and_check 可能失败了）"
	exit 1
fi

mkdir -p "$MPD_FEED/patches"
cp "$MPD_PATCH" "$MPD_FEED/patches/"

# package/feeds/* 若是实体目录（非软链），补丁目录要再放一份，否则编译用的那份没补丁
if [ -d "$MPD_FEED_COMPILED" ] && [ ! -L "$MPD_FEED_COMPILED" ]; then
	mkdir -p "$MPD_FEED_COMPILED/patches"
	cp "$MPD_PATCH" "$MPD_FEED_COMPILED/patches/"
fi

echo "✅ MPD curl seek 补丁已注入: $MPD_FEED/patches/"

# =================================================================================

# =================================================================================
# 4. 🎯 系统防火墙增强版（openwrt-sonic-fullcone）
# =================================================================================
# 一键应用所有补丁（适用于6.6、6.12、6.18）
# 全锥形 NAT（Full Cone NAT），无需额外勾选，fullcone 编译进现有 nft_masq.ko / xt_MASQUERADE.ko 模块
curl -sSL https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh | bash

# =================================================================================

# =================================================================================
# 5. 🎯 OpenWrt 上游内核压缩 lzma 修改为 gzip
# =================================================================================
IMG_MK=target/linux/rockchip/image/Makefile
grep -q 'lzma | fit lzma' "$IMG_MK" && \
    sed -i 's@kernel-bin | lzma | fit lzma@kernel-bin | gzip | fit gzip@' "$IMG_MK"
grep -q 'gzip | fit gzip' "$IMG_MK" || { echo "FATAL: 内核压缩未改成 gzip"; exit 1; }

# =================================================================================

# ===================== 赋权与开机自启 =====================
# echo "🔧 给可执行脚本添加运行权限"
chmod +x files/etc/init.d/99-bootanim
chmod +x files/usr/sbin/drm_play_arm64
chmod +x files/etc/uci-defaults/once-enable-bootanim
chmod 0755 files/usr/share/qmodem/led_scripts/misectel_led.sh
chmod +x files/usr/share/qmodem/led_scripts/misectel_led.sh
chmod 0755 package/luci-app-btmanager/root/usr/sbin/btmanager
chmod 0755 package/luci-app-btmanager/root/etc/init.d/btmanager
chmod 0755 package/luci-app-btmanager/root/etc/uci-defaults/99-btmanager
chmod 0755 package/bluez-alsa/files/bluealsa.init
chmod 0755 files/etc/init.d/mpd
chmod 0755 files/etc/init.d/upmpdcli
chmod 0755 files/etc/uci-defaults/99-h29k-dualrenderer
chmod 0755 files/lib/preinit/05_h29k_trace
chmod 0755 files/lib/preinit/31_h29k_failsafe_guard
# ==============================================================
grep -q 'failsafe_wait()' files/lib/preinit/31_h29k_failsafe_guard || { echo "FATAL: failsafe 加固文件未落地"; exit 1; }

# ===================== 实验前置校验 =====================
BOOT=target/linux/rockchip/image/default.bootscript
# 注入 rootwait=30 + initcall_debug + printk.devkmsg=on + netconsole；匹配原文 " rw rootwait"，不依赖有没有 =30
grep -q 'initcall_debug' "$BOOT" || \
    sed -i 's| rw rootwait| rw rootwait=30 initcall_debug printk.devkmsg=on ignore_loglevel netconsole=6666@192.168.1.20/eth0,6666@192.168.1.255/ff:ff:ff:ff:ff:ff|' "$BOOT"

# bootscript 之前被单独注入过 initcall_debug（没有 printk.devkmsg=on）时，只补这一项
grep -q 'printk.devkmsg=on' "$BOOT" || \
    sed -i 's|initcall_debug|initcall_debug printk.devkmsg=on|' "$BOOT"

grep -q 'initcall_debug'    "$BOOT" || { echo "FATAL: bootscript 未注入 initcall_debug"; exit 1; }
grep -q 'printk.devkmsg=on' "$BOOT" || { echo "FATAL: bootscript 未注入 printk.devkmsg=on"; exit 1; }
grep -q 'rootwait=30'       "$BOOT" || { echo "FATAL: bootscript 未注入 rootwait=30"; exit 1; }
! grep -q 'console=ttyGS0'  "$BOOT" || { echo "FATAL: bootargs 仍带 console=ttyGS0"; exit 1; }
grep -q 'netconsole='       "$BOOT" || { echo "FATAL: bootscript 未注入 netconsole"; exit 1; }
echo "✅ bootargs: $(grep -o 'rw rootwait[^;]*' "$BOOT")"

# 网口必须是 okay
DTS=target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-hinlink-h29k.dts
if ! awk '/^&gmac1 {/,/^};/' "$DTS" | grep -q 'status = "okay"'; then
    echo "❌ 构建用的 dts 里 &gmac1 不是 okay（raw CDN 缓存未刷新，下到的是旧文件）"
    echo "   实际内容：$(awk '/^&gmac1 {/,/^};/' "$DTS" | grep 'status = ')"
    exit 1
fi
echo "✅ dts: $(awk '/^&gmac1 {/,/^};/' "$DTS" | grep 'status = ' | tr -d '\t')"

# dwc3 必须回到 host（Type-C gadget 实验已撤，peripheral 会让 USB 口失去主机能力）
if ! awk '/^&usb_host0_xhci {/,/^};/' "$DTS" | grep -q 'dr_mode = "host"'; then
    echo "❌ dts 里 &usb_host0_xhci 的 dr_mode 不是 host"
    echo "   实际内容：$(awk '/^&usb_host0_xhci {/,/^};/' "$DTS" | grep 'dr_mode')"
    exit 1
fi
echo "✅ dts: $(awk '/^&usb_host0_xhci {/,/^};/' "$DTS" | grep 'dr_mode' | tr -d '\t')"

echo "🚀 H29K专用代码已经准备就绪，即将开始正式编译！"
