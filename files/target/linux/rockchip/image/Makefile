# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	rm -fR $@.boot && mkdir -p $@.boot && $(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
endef

define Build/boot-script
	# 🛠️ 修改点 1：将默认缺省脚本由 default 改为 mmc，完美匹配官方自带的 mmc.bootscript
	mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),mmc).bootscript $@.boot/boot.scr
endef

# =====================================================================
# 🚀 HINLINK H29K 独占：策略 B（保留熔断 + 升级官方通用打包流）
# =====================================================================
define Build/h29k-img
	# Step 1: 规范拷贝设备树，重命名为 bootscript 指定的 rockchip.dtb
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/rockchip.dtb && \
	\
	# Step 2: 保留你优秀的严格熔断机制，未找到引导文件直接强制中断编译
	if [ ! -f "$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" ]; then \
		echo "======================================================================="; \
		echo "❌ [H29K 编译熔断报错] 未在 target/linux/rockchip/image/ 下找到引导文件！"; \
		echo "======================================================================="; \
		exit 1; \
	fi && \
	\
	# Step 3: 🛠️ 修改点 2：废除不稳定的人肉 ptgen 算力，直接调用官方标准的 gen_image_generic.sh
	# 这会自动帮你建立 32MB(32768) 头部对齐，并将第一分区编译为 U-Boot 完美兼容的 ext2 格式！
	PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(KDIR)/root.squashfs \
		32768 && \
	\
	# Step 4: 烧录引导程序到裸区域
	echo "============= [H29K STRATEGY B ENFORCED] =============" && \
	echo "🚀 成功捕获预置引导文件: H29K-Boot-Loader.bin" && \
	dd if="$(TOPDIR)/target/linux/rockchip/image/H29K-Boot-Loader.bin" of="$@" seek=64 conv=notrunc
	
	# 💡 黄金提示（根据你的实际启动结果调整）：
	# 如果你的 H29K-Boot-Loader.bin 仅仅是第一阶段的 idbloader，你可能还需要像官方那样，
	# 把主 U-Boot 镜像也 dd 进去。如果它是打包了 IBL + U-Boot 的全家桶合集，则上面这一行 dd 就足够了。
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL = kernel-bin
  KERNEL_LOADADDR :=
  BOOT_SCRIPT :=
  IMAGES := sysupgrade.img.gz
  # 这里的流水线会自动顺序执行：创建boot夹 -> 编译mmc启动脚本 -> 熔断打包 -> 压缩
  IMAGE/sysupgrade.img.gz = boot-common | boot-script $$(BOOT_SCRIPT) | h29k-img | gzip
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
  UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
