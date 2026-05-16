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

    # ✅ PROVEN BY BUILD LOG: DTB is named 'image-$(DEVICE_DTS).dtb'
    #    e.g., for DEVICE_DTS = rk3528-hinlink-h29k → file: image-rk3528-hinlink-h29k.dtb
    if [ ! -f "$(KDIR)/image-$(DEVICE_DTS).dtb" ]; then \
        echo "ERROR: DTB not found — expected: $(KDIR)/image-$(DEVICE_DTS).dtb" >&2; \
        echo "Hint: Ensure 'target/linux/rockchip/dts/$(DEVICE_DTS).dts' exists and compiles cleanly." >&2; \
        exit 1; \
    fi
    $(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/rockchip.dtb
endef

define Build/boot-script
    # Generate U-Boot boot script for RK3528
    mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# --- ✅ Build/pine64-img: NOW WITH SQUASHFS ROOTFS ---
define Build/pine64-img
    # Step 1: Build 0.img — FAT32 boot partition (64MB) — unchanged
    rm -f $(KDIR)/0.img
    dd if=/dev/zero of=$(KDIR)/0.img bs=1M count=64
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    mkdir -p $(KDIR)/h29k-boot
    $(CP) $@.boot/kernel.img $(KDIR)/h29k-boot/kernel.img
    $(CP) $@.boot/rockchip.dtb $(KDIR)/h29k-boot/rockchip.dtb
    $(CP) $@.boot/boot.scr $(KDIR)/h29k-boot/boot.scr
    mcopy -i $(KDIR)/0.img $(KDIR)/h29k-boot/kernel.img $(KDIR)/h29k-boot/rockchip.dtb $(KDIR)/h29k-boot/boot.scr ::/

    # Step 2: Build 1.img — SQUASHFS rootfs (compressed, ~100–300MB), using STAGING_DIR_ROOT
    rm -f $(KDIR)/1.img
    if [ ! -d "$(STAGING_DIR_ROOT)" ]; then \
        echo "ERROR: STAGING_DIR_ROOT ($(STAGING_DIR_ROOT)) missing. Run 'make package/install' first." >&2; \
        exit 1; \
    fi
    # ✅ Use mksquashfs instead of make_ext4fs
    # -comp zstd: best ratio/speed balance for ARM64 (CONFIG_SQUASHFS_DECOMPRESSOR_ZSTD=y required)
    # -no-xattrs: avoids permission warnings on build host
    # -noappend: overwrite existing 1.img
    # -root-owned: ensure / owned by root:root (required by OpenWrt init)
    # -b 256k: block size optimized for eMMC random read
    $(STAGING_DIR_HOST)/bin/mksquashfs \
        $(STAGING_DIR_ROOT) \
        $(KDIR)/1.img \
        -comp zstd \
        -no-xattrs \
        -noappend \
        -root-owned \
        -b 256K \
        -fixed-time 0

    # Step 3: Package as squashfs-sysupgrade.img (NOT .gz) — matches OpenWrt naming convention
    rm -f $(BIN_DIR)/openwrt-rockchip-armv8-$(DEVICE_NAME)-squashfs-sysupgrade.img
    $(TAR) -cf - -C $(KDIR) 0.img 1.img | \
        $(STAGING_DIR_HOST)/bin/lzma -zc > $(BIN_DIR)/openwrt-rockchip-armv8-$(DEVICE_NAME)-squashfs-sysupgrade.img
endef

### Devices ###
define Device/Default
    PROFILES := Default
    KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
    KERNEL_LOADADDR :=
    BOOT_SCRIPT :=
    IMAGES := squashfs-sysupgrade.img.gz
    IMAGE/squashfs-sysupgrade.img.gz = boot-common | boot-script | pine64-img | gzip
    DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
    DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
    UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
