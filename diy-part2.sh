# --- 8. 执行生成配置与最终清理 ---
# 强制开启一些必要的依赖项，防止打包时因缺少依赖报错
echo "CONFIG_PACKAGE_kmod-fb=y" >> .config
echo "CONFIG_PACKAGE_kmod-fb-cfb-fillrect=y" >> .config
echo "CONFIG_PACKAGE_kmod-fb-cfb-copyarea=y" >> .config
echo "CONFIG_PACKAGE_kmod-fb-cfb-imgblt=y" >> .config

make defconfig

# 修复 JFFS2 错误
sed -i '/CONFIG_TARGET_ROOTFS_JFFS2/d' .config

# 【关键修复】取消镜像构建时的最大体积限制，防止 Error 255
sed -i 's/CONFIG_TARGET_ROOTFS_MAXINODE.*/CONFIG_TARGET_ROOTFS_MAXINODE=0/' .config
sed -i 's/CONFIG_TARGET_ROOTFS_RESERVED_PCT.*/CONFIG_TARGET_ROOTFS_RESERVED_PCT=0/' .config

# 调整分区大小
sed -i 's/^CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=32/' .config
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# --- 核心修改：确保模糊匹配单选含有 H29K 关键字的机型 ---
echo "正在检测并单选 H29K 机型..."
sed -i 's/CONFIG_TARGET_rockchip_armv8_DEVICE_.*=y/# & is not set/' .config
H29K_CONF=$(grep -i "CONFIG_TARGET_rockchip_armv8_DEVICE_.*H29K.*" .config | head -n 1 | cut -d'=' -f1)

if [ -n "$H29K_CONF" ]; then
    echo "锁定匹配机型: $H29K_CONF"
    sed -i "s/.*$H29K_CONF.*/$H29K_CONF=y/" .config
else
    echo "强制注入默认 H29K 机型项..."
    echo "CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y" >> .config
fi

# 再次执行刷新，确保所有修改被内核构建系统认可
make defconfig
