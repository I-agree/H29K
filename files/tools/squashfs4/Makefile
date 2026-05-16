#
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=squashfs4
PKG_CPE_ID:=cpe:/a:phillip_lougher:squashfs
PKG_VERSION:=4.7.4
PKG_RELEASE=2

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/plougher/squashfs-tools
PKG_SOURCE_DATE:=2025-11-10
PKG_SOURCE_VERSION:=53e5a67aac42e0bc9ad4a249156d7d549ce7436c
PKG_MIRROR_HASH:=7ce390d95af4b7b4ce768cec18aeb9ac61b8ca413d0ced2c42a81446d9dd8690

HOST_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/host-build.mk

define Host/Compile
    +$(HOST_MAKE_VARS) \
    $(MAKE) $(HOST_JOBS) -C $(HOST_BUILD_DIR)/squashfs-tools \
        LZ4_SUPPORT=0 \
        LZO_SUPPORT=0 \
        ZSTD_SUPPORT=1 \   # ← ✅ 启用 squashfs-ng 核心能力（原为 0）
        GZIP_SUPPORT=1 \
        XZ_SUPPORT=1 \
        LZMA_XZ_SUPPORT=1 \
        XZ_EXTENDED_OPTIONS=1 \
        EXTRA_CFLAGS="-I$(STAGING_DIR_HOST)/include" \
        LDFLAGS="-L$(STAGING_DIR_HOST)/lib -lzstd" \  # ← ✅ 强制链接 zstd 库（原无此行）
        mksquashfs unsquashfs
endef

define Host/Install
    $(INSTALL_BIN) $(HOST_BUILD_DIR)/squashfs-tools/mksquashfs $(STAGING_DIR_HOST)/bin/mksquashfs4
    $(INSTALL_BIN) $(HOST_BUILD_DIR)/squashfs-tools/unsquashfs $(STAGING_DIR_HOST)/bin/unsquashfs4
    # ← ✅ 新增：创建 squashfs-ng 标准化符号链接（OpenWrt 25.12 构建脚本实际调用它）
    ln -sf mksquashfs4 $(STAGING_DIR_HOST)/bin/mksquashfs-ng
    ln -sf unsquashfs4 $(STAGING_DIR_HOST)/bin/unsquashfs-ng
endef

define Host/Clean
    rm -f $(STAGING_DIR_HOST)/bin/mksquashfs4
    rm -f $(STAGING_DIR_HOST)/bin/unsquashfs4
    rm -f $(STAGING_DIR_HOST)/bin/mksquashfs-ng   # ← ✅ 清理符号链接
    rm -f $(STAGING_DIR_HOST)/bin/unsquashfs-ng
endef

$(eval $(call HostBuild))
