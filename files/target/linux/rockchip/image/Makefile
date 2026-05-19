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
    # 严格遵守：
    # 1. RKAF header = 12字节（RKAF + size + 0000）
    # 2. 0.img 和 1.img 都带完整 RKAF 头
    # 3. 4K对齐
    # 4. MBR分区表
    # ==============================================

    # ==============================================
    # Step 1: 制作 0.img (BOOT分区 32MB = 65536扇区) + RKAF 12字节头
    # ==============================================
    rm -f $(KDIR)/0.img $(KDIR)/0.img.raw
    # 1.1 生成 32MB FAT32 4K对齐
    dd if=/dev/zero of=$(KDIR)/0.img.raw bs=4K count=8192 status=none
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img.raw
    # 写入文件
    mkdir -p $(KDIR)/bootfiles
    $(CP) $@.boot/* $(KDIR)/bootfiles/
    mcopy -i $(KDIR)/0.img.raw $(KDIR)/bootfiles/* ::/

    # 1.2 生成 12字节 RKAF 头（关键！）
    # RKAF(4) + size(LE, 扇区数) + 0000(4) = 12字节
    printf "\x52\x4B\x41\x46" > $(KDIR)/rkaf12.tmp
    printf "\x00\x00\x01\x00" >> $(KDIR)/rkaf12.tmp  # 32MB = 65536扇区 LE
    printf "\x00\x00\x00\x00" >> $(KDIR)/rkaf12.tmp

    # 1.3 合并 RKAF(12) + 分区数据 = 最终0.img
    cat $(KDIR)/rkaf12.tmp $(KDIR)/0.img.raw > $(KDIR)/0.img

    # ==============================================
    # Step 2: 制作 1.img (rootfs) + 12字节 RKAF 头（加固完成）
    # ==============================================
    rm -f $(KDIR)/1.img
    # 计算 root.squashfs 扇区数（512字节/扇区）
    SIZE=$$(wc -c < $(KDIR)/root.squashfs); \
    SECTORS=$$(( (SIZE + 511) / 512 )); \
    B0=$$(( SECTORS & 0xff )); \
    B1=$$(( (SECTORS >> 8) & 0xff )); \
    B2=$$(( (SECTORS >> 16) & 0xff )); \
    B3=$$(( (SECTORS >> 24) & 0xff )); \
    \
    # 生成 12字节 RKAF header
    printf "\x52\x4B\x41\x46" > $(KDIR)/1.img; \
    printf "\\\\x$$(printf "%02x" $$B0)\\\\x$$(printf "%02x" $$B1)\\\\x$$(printf "%02x" $$B2)\\\\x$$(printf "%02x" $$B3)" >> $(KDIR)/1.img; \
    printf "\x00\x00\x00\x00" >> $(KDIR)/1.img; \
    \
    # 4K对齐追加 squashfs 数据
    dd if=$(KDIR)/root.squashfs of=$(KDIR)/1.img bs=4K conv=sync seek=3 status=none

    # ==============================================
    # Step3: 整机镜像 MBR + 分区写入（BootROM可解析）
    # ==============================================
    rm -f $@
    dd if=/dev/zero of=$@ bs=1M count=1 status=none
    parted -s $@ mklabel msdos
    # 分区1：boot 32M-64M
    parted -s $@ mkpart primary linux 32M 64M
    dd if=$(KDIR)/0.img of=$@ bs=4K seek=8192 conv=notrunc status=none
    # 分区2：rootfs 96M开始
    parted -s $@ mkpart primary linux 96M 100%
    dd if=$(KDIR)/1.img of=$@ bs=4K seek=24576 conv=notrunc status=none

    rm -f $(KDIR)/*.tmp $(KDIR)/*.raw $(KDIR)/bootfiles -r
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
