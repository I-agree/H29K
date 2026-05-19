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
    # Step1: 制作原厂标准32MB 0.img（4K对齐，FAT32 BOOT）
    rm -f $(KDIR)/0.img
    dd if=/dev/zero of=$(KDIR)/0.img bs=4K count=8192 status=none
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    mkdir -p $(KDIR)/h29k-boot
    $(CP) $@.boot/kernel.img $(KDIR)/h29k-boot/kernel.img
    $(CP) $@.boot/rockchip.dtb $(KDIR)/h29k-boot/rockchip.dtb
    $(CP) $@.boot/boot.scr $(KDIR)/h29k-boot/boot.scr
    mcopy -i $(KDIR)/0.img $(KDIR)/h29k-boot/* ::/

    # Step2: root.squashfs 4K对齐 → 1.img（原厂系统分区镜像）
    rm -f $(KDIR)/1.img
    dd if=$(KDIR)/root.squashfs of=$(KDIR)/1.img bs=4K conv=sync status=none

    # Step3: 构建【和原厂完全一致的MBR+偏移布局】（BootROM可识别）
    rm -f $@
    # 1. 总镜像 = 32MB头部空白 + 0.img(32M) + 64M间隙空白 + 1.img
    dd if=/dev/zero of=$@ bs=1M count=128 status=none
    parted -s $@ mklabel msdos
    # 0分区：32MB~64MB（32MB大小，对应原厂0.img）
    parted -s $@ mkpart primary linux 32M 64M
    dd if=$(KDIR)/0.img of=$@ bs=4K seek=$((32*1024*1024/4096)) conv=notrunc status=none
    # 1分区：96MB开始（32+32+64），对应原厂1.img偏移
    parted -s $@ mkpart primary linux 96M 100%
    dd if=$(KDIR)/1.img of=$@ bs=4K seek=$((96*1024*1024/4096)) conv=notrunc status=none
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
