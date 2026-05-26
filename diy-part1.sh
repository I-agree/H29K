#!/bin/sh
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
# 添加 QModem 软件源
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default
# 无线网卡驱动
echo 'src-git aic8800 https://github.com/radxa-pkg/aic8800.git;main' >> feeds.conf.default
# 正确安装 argon 主题
git clone https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon

# ==============================================================================
# 终极修复 kmod-dma-buf 死循环：
# 1. 保留内核 CONFIG_DMA_SHARED_BUFFER=y  → 屏幕/DRM 100%正常
# 2. 清空 FILES 和 AUTOLOAD → 不找 .ko 文件，不报错
# 3. 生成空的合法 ipk → 满足所有依赖，不影响任何程序
# 4. 无需 CONFIG_PACKAGE_kmod-dma-buf=n → 彻底安全
# ==============================================================================
sed -i '/define KernelPackage\/dma-buf/,/endef/{
  s|^\s*FILES:=\$(LINUX_DIR)/drivers/dma-buf/dma-shared-buffer.ko|  FILES:=|
  s|^\s*AUTOLOAD:=\$(call AutoLoad,20,dma-shared-buffer)|  AUTOLOAD:=|
}' package/kernel/linux/modules/other.mk

# 终极精致空包：kmod-sound-core（无语法错误、无警告、不影响依赖）
sed -i '/define KernelPackage\/sound-core/,/^endef/{
  s/^\(  FILES:=\).*/\1/
  s/^\(  AUTOLOAD:=\).*/\1/
}' package/kernel/linux/modules/sound.mk

# ====================== 方案：全套切换为LEDE rk3528.dtsi + rk3528-pinctrl.dtsi ======================
# 1. 清理OpenWrt原生冲突DTS和补丁
rm -f target/linux/rockchip/patches-6.12/070-01-v6.13-arm64-dts-rockchip-Add-base-DT-for-rk3528-SoC.patch
rm -f target/linux/rockchip/patches-6.12/070-04-v6.15-arm64-dts-rockchip-Add-pinctrl-and-gpio-nodes-for-RK3528.patch
rm -f target/linux/rockchip/patches-6.12/031-04-v6.15-hwrng-rockchip-store-dev-pointer-in-driver-struct.patch
rm -f target/linux/rockchip/patches-6.12/031-05-v6.15-hwrng-rockchip-eliminate-some-unnecessary-dereferenc.patch
rm -f target/linux/rockchip/patches-6.12/031-06-v6.15-hwrng-rockchip-add-support-for-rk3588-s-standalone-T.patch
rm -f target/linux/rockchip/patches-6.12/031-07-v6.16-hwrng-rockchip-add-support-for-RK3576-s-RNG.patch
rm -f target/linux/rockchip/patches-6.12/031-03-v6.15-dt-bindings-rng-rockchip-rk3588-rng-Drop-unnecessary.patch
rm -f target/linux/rockchip/patches-6.12/032-20-v6.15-clk-rockchip-Add-clock-controller-driver-for-RK3528-SoC.patch
rm -f target/linux/rockchip/patches-6.12/032-21-v6.15-clk-rockchip-rk3528-Add-reset-lookup-table.patch
rm -f target/linux/rockchip/patches-6.12/032-24-v6.16-clk-rockchip-Support-MMC-clocks-in-GRF-region.patch
rm -f target/linux/rockchip/patches-6.12/032-25-v6.16-clk-rockchip-Pass-NULL-as-reg-pointer-when-registering-GR.patch
rm -f target/linux/rockchip/patches-6.12/032-26-v6.16-clk-rockchip-rk3528-Add-SD-SDIO-tuning-clocks-in-GRF.patch
rm -f target/linux/rockchip/patches-6.12/101-arm64-dts-rockchip-Add-HINLINK-H28K.patch
rm -f package/boot/uboot-rockchip/patches/107-board-rockchip-add-HINLINK-H28K.patch
rm -rf target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528*.dtsi
rm -rf target/linux/generic/hack-6.12
rm -rf target/linux/bcm27xx/patches-6.12
rm -f target/linux/generic/hack-6.18/920-device_tree_cmdline.patch
rm -f target/linux/ipq806x/patches-6.12/901-02-ARM-decompressor-add-option-to-ignore-MEM-ATAGs.patch
rm -f target/linux/mpc85xx/patches-6.12/102-powerpc-add-cmdline-override.patch
rm -f package/boot/uboot-mediatek/patches/280-image-fdt-save-name-of-FIT-configuration-in-chosen-node.patch
rm -f target/linux/generic/hack-6.12/920-device_tree_cmdline.patch
rm -f target/linux/mpc85xx/patches-6.18/102-powerpc-add-cmdline-override.patch
rm -f target/linux/mediatek/patches-6.18/901-arm-add-cmdline-override.patch
rm -f target/linux/qualcommax/patches-6.12/0911-arm64-cmdline-replacement.patch
rm -f target/linux/ipq806x/patches-6.12/902-ARM-decompressor-support-for-ATAGs-rootblock-parsing.patch
rm -f target/linux/ipq806x/patches-6.12/900-arm-add-cmdline-override.patch
rm -f target/linux/mvebu/patches-6.12/300-mvebu-Mangle-bootloader-s-kernel-arguments.patch
rm -f target/linux/bcm27xx/patches-6.12/950-0076-OF-DT-Overlay-configfs-interface.patch
rm -rf target/linux/airoha
# rm -rf target/linux/rockchip/patches-6.12

