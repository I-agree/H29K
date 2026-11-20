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

# ===================== 系统防火墙增强版（openwrt-sonic-fullcone） =====================
# 一键应用所有补丁（适用于6.6、6.12、6.18）
# 全锥形 NAT（Full Cone NAT），无需额外勾选，fullcone 编译进现有 nft_masq.ko / xt_MASQUERADE.ko 模块
curl -sSL https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh | bash

# =================================================================================

# ===================== 赋权与开机自启 =====================
# echo "🔧 给可执行脚本添加运行权限"
chmod +x files/etc/init.d/99-bootanim
chmod +x files/usr/sbin/drm_play_arm64
chmod +x files/etc/uci-defaults/once-enable-bootanim
chmod 0755 files/usr/share/qmodem/led_scripts/misectel_led.sh
chmod +x files/usr/share/qmodem/led_scripts/misectel_led.sh
# ==============================================================

echo "🚀 H29K专用代码已经准备就绪，即将开始正式编译！"
