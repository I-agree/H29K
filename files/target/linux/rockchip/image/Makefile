include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

define Build/boot-common
	rm -fR $@.boot
	mkdir -p $@.boot
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/$(DEVICE_DTS).dtb
endef

define Build/boot-script
	mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

define Build/h29k-img
	rm -f $(KDIR)/boot.img
	dd if=/dev/zero of=$(KDIR)/boot.img bs=1M count=32
	mkfs.vfat -F 32 -n BOOT $(KDIR)/boot.img
	mcopy -i $(KDIR)/boot.img $@.boot/* ::/

	rm -f $@
	dd if=/dev/zero of=$@ bs=1M count 256
	parted -s $@ mklabel msdos
	parted -s $@ mkpart primary fat32 1MiB 33MiB
	parted -s $@ mkpart primary 33MiB 100%
	parted -s $@ set 1 boot on

	dd if=$(KDIR)/boot.img of=$@ bs=1M seek=1 conv=notrunc
	dd if=$(KDIR)/root.squashfs of=$@ bs=1M seek=33 conv=notrunc
endef

define Device/Default
  PROFILES := Default
  KERNEL_LOADADDR := 0x00280000
  DEVICE_DTS_DIR := $(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
endef

$(eval $(call BuildImage))