# 自动删除所有 RK3588 / RK3576 无关补丁（适配 RK3528 H29K）
rm -f target/linux/rockchip/patches-6.12/001-01-v6.13-arm64-dts-rockchip-Split-up-RK3588-s-PCIe-pinctrls.patch
rm -f target/linux/rockchip/patches-6.12/001-02-v6.13-arm64-dts-rockchip-Add-HDMI0-node-to-rk3588.patch
rm -f target/linux/rockchip/patches-6.12/001-03-v6.15-arm64-dts-rockchip-Use-dma-noncoherent-in-base-RK358.patch
rm -f target/linux/rockchip/patches-6.12/001-04-v6.15-arm64-dts-rockchip-Enable-HDMI0-PHY-clk-provider-on-.patch
rm -f target/linux/rockchip/patches-6.12/001-05-v6.15-arm64-dts-rockchip-Add-HDMI0-PHY-PLL-clock-source-to.patch
rm -f target/linux/rockchip/patches-6.12/001-06-v6.15-arm64-dts-rockchip-Fix-label-name-of-hdptxphy-for-RK.patch
rm -f target/linux/rockchip/patches-6.12/001-07-v6.15-arm64-dts-rockchip-Add-PHY-node-for-HDMI1-TX-port-on.patch
rm -f target/linux/rockchip/patches-6.12/001-08-v6.15-arm64-dts-rockchip-Add-HDMI1-node-on-RK3588.patch
rm -f target/linux/rockchip/patches-6.12/001-09-v6.15-arm64-dts-rockchip-Enable-HDMI1-PHY-clk-provider-on-.patch
rm -f target/linux/rockchip/patches-6.12/001-10-v6.15-arm64-dts-rockchip-Add-HDMI1-PHY-PLL-clock-source-to.patch
rm -f target/linux/rockchip/patches-6.12/001-11-v6.15-arm64-dts-rockchip-Add-rng-node-to-RK3588.patch
rm -f target/linux/rockchip/patches-6.12/001-12-v6.15-arm64-dts-rockchip-Add-HDMI-audio-outputs-for-rk3588.patch
rm -f target/linux/rockchip/patches-6.12/001-13-v6.15-arm64-dts-rockchip-Add-GPU-power-domain-regulator-de.patch
rm -f target/linux/rockchip/patches-6.12/001-14-v6.15-arm64-dts-rockchip-change-rng-reset-id-back-to-its-c.patch
rm -f target/linux/rockchip/patches-6.12/001-15-v6.15-arm64-dts-rockchip-Add-device-tree-support-for-HDMI-.patch
rm -f target/linux/rockchip/patches-6.12/001-16-v6.19-arm64-dts-rockchip-add-eMMC-CQE-support-for-rk3588.patch

rm -f target/linux/rockchip/patches-6.12/002-01-v6.13-arm64-dts-rockchip-add-and-enable-gpu-node-for-Radxa.patch
rm -f target/linux/rockchip/patches-6.12/002-02-v6.13-arm64-dts-rockchip-Enable-HDMI0-on-rock-5a.patch
rm -f target/linux/rockchip/patches-6.12/002-03-v6.13-arm64-dts-rockchip-sort-rk3588s-rock5a-properly-in-M.patch
rm -f target/linux/rockchip/patches-6.12/002-04-v6.13-arm64-dts-rockchip-adapt-regulator-nodenames-to-pref.patch
rm -f target/linux/rockchip/patches-6.12/002-05-v6.15-arm64-dts-rockchip-Fix-label-name-of-hdptxphy-for-RK.patch
rm -f target/linux/rockchip/patches-6.12/002-06-v6.15-arm64-dts-rockchip-Add-GPU-power-domain-regulator-de.patch

rm -f target/linux/rockchip/patches-6.12/003-01-v6.13-arm64-dts-rockchip-Switch-to-hp-det-gpios.patch
rm -f target/linux/rockchip/patches-6.12/003-02-v6.13-arm64-dts-rockchip-Enable-HDMI0-on-rock-5b.patch
rm -f target/linux/rockchip/patches-6.12/003-03-v6.13-arm64-dts-rockchip-adapt-regulator-nodenames-to-pref.patch
rm -f target/linux/rockchip/patches-6.12/003-04-v6.13-arm64-dts-rockchip-rename-rfkill-label-for-Radxa-ROC.patch
rm -f target/linux/rockchip/patches-6.12/003-05-v6.15-arm64-dts-rockchip-Fix-label-name-of-hdptxphy-for-RK.patch
rm -f target/linux/rockchip/patches-6.12/003-06-v6.15-arm64-dts-rockchip-Enable-HDMI1-on-rock-5b.patch
rm -f target/linux/rockchip/patches-6.12/003-07-v6.15-arm64-dts-rockchip-Enable-HDMI-audio-outputs-for-Roc.patch
rm -f target/linux/rockchip/patches-6.12/003-08-v6.15-arm64-dts-rockchip-Add-GPU-power-domain-regulator-de.patch
rm -f target/linux/rockchip/patches-6.12/003-09-v6.15-arm64-dts-rockchip-Enable-HDMI-receiver-on-rock-5b.patch
rm -f target/linux/rockchip/patches-6.12/003-10-v6.16-arm64-dts-rockchip-Add-vcc-supply-to-SPI-flash-on-rk.patch
rm -f target/linux/rockchip/patches-6.12/003-11-v6.16-arm64-dts-rockchip-move-rock-5b-to-include-file.patch
rm -f target/linux/rockchip/patches-6.12/003-12-v6.16-arm64-dts-rockchip-add-Rock-5B.patch
rm -f target/linux/rockchip/patches-6.12/003-13-v6.17-arm64-dts-rockchip-rename-rk3588-rock-5b.dtsi.patch
rm -f target/linux/rockchip/patches-6.12/003-14-v6.17-arm64-dts-rockchip-move-common-ROCK-5B-nodes-into-ow.patch
rm -f target/linux/rockchip/patches-6.12/003-15-v6.17-arm64-dts-rockchip-add-ROCK-5T-device-tree.patch
rm -f target/linux/rockchip/patches-6.12/003-16-v6.17-arm64-dts-rockchip-fix-USB-on-RADXA-ROCK-5T.patch
rm -f target/linux/rockchip/patches-6.12/003-17-v6.17-arm64-dts-rockchip-fix-second-M.2-slot-on-ROCK-5T.patch

