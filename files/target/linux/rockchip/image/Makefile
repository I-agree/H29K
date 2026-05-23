# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	rm -fR $@.boot
	mkdir -p $@.boot
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
endef

define Build/boot-script
	mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# =====================================================================
# 🚀 HINLINK H29K 独占：策略 B（无缝预埋 + 严格熔断）核心打包宏
# =====================================================================
define Build/h29k-img
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/rockchip.dtb
	@set `ptgen -o $@ -h 16 -s 63 -l 32768 \
		-p $(CONFIG_TARGET_KERNEL_PARTSIZE)m \
		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)m`; \
	KERNELOFFSET=$$(($$1 / 512)); \
	ROOTFSOFFSET=$$(($$3 / 512)); \
	ROOTFSSIZE=$$(($$4 / 512)); \
	dd if=/dev/zero of=$@ bs=512 seek=$$ROOTFSOFFSET count=$$ROOTFSSIZE conv=notrunc; \
	rm -f $@.kernel.img; \
	mke2fs -F -t ext4 -b 4096 -O ^64bit,^metadata_csum,^flex_bg,^huge_file,^has_journal,^dir_index,^dir_nlink,^extra_isize,gdt_csum -L kernel -d $@.boot $@.kernel.img $$(( $(CONFIG_TARGET_KERNEL_PARTSIZE) * 256 )); \
	dd if=$@.kernel.img of=$@ bs=512 seek=$$KERNELOFFSET conv=notrunc; \
	dd if=$(KDIR)/root.$(IMG_ROOTFS_TYPE) of=$@ bs=512 seek=$$ROOTFSOFFSET conv=notrunc; \
	if [ ! -f "$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" ]; then \
		echo "======================================================================="; \
		echo "❌ [H29K 编译熔断报错] 未在 target/linux/rockchip/image/ 下找到引导文件！"; \
		echo "======================================================================="; \
		exit 1; \
	fi; \
	echo "============= [H29K STRATEGY B ENFORCED] ============="; \
	echo "🚀 成功捕获预置引导文件: H29K-Boot-Loader.bin"; \
	dd if="$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" of="$@" seek=64 conv=notrunc; \
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
