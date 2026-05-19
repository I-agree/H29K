# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
    $(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
    # Create boot directory with kernel and dtb
    rm -fR $@.boot
    mkdir -p $@.boot

    $(CP) $(IMAGE_KERNEL) $@.boot/kernel.img

    if [ ! -f "$(KDIR)/image-$(DEVICE_DTS).dtb" ]; then \
        echo "ERROR: DTB not found — expected: $(KDIR)/image-$(DEVICE_DTS).dtb" >&2; \
        exit 1; \
    fi
    $(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/rockchip.dtb
endef

define Build/boot-script
    mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# --- ✅ 厂家同款格式：单个 img 包 ---
define Build/pine64-img
    # 1. 制作标准4K对齐 64MB BOOT分区镜像 0.img（FAT32）
    rm -f $(KDIR)/0.img
    dd if=/dev/zero of=$(KDIR)/0.img bs=4K count=16384 status=none
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    mkdir -p $(KDIR)/h29k-boot
    $(CP) $@.boot/kernel.img $(KDIR)/h29k-boot/kernel.img
    $(CP) $@.boot/rockchip.dtb $(KDIR)/h29k-boot/rockchip.dtb
    $(CP) $@.boot/boot.scr $(KDIR)/h29k-boot/boot.scr
    mcopy -i $(KDIR)/0.img $(KDIR)/h29k-boot/* ::/

    # 2. 4K对齐处理root.squashfs → 标准分区镜像1.img（不删root.squashfs）
    dd if=$(KDIR)/root.squashfs of=$(KDIR)/1.img bs=4K conv=sync status=none

    # 3. 构建整机固件：MBR分区表 + 0.img(boot) + 1.img(rootfs)，BootROM可识别
    rm -f $@
    # 空镜像 + MBR分区表
    dd if=/dev/zero of=$@ bs=1M count=1 status=none
    parted -s $@ mklabel msdos
    # BOOT分区：1M~65M（64MB，严格4K对齐）
    parted -s $@ mkpart primary fat32 1M 65M
    dd if=$(KDIR)/0.img of=$@ bs=4K seek=$((1*1024*1024/4096)) conv=notrunc status=none
    # ROOTFS分区：65M起，4K对齐
    parted -s $@ mkpart primary squashfs 65M 100%
    dd if=$(KDIR)/1.img of=$@ bs=4K seek=$((65*1024*1024/4096)) conv=notrunc status=none
endef

### Devices ###
define Device/Default
    PROFILES := Default
    KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
    KERNEL_LOADADDR := 0x00280000
    BOOT_SCRIPT := default
    DEVICE_DTS_DIR := $$(DTS_DIR)/rockchip
    DEVICE_DTS := $$(SOC)-$(lastword $(subst _, ,$(1)))
    UBOOT_DEVICE_NAME := $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