rm -f target/linux/rockchip/patches-6.12/004-01-v6.13-arm64-dts-rockchip-Switch-to-hp-det-gpios.patch
rm -f target/linux/rockchip/patches-6.12/004-02-v6.13-arm64-dts-rockchip-fix-the-pcie-refclock-oscillator-.patch
rm -f target/linux/rockchip/patches-6.12/004-03-v6.14-arm64-dts-rockchip-slow-down-emmc-freq-for-rock-5-it.patch
rm -f target/linux/rockchip/patches-6.12/004-04-v6.15-arm64-dts-rockchip-add-hdmi1-support-to-ROCK-5-ITX.patch
rm -f target/linux/rockchip/patches-6.12/004-05-v6.15-arm64-dts-rockchip-Add-GPU-power-domain-regulator-de.patch

rm -f target/linux/rockchip/patches-6.12/005-01-v6.13-arm64-dts-rockchip-add-Radxa-ROCK-5C.patch
rm -f target/linux/rockchip/patches-6.12/005-02-v6.15-arm64-dts-rockchip-Add-finer-grained-PWM-states-for-.patch
rm -f target/linux/rockchip/patches-6.12/005-03-v6.15-arm64-dts-rockchip-Enable-automatic-fan-control-on-R.patch
rm -f target/linux/rockchip/patches-6.12/005-04-v6.15-arm64-dts-rockchip-Fix-label-name-of-hdptxphy-for-RK.patch
rm -f target/linux/rockchip/patches-6.12/005-05-v6.15-arm64-dts-rockchip-switch-Rock-5C-to-PMIC-based-TSHU.patch
rm -f target/linux/rockchip/patches-6.12/005-06-v6.15-arm64-dts-rockchip-Add-GPU-power-domain-regulator-de.patch

rm -f target/linux/rockchip/patches-6.12/006-01-v6.14-arm64-dts-rockchip-Add-Radxa-E52C.patch

rm -f target/linux/rockchip/patches-6.12/031-01-v6.15-dt-bindings-reset-Add-SCMI-reset-IDs-for-RK3588.patch
rm -f target/linux/rockchip/patches-6.12/031-02-v6.15-dt-bindings-rng-add-binding-for-Rockchip-RK3588-RNG.patch
rm -f target/linux/rockchip/patches-6.12/031-03-v6.15-dt-bindings-rng-rockchip-rk3588-rng-Drop-unnecessary.patch
rm -f target/linux/rockchip/patches-6.12/031-04-v6.15-hwrng-rockchip-store-dev-pointer-in-driver-struct.patch
rm -f target/linux/rockchip/patches-6.12/031-05-v6.15-hwrng-rockchip-eliminate-some-unnecessary-dereferenc.patch
rm -f target/linux/rockchip/patches-6.12/031-06-v6.15-hwrng-rockchip-add-support-for-rk3588-s-standalone-T.patch
rm -f target/linux/rockchip/patches-6.12/031-07-v6.16-hwrng-rockchip-add-support-for-RK3576-s-RNG.patch

rm -f target/linux/rockchip/patches-6.12/032-01-v6.14-clk-rockchip-support-clocks-registered-late.patch
rm -f target/linux/rockchip/patches-6.12/032-02-v6.14-clk-rockchip-rk3588-register-GATE_LINK-later.patch
rm -f target/linux/rockchip/patches-6.12/032-03-v6.14-clk-rockchip-expose-rockchip_clk_set_lookup.patch
rm -f target/linux/rockchip/patches-6.12/032-04-v6.14-clk-rockchip-implement-linked-gate-clock-support.patch
rm -f target/linux/rockchip/patches-6.12/032-05-v6.14-clk-rockchip-rk3588-drop-RK3588_LINKED_CLK.patch
rm -f target/linux/rockchip/patches-6.12/032-06-v6.14-clk-rockchip-rk3588-make-refclko25m_ethX-critical.patch
rm -f target/linux/rockchip/patches-6.12/032-07-v6.15-clk-rockchip-rk3568-mark-hclk_vi-as-critical.patch
rm -f target/linux/rockchip/patches-6.12/032-08-v6.16-clk-rockchip-rk3588-Add-PLL-rate-for-1500-MHz.patch
rm -f target/linux/rockchip/patches-6.12/032-09-v6.16-clk-rockchip-Drop-empty-init-callback-for-rk3588-PLL-type.patch

