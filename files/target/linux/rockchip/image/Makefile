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
    # ==============================================
    # ROCKCHIP 原厂标准：
    # 1. 0.img = RKAF + FAT32 boot (4K对齐)
    # 2. 1.img = RKAF + squashfs (4K对齐)
    # 3. 整机 = MBR + 原厂偏移 + RKAF分区
    # ==============================================

    # --------------------------
    # Step 1: 制作 32MB RKAF boot 分区 (0.img)
    # --------------------------
    rm -f $(KDIR)/0.img
    # 32MB 4K对齐
    dd if=/dev/zero of=$(KDIR)/0.img bs=4K count=8192 status=none
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    # 写入内核、设备树、boot.scr
    mkdir -p $(KDIR)/boot-files
    $(CP) $@.boot/* $(KDIR)/boot-files/
    mcopy -i $(KDIR)/0.img $(KDIR)/boot-files/* ::/
    # RKAF 封装（Rockchip 强制）
    echo -n -e "\x52\x4B\x41\x46" >> $(KDIR)/0.img.tmp
    cat $(KDIR)/0.img >> $(KDIR)/0.img.tmp
    mv $(KDIR)/0.img.tmp $(KDIR)/0.img

    # --------------------------
    # Step 2: 制作 带 RKAF header 的 1.img（核心修复）
    # --------------------------
    rm -f $(KDIR)/1.img
    # 写入 RKAF 魔术头 (0x46414B52 = "RKAF")
    echo -n -e "\x52\x4B\x41\x46" > $(KDIR)/1.img
    # 4K对齐追加 squashfs（真正的系统分区）
    dd if=$(KDIR)/root.squashfs of=$(KDIR)/1.img bs=4K conv=sync seek=1 status=none

    # --------------------------
    # Step 3: 构建整机 MBR 固件（BootROM 可识别）
    # --------------------------
    rm -f $@
    dd if=/dev/zero of=$@ bs=1M count=1 status=none
    parted -s $@ mklabel msdos
    # 分区1：boot (RKAF)
    parted -s $@ mkpart primary linux 32M 64M
    dd if=$(KDIR)/0.img of=$@ bs=4K seek=8192 conv=notrunc status=none
    # 分区2：rootfs (RKAF + squashfs)
    parted -s $@ mkpart primary linux 96M 100%
    dd if=$(KDIR)/1.img of=$@ bs=4K seek=24576 conv=notrunc status=none
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
