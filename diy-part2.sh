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
for d in target/linux/rockchip/patches-6.12 target/linux/rockchip/patches-*; do
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
@@ -80,1 +80,2 @@
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3528-hinlink-h28k.dtb
+dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3528-hinlink-h29k.dtb
EOF

    echo "✅ 严格数学对齐内核补丁已成功封印至 Quilt 队列！"
else
    echo "⚠️ 提示：未探测到 rockchip 补丁目录，跳过内核补丁修改。"
fi

# =================================================================================

# =================================================================================
# 🚨 针对 aic8800 本地 Makefile 的终极补丁（支持 set -e 严格模式）
# =================================================================================
REAL_AIC_MAKEFILE="package/kernel/aic8800/Makefile"

if [ -f "$REAL_AIC_MAKEFILE" ]; then
    echo "📥 侦测到目标组件，正在从自定义仓库强制下载覆盖 aic8800 Makefile..."
    
    # 👇 【已加固】先下载到临时文件，校验成功后再覆盖，防止 pipefail 和空文件导致 grep 崩溃
    TMP_AIC_MAKEFILE=$(mktemp)
    if curl -sSL --connect-timeout 8 --retry 3 \
      "https://raw.githubusercontent.com/I-agree/H29K/main/package/kernel/aic8800/Makefile" > "$TMP_AIC_MAKEFILE"; then
      
        if [ -s "$TMP_AIC_MAKEFILE" ] && grep -q "-DBUILD_OPENWRT -Wno-missing-prototypes" "$TMP_AIC_MAKEFILE"; then
            mv -f "$TMP_AIC_MAKEFILE" "$REAL_AIC_MAKEFILE"
            echo "✅ aic8800 Makefile 覆盖成功！"
        else
            echo "❌ 校验失败：Makefile 中缺失 -DBUILD_OPENWRT -Wno-missing-prototypes 或文件为空，编译将终止！"
            rm -f "$TMP_AIC_MAKEFILE"
            exit 1
        fi
    else
        echo "❌ 下载失败：无法获取 aic8800 Makefile，编译将终止！"
        rm -f "$TMP_AIC_MAKEFILE"
        exit 1
    fi
else
    echo "⚠️ 警告：在 $REAL_AIC_MAKEFILE 未找到该组件，请确认源码路径！"
fi

# =================================================================================

echo "🚀 H29K专用代码已经准备就绪，即将开始正式编译！"