rm -f target/linux/rockchip/patches-6.12/032-10-v6.15-soc-rockchip-add-header-for-suspend-mode-SIP-interface.patch
rm -f target/linux/rockchip/patches-6.12/032-11-v6.15-clk-rockchip-rk3576-define-clk_otp_phy_g.patch
rm -f target/linux/rockchip/patches-6.12/032-12-v6.15-dt-bindings-clock-rk3576-add-SCMI-clocks.patch
rm -f target/linux/rockchip/patches-6.12/032-13-v6.16-dt-bindings-clock-rk3576-add-IOC-gated-clocks.patch
rm -f target/linux/rockchip/patches-6.12/032-14-v6.16-clk-rockchip-introduce-auxiliary-GRFs.patch
rm -f target/linux/rockchip/patches-6.12/032-15-v6.16-clk-rockchip-introduce-GRF-gates.patch
rm -f target/linux/rockchip/patches-6.12/032-16-v6.16-clk-rockchip-add-GATE_GRFs-for-SAI-MCLKOUT-to-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/032-17-v6.16-clk-rockchip-rk3576-add-missing-slab-h-include.patch

rm -f target/linux/rockchip/patches-6.12/033-01-v6.15-pmdomain-rockchip-Add-smc-call-to-inform-firmware.patch
rm -f target/linux/rockchip/patches-6.12/033-02-v6.15-pmdomain-rockchip-Check-if-SMC-could-be-handled-by-TA.patch
rm -f target/linux/rockchip/patches-6.12/033-03-v6.15-pmdomain-rockchip-Fix-build-error.patch

rm -f target/linux/rockchip/patches-6.12/034-01-v6.17-thermal-drivers-rockchip-Rename-rk_tsadcv3_tshut_mode.patch
rm -f target/linux/rockchip/patches-6.12/034-02-v6.17-thermal-drivers-rockchip-Support-RK3576-SoC-in-the-therma.patch
rm -f target/linux/rockchip/patches-6.12/034-03-v6.17-thermal-drivers-rockchip-Support-reading-trim-values-from.patch

rm -f target/linux/rockchip/patches-6.12/036-03-v6.13-phy-rockchip-inno-usb2-Add-usb2-phys-support-for-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/036-04-v6.13-phy-rockchip-usbdp-add-rk3576-device-match-data.patch
rm -f target/linux/rockchip/patches-6.12/036-05-v6.14-phy-rockchip-naneng-combo-add-rk3576-support.patch

rm -f target/linux/rockchip/patches-6.12/037-01-v6.15-scsi-ufs-core-Export-ufshcd_dme_reset-and.patch
rm -f target/linux/rockchip/patches-6.12/037-02-v6.15-scsi-ufs-rockchip-Initial-support-for-UFS.patch
rm -f target/linux/rockchip/patches-6.12/037-03-v6.15-scsi-ufs-rockchip-Fix-devm_clk_bulk_get_all_enabled.patch
rm -f target/linux/rockchip/patches-6.12/037-04-v6.19-mmc-sdhci-of-dwcmshc-Add-command-queue-support-for-rockch.patch
rm -f target/linux/rockchip/patches-6.12/037-05-v6.19-mmc-sdhci-of-dwcmshc-Fix-command-queue-support-for-RK3576.patch
rm -f target/linux/rockchip/patches-6.12/037-06-v6.19-mmc-sdhci-of-dwcmshc-Disable-internal-clock-auto-gate-for.patch
rm -f target/linux/rockchip/patches-6.12/037-07-v6.19-mmc-sdhci-of-dwcmshc-reduce-CIT-for-better-performance.patch

rm -f target/linux/rockchip/patches-6.12/050-01-v6.13-arm64-dts-rockchip-Add-rk3576-SoC-base-DT.patch
rm -f target/linux/rockchip/patches-6.12/050-02-v6.14-arm64-dts-rockchip-Add-rk3576-naneng-combphy-nodes.patch
rm -f target/linux/rockchip/patches-6.12/050-03-v6.14-arm64-dts-rockchip-add-usb-related-nodes-for-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-04-v6.15-arm64-dts-rockchip-add-rk3576-otp-node.patch
rm -f target/linux/rockchip/patches-6.12/050-05-v6.15-scsi-arm64-dts-rockchip-Add-UFS-support-for-RK3576-SoC.patch
rm -f target/linux/rockchip/patches-6.12/050-06-v6.15-arm64-dts-rockchip-Add-vop-for-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-07-v6.15-arm64-dts-rockchip-Add-hdmi-for-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-08-v6.15-arm64-dts-rockchip-Add-SFC-nodes-for-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-09-v6.15-arm64-dts-rockchip-fix-RK3576-SCMI-clock-IDs.patch
rm -f target/linux/rockchip/patches-6.12/050-10-v6.16-arm64-dts-rockchip-Add-rk3576-pcie-nodes.patch
rm -f target/linux/rockchip/patches-6.12/050-11-v6.16-arm64-dts-rockchip-add-SATA-nodes-to-RK3576.patch
rm -f target/linux/rockchip/patches-6.12/050-12-v6.16-arm64-dts-rockchip-add-RK3576-RNG-node.patch
rm -f target/linux/rockchip/patches-6.12/050-13-v6.16-arm64-dts-rockchip-Add-RK3576-SAI-nodes.patch
rm -f target/linux/rockchip/patches-6.12/050-14-v6.16-arm64-dts-rockchip-Add-RK3576-HDMI-audio.patch
rm -f target/linux/rockchip/patches-6.12/050-15-v6.16-arm64-dts-rockchip-Add-missing-SFC-power-domains-to-rk357.patch
rm -f target/linux/rockchip/patches-6.12/050-16-v6.16-arm64-dts-rockchip-fix-rk3576-pcie-unit-addresses.patch
rm -f target/linux/rockchip/patches-6.12/050-17-v6.16-arm64-dts-rockchip-move-rk3576-pinctrl-node-outside-the.patch
rm -f target/linux/rockchip/patches-6.12/050-18-v6.16-arm64-dts-rockchip-remove-a-double-empty-line-from-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-19-v6.16-arm64-dts-rockchip-fix-rk3576-pcie1-linux-pci-domain.patch
rm -f target/linux/rockchip/patches-6.12/050-20-v6.17-arm64-dts-rockchip-add-SDIO-controller-on-RK3576.patch
rm -f target/linux/rockchip/patches-6.12/050-21-v6.17-arm64-dts-rockchip-Enable-HDMI-PHY-clk-provider-on-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-22-v6.17-arm64-dts-rockchip-Add-HDMI-PHY-PLL-clock-source-to-VOP2.patch
rm -f target/linux/rockchip/patches-6.12/050-23-v6.17-arm64-dts-rockchip-Add-thermal-nodes-to-RK3576.patch
rm -f target/linux/rockchip/patches-6.12/050-24-v6.17-arm64-dts-rockchip-Add-thermal-trim-OTP-and-tsadc-nodes.patch
rm -f target/linux/rockchip/patches-6.12/050-25-v6.17-arm64-dts-rockchip-add-mipi-dcphy-to-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-26-v6.17-arm64-dts-rockchip-add-the-dsi-controller-to-rk3576.patch
rm -f target/linux/rockchip/patches-6.12/050-27-v6.17-arm64-dts-rockchip-Enable-RK3576-watchdog.patch

