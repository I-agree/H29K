# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
    $(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
    # This creates a new folder copies the dtb (as rockchip.dtb) 
    # and the kernel image (as kernel.img)
    rm -fR $@.boot
    mkdir -p $@.boot

    $(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
endef

define Build/boot-script
    # Make an U-boot image and copy it to the boot partition
    mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# --- ✅ STEP 1: REPLACE ORIGINAL Build/pine64-img (17 lines added, 4 lines removed) ---
define Build/pine64-img
    # Build 0.img: 64MB FAT32 boot partition containing kernel.img, dtb, boot.scr
    rm -f $(KDIR)/0.img
    dd if=/dev/zero of=$(KDIR)/0.img bs=1M count=64
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    mkdir -p $(KDIR)/h29k-boot
    $(CP) $@.boot/kernel.img $(KDIR)/h29k-boot/hinlink_h29k-kernel.bin
    $(CP) $(DTS_DIR)/rockchip/$(DEVICE_DTS).dtb $(KDIR)/h29k-boot/rk3528-hinlink-h29k.dtb
    $(CP) $@.boot/boot.scr $(KDIR)/h29k-boot/boot.scr
    mcopy -i $(KDIR)/0.img $(KDIR)/h29k-boot/* ::/

    # Build 1.img: 1024MB ext4 system partition from $(IMAGE_ROOTFS)
    rm -f $(KDIR)/1.img
    $(STAGING_DIR_HOST)/bin/make_ext4fs \
        -J -L system -l 1024M \
        $(KDIR)/1.img \
        $(IMAGE_ROOTFS)

    # Package into $@ (sysupgrade.img.gz) as tar archive
    rm -f $(KDIR)/h29k-package.tar
    tar -cf $(KDIR)/h29k-package.tar -C $(KDIR) 0.img 1.img
    gzip -c $(KDIR)/h29k-package.tar > $@
endef
# --- ✅ END OF MODIFICATION ---

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
