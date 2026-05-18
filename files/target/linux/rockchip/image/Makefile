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
    # Step 1: Build 0.img
    rm -f $(KDIR)/0.img
    dd if=/dev/zero of=$(KDIR)/0.img bs=1M count=64
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    mkdir -p $(KDIR)/h29k-boot
    $(CP) $@.boot/kernel.img $(KDIR)/h29k-boot/kernel.img
    $(CP) $@.boot/rockchip.dtb $(KDIR)/h29k-boot/rockchip.dtb
    $(CP) $@.boot/boot.scr $(KDIR)/h29k-boot/boot.scr
    mcopy -i $(KDIR)/0.img $(KDIR)/h29k-boot/* ::/

    # ==============================
    # ✅ 只校验：OpenWrt 生成的 1.img 是否存在
    # ==============================
    if [ ! -f "$(KDIR)/1.img" ]; then \
        echo "====================================================="; \
        echo "ERROR: 1.img NOT FOUND! OpenWrt did not generate it!"; \
        echo "PATH: $(KDIR)/1.img"; \
        echo "====================================================="; \
        false; \
    fi

    # ==============================
    # ✅ 直接拼接：0.img(boot) + 1.img(rootfs)
    # ==============================
    cat $(KDIR)/0.img $(KDIR)/1.img > $@
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