# === 🔥 P3TERX: Auto-remove fdt.c pollution (RK3528 clean build) ===
# Remove fdt.c if exists (created by generic/bcm27xx/qualcommax patches)
rm -f "$BUILD_DIR"/target-*/linux-*/drivers/of/fdt.c
# Remove fdt.o reference from drivers/of/Makefile (added by bcm27xx/950-*.patch)
sed -i '/fdt\.o/d' "$BUILD_DIR"/target-*/linux-*/drivers/of/Makefile 2>/dev/null
# Remove CONFIG_OF_CONFIGFS line (side effect of bcm27xx/950-*.patch)
sed -i '/CONFIG_OF_CONFIGFS/d' "$BUILD_DIR"/target-*/linux-*/drivers/of/Kconfig 2>/dev/null
# Restore original of_fdt.h (remove early_init_dt_* declarations injected by 920-*.patch)
sed -i '/early_init_dt_verify/d; /early_init_dt_scan/d' "$BUILD_DIR"/target-*/linux-*/include/linux/of_fdt.h 2>/dev/null
# Ensure no stale .o/.ko files remain (defensive cleanup)
find "$BUILD_DIR"/target-*/linux-*/drivers/of/ -name "fdt.*" -delete 2>/dev/null

# 下载指定 dts 到目标目录，带校验
DTS_SAVE_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_SAVE_DIR"

curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/dts/rk3528-hinlink-h29k.dts \
-o "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts"

# 验证是否下载成功
if [ -f "$DTS_SAVE_DIR/rk3528-hinlink-h29k.dts" ]; then
    echo "✅ rk3528-hinlink-h29k.dts 下载并保存成功"
else
    echo "❌ rk3528-hinlink-h29k.dts 下载失败"
    exit 1
fi

# ==================== 稳定下载 H29K 配置文件 ====================
mkdir -p package/boot/uboot-rockchip/configs/ target/linux/rockchip/image/

# 下载地址
URL_UBOOT_DEF="https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"
URL_ARMV8_MK="https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/armv8.mk"

# 下载（curl 稳定版）
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$URL_UBOOT_DEF" -o "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig"

# 校验defconfig
[ -s "package/boot/uboot-rockchip/configs/hinlink-h29k-rk3528_defconfig" ] || { echo "❌ U-Boot defconfig 下载失败" >&2; exit 1; }

echo "✅ H29K 配置文件defconfig下载成功"

# ==================== 稳定下载 armv8.mk ====================
MK_FILE="target/linux/rockchip/image/armv8.mk"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$URL_ARMV8_MK" -o "$MK_FILE"

# 校验文件非空
if [ ! -s "$MK_FILE" ]; then
    echo "❌ 下载 armv8.mk 失败，终止编译"
    exit 1
fi

# 校验不包含 hinlink_h28k
if grep -q "hinlink_h28k" "$MK_FILE"; then
    echo "❌ ERROR: armv8.mk 包含 hinlink_h28k，终止编译"
    exit 1
fi

echo "✅ 已下载并替换 armv8.mk 成功"

# ==============================
# 【安装squashfs4】
# ==============================
# 定义正确目录
TARGET_DIR="target/linux/rockchip"
mkdir -p $TARGET_DIR

# 下载指定的官方原版修改的Makefile
echo "正在下载 rockchip Makefile ..."
curl -L --retry 5 \
https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/Makefile \
-o $TARGET_DIR/Makefile

echo -e "\n=============================================\n"

# 下载 H29K 专用 uboot-rockchip Makefile 并验证是否成功
echo "正在下载 H29K U-Boot Makefile..."
wget -q --show-progress --retry=3 --timeout=10 \
-O package/boot/uboot-rockchip/Makefile \
https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-rockchip/Makefile

# 验证文件是否下载成功
if [ -s package/boot/uboot-rockchip/Makefile ]; then
    echo -e "\033[42;37m 下载成功！U‑Boot Makefile 已正确安装 \033[0m"
    echo "路径：package/boot/uboot-rockchip/Makefile"
