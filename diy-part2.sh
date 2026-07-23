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

# ===================== 新增赋权与开机自启 =====================
# echo "🔧 给可执行脚本添加运行权限"
chmod +x files/etc/init.d/99-bootanim
chmod +x files/usr/sbin/drm_play_arm64
chmod +x files/usr/sbin/bo.py

# 编译时直接把开机自启的链接打包进固件，烧录后任意次数开机都会自动跑，enable只需要执行一次，永久生效
$TARGET_DIR/etc/init.d/99-bootanim enable
# ==============================================================

echo "🚀 H29K专用代码已经准备就绪，即将开始正式编译！"
