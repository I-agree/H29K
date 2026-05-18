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

# --- ✅ 厂家同款格式：单个 img 包，解压直接是 img ---
define Build/pine64-img
    # 👇 【云编译强兼容修复】调用顶层 tools/Makefile 的标准 install target
    #    ✅ tools/squashfs4/install 是 OpenWrt 官方定义的合法 target
    #    ✅ 自动依赖 compile → 构建 + 安装原子完成
    #    ❌ $(MAKE) -C $(TOPDIR)/tools/squashfs4 install 是非法的（无该 target）
    $(MAKE) -w -s -C $(TOPDIR) tools/squashfs4/install || { \
        echo "❌ FATAL: Failed to build & install mksquashfs from tools/squashfs4"; \
        exit 1; \
    }

    # 👇 【防御性校验】确保 mksquashfs 真正可用（防 staging_dir 权限/符号链接异常）
    if ! [ -x "$(STAGING_DIR_HOST)/bin/mksquashfs" ]; then \
        echo "❌ FATAL: $(STAGING_DIR_HOST)/bin/mksquashfs not found or not executable"; \
        ls -l "$(STAGING_DIR_HOST)/bin/mksquashfs" 2>/dev/null || echo "(file missing)"; \
        exit 1; \
    fi

    # Step 1: Build 0.img
    rm -f $(KDIR)/0.img
    dd if=/dev/zero of=$(KDIR)/0.img bs=1M count=64
    mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/0.img
    mkdir -p $(KDIR)/h29k-boot
    $(CP) $@.boot/kernel.img $(KDIR)/h29k-boot/kernel.img
    $(CP) $@.boot/rockchip.dtb $(KDIR)/h29k-boot/rockchip.dtb
    $(CP) $@.boot/boot.scr $(KDIR)/h29k-boot/boot.scr
    mcopy -i $(KDIR)/0.img $(KDIR)/h29k-boot/* ::/

    # Step 2: Build 1.img — using official squashfs4 + xz (no zstd, no mksquashfs-ng)
    rm -f $(KDIR)/1.img
    $(STAGING_DIR_HOST)/bin/mksquashfs \
        $(STAGING_DIR_ROOT) \
        $(KDIR)/1.img \
        -comp xz \
        -no-xattrs \
        -noappend \
        -root-owned \
        -b 256K \
        -fixed-time 0

    # ==============================
    # ✅ 关键修改：厂家格式（非tar）
    # ==============================
    cat $(KDIR)/0.img $(KDIR)/1.img > $@
endef

### Devices ###
define Device/Default
    PROFILES := Default
    KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
    KERNEL_LOADADDR := 0x00280000
    BOOT_SCRIPT := default
    IMAGES := sysupgrade.img.gz
    IMAGE/sysupgrade.img.gz = boot-common | boot-script | pine64-img | gzip
    DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
    DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
    UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