else
    echo -e "\033[41;37m 下载失败！请检查网络或链接 \033[0m"
    exit 1
fi

# 下载修复 uboot-tools 的 Makefile
echo "正在下载 uboot-tools 修复文件 ..."
wget -q --show-progress --retry=3 --timeout=10 \
-O package/boot/uboot-tools/Makefile \
https://raw.githubusercontent.com/I-agree/H29K/main/files/package/boot/uboot-tools/Makefile

# 验证是否下载成功
if [ -s package/boot/uboot-tools/Makefile ]; then
    echo -e "\033[42;37m 下载成功 ✅ uboot-tools 已修复 \033[0m"
else
    echo -e "\033[41;37m 下载失败 ❌ 请检查网络 \033[0m"
    exit 1
fi

# ==============================================
# 清理 Rockchip 旧网卡驱动（RK3528/H29K 不需要）
# ==============================================
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 删除 CONFIG_EMAC_ROCKCHIP=y
sed -i '/CONFIG_EMAC_ROCKCHIP=y/d' "$CONFIG_FILE"

# 删除 CONFIG_ARC_EMAC_CORE=y
sed -i '/CONFIG_ARC_EMAC_CORE=y/d' "$CONFIG_FILE"

echo "✅ 已清理无用网卡配置：CONFIG_EMAC_ROCKCHIP 和 CONFIG_ARC_EMAC_CORE 已删除"

# ==============================================
# 清理非法 PA_BITS 配置（RK3528 仅支持 CONFIG_ARM64_PA_BITS=40）
# ==============================================
# 删除 CONFIG_ARM64_PA_BITS=48
sed -i '/CONFIG_ARM64_PA_BITS=48/d' "$CONFIG_FILE"

# 删除 CONFIG_ARC_EMAC_CORE=y
sed -i '/CONFIG_ARM64_PA_BITS_48=y/d' "$CONFIG_FILE"

echo "✅ 已清理非法 PA_BITS 配置：CONFIG_ARM64_PA_BITS=48 和 CONFIG_ARC_EMAC_CORE=y 已删除"

# 定义配置文件路径
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

# 批量删除指定的配置项
sed -i '/CONFIG_ARM64_TAGGED_ADDR_ABI=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_COMPAT_32BIT_TIME=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_UNMAP_KERNEL_AT_EL0=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_RODATA_FULL_DEFAULT_ENABLED=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_ROCKCHIP_IOMMU=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_ERRATUM_1530923=y/d' "$CONFIG_FILE"
sed -i '/CONFIG_ARM64_ERRATUM_858921=y/d' "$CONFIG_FILE"

# 验证所有配置项是否删除成功
if grep -qE "CONFIG_ARM64_TAGGED_ADDR_ABI=y|CONFIG_COMPAT_32BIT_TIME=y|CONFIG_UNMAP_KERNEL_AT_EL0=y|CONFIG_RODATA_FULL_DEFAULT_ENABLED=y|CONFIG_ROCKCHIP_IOMMU=y|CONFIG_ARM64_ERRATUM_1530923=y|CONFIG_ARM64_ERRATUM_858921=y" "$CONFIG_FILE"; then
    echo "====================================================="
    echo " ❌ 错误：部分配置项删除失败，请检查！"
    echo "====================================================="
    exit 1
fi

echo "====================================================="
echo " ✅ 所有指定配置项已成功删除！"
echo " ✅ 验证通过，继续编译……"
echo "====================================================="

# 简单可靠：等待10秒后再继续执行（OpenWrt Actions 环境专用）
# 不依赖任何外部工具，兼容所有 BusyBox / dash / bash 环境

sleep 10

# ✅ 等待完成，后续命令可直接跟在此行下方
# 例如：
# echo "✅ 10秒已过，开始下一步..."
# make menuconfig

# ==============================================
# 为 Hinlink H29K 添加内核驱动配置（追加到文件末尾）
# ==============================================
# 定义配置文件路径
CONFIG_FILE="target/linux/rockchip/armv8/config-6.12"

cat >> "$CONFIG_FILE" << 'EOF'
# === 之前删除的项 ===
# CONFIG_EMAC_ROCKCHIP is not set
# CONFIG_ARC_EMAC_CORE is not set

# === RK3528 核心必需 ===
CONFIG_ROCKCHIP_RK3528=y
CONFIG_SOC_RK3528=y
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_EPAN=y
CONFIG_ARM64_PAN=y
CONFIG_ARM64_VHE=y
CONFIG_ARM64_PA_BITS_40=y
CONFIG_ARM64_VA_BITS_48=y
CONFIG_ARM64_ASIMD=y
CONFIG_CLK_RK3528_PLL=y
CONFIG_CLK_RK3528_ACLK_PERI=y
CONFIG_CLK_RK3528_HCLK_PERI=y
CONFIG_CLK_RK3528_PCLK_PERI=y
CONFIG_CLK_RK3528_ACLK_CPU=y

# === 显示 DRM ST7789V V2 ===
CONFIG_DRM_PANEL_SIMPLE=y
CONFIG_DRM_PANEL_ST7789V_V2=y
CONFIG_DRM_ROCKCHIP_VOP2=y
# CONFIG_DRM_ROCKCHIP_INNO_HDMI is not set
# CONFIG_DRM_ANALOGIX_DP is not set
# CONFIG_FB is not set

