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
	# 🎯 坑一修复：恢复为标准的 arm64 架构，防止 U-Boot 报架构错误拒绝执行
	mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# =====================================================================
# 🚀 HINLINK H29K 独占：策略 B（无缝预埋 + 严格熔断）核心打包宏
# =====================================================================
define Build/h29k-img
	# [步骤 1] 自动将当前设备树文件命名为 rockchip.dtb 塞入 boot 目录
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/rockchip.dtb

	# [步骤 2-8] 绘制分区表、填充数据并注入引导（必须在同一个连续的 Shell 进程中执行，不可被注释阻断）
	@set `ptgen -o $@ -h 16 -s 63 -l 32768 \
		-p $(CONFIG_TARGET_KERNEL_PARTSIZE)m \
		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)m`; \
	KERNELOFFSET=$$(($$1 / 512)); \
	ROOTFSOFFSET=$$(($$3 / 512)); \
	ROOTFSSIZE=$$(($$4 / 512)); \
	dd if=/dev/zero of=$@ bs=512 seek=$$ROOTFSOFFSET count=$$ROOTFSSIZE conv=notrunc; \
	rm -f $@.kernel.img; \
	# 🎯 坑二修复：追加禁用 ^dir_nlink,^extra_isize 并强制开启 gdt_csum，达成与原厂 1:1 像素级特性对齐
	mke2fs -F -t ext4 -b 4096 -O ^64bit,^metadata_csum,^flex_bg,^huge_file,^has_journal,^dir_index,^dir_nlink,^extra_isize,gdt_csum -L kernel -d $@.boot $@.kernel.img $$(( $(CONFIG_TARGET_KERNEL_PARTSIZE) * 256 )); \
	dd if=$@.kernel.img of=$@ bs=512 seek=$$KERNELOFFSET conv=notrunc; \
	dd if=$(IMAGE_ROOTFS) of=$@ bs=512 seek=$$ROOTFSOFFSET conv=notrunc; \
	if [ ! -f "$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" ]; then \
		echo "======================================================================="; \
		echo "❌ [H29K 编译熔断报错] 未在 target/linux/rockchip/image/ 下找到引导文件！"; \
		echo "❌ 请检查您的 diy-part1.sh 逻辑是否正常拉取或复制了 H29K-Boot-Loader.bin"; \
		echo "======================================================================="; \
		exit 1; \
	fi; \
	echo "============= [H29K STRATEGY B ENFORCED] ============="; \
	echo "🚀 成功捕获预置引导文件: H29K-Boot-Loader.bin"; \
	echo "📦 正在执行硬核物理埋入（eMMC Sector 64 偏移量 32KiB 处）..."; \
	dd if="$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" of="$@" seek=64 conv=notrunc; \
	echo "📊 本地引导预埋成功，固件具备独立脱机启动能力。"; \
	echo "====================================================="; \
	rm -f $@.kernel.img
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL = kernel-bin
  KERNEL_LOADADDR :=
  BOOT_SCRIPT :=
  IMAGES := sysupgrade.img.gz
  IMAGE/sysupgrade.img.gz = boot-common | boot-script $$(BOOT_SCRIPT) | h29k-img | gzip
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
  UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
