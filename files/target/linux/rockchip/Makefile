include $(TOPDIR)/rules.mk

define Kernel/Prepare/Default
    $(Kernel/Prepare/Default)
    mkdir -p $(PKG_BUILD_DIR)/arch/arm64/boot/dts/rockchip/
    cp -f $(TOPDIR)/files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts $(PKG_BUILD_DIR)/arch/arm64/boot/dts/rockchip/
endef

define Kernel/Configure/Default
    $(Kernel/Configure/Default)
    mkdir -p $(PKG_BUILD_DIR)/arch/arm64/boot/dts/rockchip/
    cp -f $(TOPDIR)/files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts $(PKG_BUILD_DIR)/arch/arm64/boot/dts/rockchip/
endef