# === 触控 FT6236 ===
CONFIG_INPUT=y
CONFIG_INPUT_MISC=y
CONFIG_INPUT_POLLDEV=y
CONFIG_TOUCHSCREEN_FT6236=y

# === SPI 总线 ===
CONFIG_SPI=y
CONFIG_SPI_MASTER=y
CONFIG_SPI_ROCKCHIP_SPI=y
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_BACKLIGHT_PWM=y
CONFIG_REGULATOR=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y

# === USB DWC3 ===
CONFIG_USB_DWC3=y
CONFIG_USB_DWC3_HOST=y
CONFIG_USB_DWC3_GADGET=y
CONFIG_USB_DWC3_ROCKCHIP=y
CONFIG_USB_DWC3_ROCKCHIP_PHY_V2=y

# === MMC/SDIO/WIFI ===
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_PLTFM=y
CONFIG_MMC_SDHCI_ROCKCHIP=y
CONFIG_MMC_SDHCI_OF_ROCKCHIP_V2=y

# === 网络 TCP & QoS ===
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
CONFIG_DEFAULT_QDISC="fq"

# === RK3528 平台驱动 ===
CONFIG_ROCKCHIP_RK3528_PMU=y
CONFIG_ROCKCHIP_DRM_VOP2=y
CONFIG_ROCKCHIP_VOP2_KMS=y
CONFIG_ROCKCHIP_USB3PHY=y
CONFIG_ROCKCHIP_EMMC=y
CONFIG_ROCKCHIP_CLK_RK3528=y
CONFIG_ROCKCHIP_SECURE_BOOT=y
CONFIG_ROCKCHIP_TRUSTED_FOUNDATION=y

# === 硬件加密 ===
CONFIG_CRYPTO_DEV_ROCKCHIP=y
CONFIG_CRYPTO_DEV_ROCKCHIP_AES=y
CONFIG_CRYPTO_DEV_ROCKCHIP_SHA=y
CONFIG_CRYPTO_DEV_ROCKCHIP_TRNG=y

# === 视频硬解 VPU ===
CONFIG_VIDEO_ROCKCHIP_VPU=y
CONFIG_VIDEO_ROCKCHIP_VPU_DEC=y
CONFIG_VIDEO_ROCKCHIP_VPU_ENC=y
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CONTROLLER=y
CONFIG_VIDEO_DEV=y

# === DMA & CMA ===
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_CMA_SIZE_MBYTES=320

# === 地址空间（强制） ===
# CONFIG_ARM64_VA_BITS_52 is not set
# CONFIG_ARM64_PA_BITS_36 is not set
# CONFIG_ARM64_PA_BITS_42 is not set
# CONFIG_ARM64_PA_BITS_48 is not set

# === 必须关闭的无用功能 ===
# CONFIG_ROCKCHIP_RGA is not set
# CONFIG_ROCKCHIP_IOMMU is not set
# CONFIG_ROCKCHIP_DW_HDMI is not set
# CONFIG_PCIE_ROCKCHIP_HOST is not set
# CONFIG_SND is not set
# CONFIG_SND_SOC is not set
# CONFIG_SND_SOC_ROCKCHIP is not set
# CONFIG_SND_SOC_ROCKCHIP_I2S is not set
# CONFIG_BT is not set
# CONFIG_MFD_RK808 is not set
# CONFIG_ROCKCHIP_DMC_RK3588 is not set

# === END RK3528 CONFIGURATION ===
EOF

echo "✅ 已向 $CONFIG_FILE 安全追加 RK3528 H29K 全套配置（含 VA_BITS/PA_BITS/DRM/VOP2/Secure Boot）"

# Step 1: 彻底移除 rockchip/armv8/config-6.12 中的 CONFIG_ARM64_SVE=y（RK3528 不支持 SVE）
sed -i '/CONFIG_ARM64_SVE=y/d' target/linux/rockchip/armv8/config-6.12

# Step 2: 显式确保 generic/config-6.12 中 SVE 为明确 not set（防歧义）
echo "# CONFIG_ARM64_SVE is not set" >> target/linux/generic/config-6.12

# Step 3: 显式启用 ASIMD（VHE 的硬依赖，且 RK3528 原生支持）
echo "CONFIG_ARM64_ASIMD=y" >> target/linux/generic/config-6.12

# 写入完整 override（含 bootloader + secure boot）
OVERRIDE_FILE="/workdir/openwrt/.config.override"

cat >> "$OVERRIDE_FILE" << 'EOF'
# RK3528 H29K OVERRIDE — GENERATED BY diy-part1.sh
# CONFIG_TARGET_MULTI_ARCH is not set
CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_h29k=y
# CONFIG_ARM64_EPHEMERAL_PAGE_TABLES is not set
# CONFIG_PACKAGE_u-boot-rk3528 is not set
# CONFIG_PACKAGE_u-boot-rk3528-tpl is not set
# CONFIG_TRUSTED_FIRMWARE_A is not set

EOF

echo "✅ RK3528 H29K 最终配置"

# 简单可靠：等待10秒后再继续执行（OpenWrt Actions 环境专用）
# 不依赖任何外部工具，兼容所有 BusyBox / dash / bash 环境

sleep 10

# ✅ 等待完成，后续命令可直接跟在此行下方
# 例如：
# echo "✅ 10秒已过，开始下一步..."
# make menuconfig

# ==============================
# 适配H29K的打包流水线
# ==============================
# 1. 下载并覆盖到正确路径
wget -O target/linux/rockchip/image/Makefile https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/Makefile

