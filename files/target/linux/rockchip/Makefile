# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

BOARD:=rockchip
BOARDNAME:=Rockchip
FEATURES:=ext4 audio usb usbgadget display gpio fpu pci pcie rootfs-part boot-part squashfs
SUBTARGETS:=armv8

# 👇【关键修复】强制 target/linux/install 等待 tools/squashfs4/install 完成
HOST_BUILD_DEPENDS += squashfs4/host

KERNEL_PATCHVER:=6.12

define Target/Description
    Build firmware image for Rockchip SoC devices.
endef

# === 🔒 关键加固：强制限定补丁作用域（防 ipq806x/mpc85xx/qualcommax 等污染） ===
# 此处重载 Kernel/Patch 规则，确保 ONLY rockchip/patches-* 被应用
define Kernel/Patch
    $(call Patch/Default)
    # 清空默认 PATCH_DIRS（避免 generic/hack-* 等被自动包含）
    PATCH_DIRS :=
    # 显式指定 rockchip 专属 patch 目录（按内核版本自动匹配）
    PATCH_DIRS += $(PKG_BUILD_DIR)/../patches-$(LINUX_VERSION)
    PATCH_DIRS += $(PKG_BUILD_DIR)/../patches
    # 若存在 rockchip/patches-6.12，则优先使用；否则 fallback 到通用 patches/
    $(foreach dir,$(PATCH_DIRS), \
        $(if $(wildcard $(dir)), \
            $(call Patch/Path,$(dir)) \
        ) \
    )
endef

include $(INCLUDE_DIR)/target.mk

DEFAULT_PACKAGES += uboot-envtools partx-utils e2fsprogs mkf2fs kmod-input-gpio-keys input-event-daemon


KERNELNAME:=Image dtbs

$(eval $(call BuildTarget))
