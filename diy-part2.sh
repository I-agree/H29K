#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# 1. 创建目标目录（如果不存在）
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/

# 2. 下载 H29K 的设备树文件 (DTS)
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
curl -fsSL https://raw.githubusercontent.com/aaaol/OpenWrt/master/Files/LEDE/HinLink_H29K/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts > target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts

# 3. 在 Makefile 中注册 H29K 设备
RK35XX_MK="target/linux/rockchip/image/rk35xx.mk"
if [ -f "$RK35XX_MK" ]; then
    cat >> "$RK35XX_MK" <<EOF

define Device/hinlink_h29k
  DEVICE_VENDOR := HinLink
  DEVICE_MODEL := H29K
  DEVICE_DTS := rk3528-opc-h29k
  DEVICE_PACKAGES := kmod-usb3 kmod-usb-dwc3-rockchip \
    kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan \
    kmod-usb-net-rtl8152 kmod-usb-net-qmi-wwan kmod-usb-net-cdc-ether \
    usbutils uqmi luci-i18n-base-zh-cn
endef
TARGET_DEVICES += hinlink_h29k
EOF
fi

# 4. 修改主机名为 H29K
sed -i 's/OpenWrt/H29K/g' package/base-files/files/bin/config_generate

# 5. 修改默认 SSID 为 H29K
sed -i 's/OpenWrt/H29K/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# 6. 设置默认时区为北京时间 (CST-8)
sed -i "s/timezone='UTC'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/timezone='CST-8'/a \ \ \ \ \ \ \ \ set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# 7. 强制默认语言为中文 (如果已经编译了中文包)
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci
