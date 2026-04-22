#!/bin/bash

# --- 1. 环境与底层基础修复 ---
# 某些脚本依赖 /lib/functions.sh，但在编译环境中可能缺失，此处做软链接修复
if [ -f "$(pwd)/package/base-files/files/lib/functions.sh" ]; then
    sudo mkdir -p /lib
    sudo ln -sf $(pwd)/package/base-files/files/lib/functions.sh /lib/functions.sh
fi

# --- 2. 硬件支持文件下载与强制断言 ---
# 下载 H29K 专属的设备树(DTS)和引导程序(Boot Loader)，下载失败则立即停止编译防止产出错误固件
DTS_URL="https://raw.githubusercontent.com/I-agree/H29K/main/rk3528-opc-h29k.dts"
BOOT_BIN_URL="https://raw.githubusercontent.com/I-agree/H29K/main/H29K-Boot-Loader.bin"
DTS_PATH="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"

mkdir -p "$DTS_PATH"
echo "正在下载 H29K 硬件支持文件..."

curl -fsSL "$DTS_URL" > "$DTS_PATH/rk3528-opc-h29k.dts" || { echo "DTS下载失败"; exit 1; }
curl -fsSL "$BOOT_BIN_URL" > hinlink_h29k-u-boot-rockchip.bin || { echo "Boot下载失败"; exit 1; }

# 将引导程序放入预设目录，供后续镜像打包使用
mkdir -p bin/targets/rockchip/armv8
cp hinlink_h29k-u-boot-rockchip.bin bin/targets/rockchip/armv8/

# --- 3. 动态注入 video.mk (核心：解决TFT驱动路径写死问题) ---
# 使用通配符同时检查标准目录和 Staging 目录，确保无论内核版本如何变动都能找到 .ko 文件
VIDEO_MK="package/kernel/linux/modules/video.mk"
sed -i '/KernelPackage\/h29k-fb-tft-core/,/eval $(call KernelPackage,h29k-fb-tft-core)/d' "$VIDEO_MK"
sed -i '/KernelPackage\/h29k-fb-st7789v/,/eval $(call KernelPackage,h29k-fb-st7789v)/d' "$VIDEO_MK"

echo "正在注入屏幕驱动定义到 $VIDEO_MK..."
cat >> "$VIDEO_MK" <<EOF

define KernelPackage/h29k-fb-tft-core
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=Support for small TFT LCD display modules (H29K)
  KCONFIG:=CONFIG_FB_TFT
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/*/fbtft.ko \$(LINUX_DIR)/drivers/staging/fbtft/fbtft.ko
  AUTOLOAD:=\$(call AutoProbe,fbtft)
endef
\$(eval \$(call KernelPackage,h29k-fb-tft-core))

define KernelPackage/h29k-fb-st7789v
  SUBMENU:=\$(VIDEO_MENU)
  TITLE:=ST7789V LCD display support (H29K)
  DEPENDS:=+kmod-h29k-fb-tft-core +kmod-fb +kmod-fb-cfb-fillrect +kmod-fb-cfb-copyarea +kmod-fb-cfb-imgblt
  KCONFIG:=CONFIG_FB_TFT_ST7789V
  FILES:=\$(LINUX_DIR)/drivers/video/fbdev/*/fb_st7789v.ko \$(LINUX_DIR)/drivers/staging/fbtft/fb_st7789v.ko
  AUTOLOAD:=\$(call AutoProbe,fb_st7789v)
endef
\$(eval \$(call KernelPackage,h29k-fb-st7789v))
EOF

