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
    # Copy DTB: use DEVICE_DTS as base, strip prefix if needed (e.g., "rk3528-hinlink-h29k" → "hinlink-h29k")
    $(CP) $(KDIR)/image-$(subst rk3528-,,$(DEVICE_DTS)).dtb $@.boot/rockchip.dtb
endef

define Build/boot-script
    # Generate U-Boot boot script for RK3528
    mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# --- ✅ Build/pine64-img: Optimized for ROOTFS_TYPE=ext4 & hinlink_h29k ---
define Build/pine64-img
    # Step 1: Build 0.img — FAT32 boot partition (64MB)
    rm -f $(KDIR)/0.img
    dd if=/dev/zero of=$(KDIR)/0.img bs=1M count=64
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    mkdir -p $(KDIR)/h29k-boot
    $(CP) $@.boot/kernel.img $(KDIR)/h29k-boot/kernel.img
    $(CP) $@.boot/rockchip.dtb $(KDIR)/h29k-boot/rockchip.dtb
    $(CP) $@.boot/boot.scr $(KDIR)/h29k-boot/boot.scr
    mcopy -i $(KDIR)/0.img $(KDIR)/h29k-boot/kernel.img $(KDIR)/h29k-boot/rockchip.dtb $(KDIR)/h29k-boot/boot.scr ::/

    # Step 2: Build 1.img — ext4 system partition (1024MB), using STAGING_DIR_ROOT
    rm -f $(KDIR)/1.img
    if [ ! -d "$(STAGING_DIR_ROOT)" ]; then \
        echo "ERROR: STAGING_DIR_ROOT ($(STAGING_DIR_ROOT)) missing. Run 'make package/install' first." >&2; \
        exit 1; \
    fi
    $(STAGING_DIR_HOST)/bin/make_ext4fs \
        -J -L system -l 1024M \
        $(KDIR)/1.img \
        $(STAGING_DIR_ROOT)

    # Step 3: Package as tar.gz
    rm -f $(KDIR)/h29k-package.tar
    tar -cf $(KDIR)/h29k-package.tar -C $(KDIR) 0.img 1.img
    gzip -c $(KDIR)/h29k-package.tar > $@
endef

### Devices ###
define Device/Default
    PROFILES := Default
    KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
    KERNEL_LOADADDR :=
    BOOT_SCRIPT :=
    IMAGES := sysupgrade.img.gz
    IMAGE/sysupgrade.img.gz = boot-common | boot-script | pine64-img | gzip
    DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
    DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
    UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
