# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	# 创建临时的 boot 挂载目录，并将内核镜像复制进去
	rm -fR $@.boot
	mkdir -p $@.boot
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
endef

define Build/boot-script
	# 编译 U-boot 专用的引导脚本 boot.scr
	mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# =====================================================================
# 🚀 深度定制：HINLINK H29K 策略 B（无缝预埋型）唯一指定打包宏
# =====================================================================
define Build/h29k-img
	# 1. 自动将当前设备树文件（.dtb）命名为 rockchip.dtb 塞入 boot 目录
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/rockchip.dtb
	
	# 2. 调用 OpenWrt 官方 ptgen 工具绘制 MBR 分区表
	# -l 32768：强制前置保留 32MB 空间（33554432 字节），完美对齐原厂分区物理结构
	@set `ptgen -o $@ -h 16 -s 63 -l 32768 \
		-p $(CONFIG_TARGET_KERNEL_PARTSIZE)m \
		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)m`; \
	KERNELOFFSET=$$(($$1 / 512)); \
	ROOTFSOFFSET=$$(($$3 / 512)); \
	ROOTFSSIZE=$$(($$4 / 512)); \
	\
	# 3. 预先向复合镜像中注入全零数据块填充 rootfs 空间（防止物理大小因 SquashFS 压缩而收缩）
	dd if=/dev/zero of=$@ bs=512 seek=$$ROOTFSOFFSET count=$$ROOTFSSIZE conv=notrunc; \
	\
	# 4. 在免 root 权限下，调用 mke2fs 工具将 $@.boot 文件夹封装成标准的 Ext4 块镜像文件
	rm -f $@.kernel.img; \
	mke2fs -F -t ext4 -b 4096 -L kernel -d $@.boot $@.kernel.img $$(( $(CONFIG_TARGET_KERNEL_PARTSIZE) * 256 )); \
	\
	# 5. 精确 dd 写入：将 Ext4 启动分区镜像和标准的 SquashFS 根系统镜像填入对应的 MBR 扇区
	dd if=$@.kernel.img of=$@ bs=512 seek=$$KERNELOFFSET conv=notrunc; \
	dd if=$(IMAGE_ROOTFS) of=$@ bs=512 seek=$$ROOTFSOFFSET conv=notrunc; \
	\
	# 6. 🔒 策略 B 强校验断言机制（Strict Mode）：
	# 必须检测到由 diy-part1.sh 放入的 H29K-Boot-Loader.bin，否则立刻熔断报错！
	if [ ! -f "$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" ]; then \
		echo "======================================================================="; \
		echo "❌ [H29K 编译熔断报错] 未在 target/linux/rockchip/image/ 下找到引导文件！"; \
		echo "❌ 请检查您的 diy-part1.sh 逻辑是否正常拉取或复制了 H29K-Boot-Loader.bin"; \
		echo "======================================================================="; \
		exit 1; \
	fi; \
	\
	# 7. 校验通过，精准注入到整盘镜像的第 64 扇区
	echo "============= [H29K STRATEGY B ENFORCED] ============="; \
	echo "🚀 成功捕获预置引导文件: H29K-Boot-Loader.bin"; \
	echo "📦 正在执行硬核物理埋入（eMMC Sector 64 偏移量 32KiB 处）..."; \
	dd if="$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" of="$@" seek=64 conv=notrunc; \
	echo "📊 本地引导预埋成功，固件具备独立脱机启动能力。"; \
	echo "====================================================="; \
	\
	# 8. 清理构建临时产物
	rm -f $@.kernel.img
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_LOADADDR :=
  BOOT_SCRIPT :=
  IMAGES := sysupgrade.img.gz
  # 👈 核心修改：此处彻底砍掉全局默认的打包逻辑，默认所有机型全部经过我们的 h29k-img 宏进行安全校验打包
  IMAGE/sysupgrade.img.gz = boot-common | boot-script $$(BOOT_SCRIPT) | h29k-img | gzip | append-metadata
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
  UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
