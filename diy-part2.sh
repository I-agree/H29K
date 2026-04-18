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

#!/bin/bash

# 1. 创建目标目录（如果不存在）
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/

# 2. 下载你的 dts 文件到指定位置
# 注意：这里使用 raw 链接直接下载
curl -fsSL https://raw.githubusercontent.com/aaaol/OpenWrt/master/Files/LEDE/HinLink_H29K/target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts \
    -o target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3528-opc-h29k.dts

# 3. 修正 Makefile 以便内核识别新设备 (非常重要)
# 这一步将设备型号加入到 rockchip 平台的内核编译列表中
sed -i '/rk3528/a \ \ \ \ \ \ \ \ rk3528-opc-h29k.dtb \\' target/linux/rockchip/image/arm64.mk