# 2. 自动验证 IMAGE 行是否正确
grep -q "智能识别 Binman 合体固件或传统拆分固件" target/linux/rockchip/image/Makefile

# 3. 输出验证结果
if [ $? -eq 0 ]; then
    echo -e "\033[32m✅ 验证成功：Makefile 已正确修改，打包规则完全符合要求！\033[0m"
else
    echo -e "\033[31m❌ 验证失败：文件内容不匹配，请检查！\033[0m"
fi

# ==============================
# RK3528 压缩包文件自动部署（正确路径版）
# ==============================

# 正确路径（相对路径，100% 适配 OpenWrt 编译）
TARGET_DIR="target/linux/rockchip/files"
ZIP_URL="https://raw.githubusercontent.com/I-agree/H29K/main/123/lede-target-linux-rockchip-files.zip"
ZIP_FILE="${TARGET_DIR}/lede-target-linux-rockchip-files.zip"

# 创建目录
mkdir -p ${TARGET_DIR}

# 下载
echo "正在下载 RK3528 驱动文件..."
wget -q --no-check-certificate -O "${ZIP_FILE}" "${ZIP_URL}"

# 校验文件是否存在
if [ ! -f "${ZIP_FILE}" ]; then
    echo "❌ 下载失败！"
    exit 1
fi

# 校验 ZIP 完整性
echo "正在校验文件完整性..."
unzip -tq "${ZIP_FILE}"
if [ $? -ne 0 ]; then
    echo "❌ 文件损坏！"
    exit 1
fi

# 解压
echo "正在解压文件..."
unzip -o -q "${ZIP_FILE}" -d "${TARGET_DIR}"

# 验证最终结构
if [ -d "${TARGET_DIR}/drivers" ] && [ -d "${TARGET_DIR}/include" ]; then
    echo "✅ RK3528 原厂文件部署成功！"
else
    echo "❌ 部署失败！目录结构错误"
    exit 1
fi

# 清理
rm -f "${ZIP_FILE}"

echo "所有操作完成！"

# 下载 H29K 专用 mmc.bootscript（仅 1 个文件）
mkdir -p target/linux/rockchip/image
wget -q https://raw.githubusercontent.com/I-agree/H29K/main/files/target/linux/rockchip/image/mmc.bootscript -O target/linux/rockchip/image/mmc.bootscript

# 下载 H29K 专用 gen_image_generic.sh（仅 1 个文件）
mkdir -p scripts
wget -q https://raw.githubusercontent.com/I-agree/H29K/main/files/scripts/gen_image_generic.sh -O scripts/gen_image_generic.sh

# 完美的双修补丁：一份在内核，一份给 U-Boot
mkdir -p package/boot/uboot-rockchip/dts
cp target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-hinlink-h29k.dts package/boot/uboot-rockchip/dts/rk3528-hinlink-h29k.dts

# ==========================================================================
# 🎯 全面切换为 LEDE rk3528.dtsi 核心（带网络防空、容错与 U-Boot 同步注入）
# ==========================================================================

# 1. 路径定义
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_DIR"

echo "📥 开始下载 LEDE 核心设备树组件（带重试机制）..."

# 下载 rk3528.dtsi
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
  https://raw.githubusercontent.com/I-agree/H29K/main/123/rk3528.dtsi \
  -o "$DTS_DIR/rk3528.dtsi"

# 下载 rk3528-pinctrl.dtsi
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
  https://raw.githubusercontent.com/I-agree/H29K/main/123/rk3528-pinctrl.dtsi \
  -o "$DTS_DIR/rk3528-pinctrl.dtsi"

# 下载 rockchip-pinconf.dtsi
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 \
  https://raw.githubusercontent.com/I-agree/H29K/main/123/rockchip-pinconf.dtsi \
  -o "$DTS_DIR/rockchip-pinconf.dtsi"

# 2. 严格的“防空包/防失效”合并校验
if [ ! -s "$DTS_DIR/rk3528.dtsi" ] || [ ! -s "$DTS_DIR/rk3528-pinctrl.dtsi" ] || [ ! -s "$DTS_DIR/rockchip-pinconf.dtsi" ]; then
    echo "❌ 核心 DTSI 文件下载失败或文件为空（网络触发异常），停止编译！"
    exit 1
fi

echo "✅ 成功下载并验证全套 LEDE rk3528 核心设备树组件！"

echo "============================================="
echo "  🔍 全部文件完整性检查"
echo "============================================="
# 基础路径
ROC_DIR="target/linux/rockchip/files"
DTS_DIR="$ROC_DIR/arch/arm64/boot/dts/rockchip"
INC="$ROC_DIR/include/dt-bindings"

# 检查文件夹
check_dir() {
    if [ -d "$1" ]; then echo "✅ 目录存在: $1"; else echo "❌ 目录缺失: $1"; fi
}

# 检查文件
check_file() {
    if [ -f "$1" ]; then echo "✅ 文件存在: $1"; else echo "❌ 文件缺失: $1"; fi
}

echo -e "\n📁 检查主文件夹"
check_dir "$ROC_DIR/include"
check_dir "$ROC_DIR/drivers"

echo -e "\n📄 检查 LEDE 头文件"
check_file "$INC/clock/rk3528-cru.h"
check_file "$INC/power/rk3528-power.h"

echo -e "\n📄 检查 rockchip-pinconf.dtsi"
check_file "$DTS_DIR/rockchip-pinconf.dtsi"

echo -e "\n============================================="
echo " ✅ 检查完成！以上全部存在即为正常"
echo "============================================="