# --- 4. 自动适配所有内核配置 (核心：开启 Staging 和 TFT 深度依赖) ---
# 必须开启 CONFIG_STAGING 才能编译位于暂存区的驱动，并补全 FB 绘图引擎依赖
echo "正在扫描并修补所有内核版本的配置文件以支持 TFT 帧缓冲..."
find target/linux/rockchip/armv8/ -name "config-*" | while read CONF; do
    sed -i '/CONFIG_STAGING/d' "$CONF"
    sed -i '/CONFIG_FB_TFT/d' "$CONF"
    sed -i '/CONFIG_FB_ST7789V/d' "$CONF"
    {
        echo "CONFIG_STAGING=y"
        echo "CONFIG_FB=y"
        echo "CONFIG_FB_CFB_FILLRECT=y"
        echo "CONFIG_FB_CFB_COPYAREA=y"
        echo "CONFIG_FB_CFB_IMAGEBLIT=y"
        echo "CONFIG_FB_DEFERRED_IO=y"
        echo "CONFIG_FB_SYS_FILLRECT=y"
        echo "CONFIG_FB_SYS_COPYAREA=y"
        echo "CONFIG_FB_SYS_IMAGEBLIT=y"
        echo "CONFIG_FB_SYS_FOPS=y"
        echo "CONFIG_FB_BACKLIGHT=y"
        echo "CONFIG_SPI=y"
        echo "CONFIG_FB_TFT=m"
        echo "CONFIG_FB_TFT_ST7789V=m"
        echo "CONFIG_FB_TFT_FBTFT_DEVICE=m"
    } >> "$CONF"
done

# --- 5. 注册设备并完善 DEVICE_PACKAGES (确保固件集成驱动) ---
# 必须在 DEVICE_PACKAGES 中列出 kmod-h29k-fb-tft-core 及其依赖包
TARGET_MK=$(find target/linux/rockchip/image -name "armv8.mk")
if [ -n "$TARGET_MK" ] && ! grep -q "hinlink_h29k" "$TARGET_MK"; then
    echo "正在注册 H29K 设备到 $TARGET_MK..."
    cat >> "$TARGET_MK" <<EOF

define Device/hinlink_h29k
  \$(Device/rk3528)
  DEVICE_VENDOR := HINLINK
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  DEVICE_DTS_DIR := \$(LINUX_DIR)/arch/arm64/boot/dts/rockchip
  UBOOT_DEVICE_NAME := hinlink_h29k
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | rockchip-img | gzip | append-metadata
  KERNEL_SIZE := 33554432
  KERNEL_LOADADDR := 0x00200000
  BOARD_ROOTFS_PARTSIZE := 1024
  DEVICE_PACKAGES := kmod-usb3 uboot-rockchip-v8 kmod-r8169 kmod-usb-net-rtl8152 kmod-aic8800 aic8800-firmware kmod-mtk_t7xx \
	kmod-fb kmod-fb-cfb-fillrect kmod-fb-cfb-copyarea kmod-fb-cfb-imgblt \
	kmod-h29k-fb-tft-core kmod-h29k-fb-st7789v
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# --- 6. 核心配置注入与机型锁定 ---
# 强制选中机型并包含自定义内核模块
cat >> .config <<EOF
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
CONFIG_PACKAGE_kmod-h29k-fb-tft-core=y
CONFIG_PACKAGE_kmod-h29k-fb-st7789v=y
CONFIG_PACKAGE_luci-theme-argon=y
EOF

# --- 7. 系统默认值初始化 (UCI 方案) ---
# 设置 Argon 为默认主题，并修改主机名
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-h29k-custom <<EOF
#!/bin/sh
uci set luci.main.mediaurlbase='/luci-static/argon'
uci set system.@system[0].hostname='H29K'
uci commit luci
uci commit system
exit 0
EOF

# --- 8. 执行生成配置与最终清理 ---
# 第一次 defconfig 生成基础 .config
make defconfig

# 修复 JFFS2 错误：移除该项配置以避免某些平台下的挂载报错
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config

# 调整分区大小：根据 H29K 实际需求，设置内核 32M，Rootfs 1024M
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 确保单选 H29K 机型并刷新：清理所有机型选中项，强制只保留 H29K
sed -i '/CONFIG_TARGET_rockchip_armv8_DEVICE_/d' .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config

# 第二次 defconfig 刷新依赖关系并锁定配置
make defconfig
