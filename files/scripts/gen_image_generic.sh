#!/bin/sh
# Copyright (C) 2006-2012 OpenWrt.org
set -e
if [ $# -ne 5 ] && [ $# -ne 6 ]; then
    echo "SYNTAX: $0 <file> <kernel size> <kernel directory> <rootfs size> <rootfs image> [<align>]"
    exit 1
fi

OUTPUT="$1"
KERNELSIZE="$2"
KERNELDIR="$3"
ROOTFSSIZE="$4"
ROOTFSIMAGE="$5"
ALIGN="$6"

rm -f "$OUTPUT"

head=16
sect=63

# create partition table
# 🛠️ 核心修复：GPT 模式下使用绝对偏移 @32m，不再使用 -l 产生恶心的 BIOS Boot 伪分区
if [ -n "$GUID" ]; then
    set $(ptgen -o "$OUTPUT" -h $head -s $sect -g -p "${KERNELSIZE}m@32m" -p "${ROOTFSSIZE}m" ${SIGNATURE:+-S 0x$SIGNATURE} -G "$GUID")
else
    set $(ptgen -o "$OUTPUT" -h $head -s $sect -p "${KERNELSIZE}m" -p "${ROOTFSSIZE}m" ${ALIGN:+-l $ALIGN} ${SIGNATURE:+-S 0x$SIGNATURE})
fi

KERNELOFFSET="$(($1 / 512))"
KERNELSIZE="$2"
ROOTFSOFFSET="$(($3 / 512))"
ROOTFSSIZE="$4"

# Using mcopy -s ... is using READDIR(3) to iterate through the directory
# entries, hence they end up in the FAT filesystem in traversal order which
# breaks reproducibility.
# Implement recursive copy with reproducible order.
dos_dircopy() {
  local entry
  local baseentry
  for entry in "$1"/* ; do
    if [ -f "$entry" ]; then
      mcopy -i "$OUTPUT.kernel" "$entry" ::"$2"
    elif [ -d "$entry" ]; then
      baseentry="$(basename "$entry")"
      mmd -i "$OUTPUT.kernel" ::"$2""$baseentry"
      dos_dircopy "$entry" "$2""$baseentry"/
    fi
  done
}

[ -n "$PADDING" ] && dd if=/dev/zero of="$OUTPUT" bs=512 seek="$ROOTFSOFFSET" conv=notrunc count="$ROOTFSSIZE"
dd if="$ROOTFSIMAGE" of="$OUTPUT" bs=512 seek="$ROOTFSOFFSET" conv=notrunc

if [ -n "$GUID" ]; then
    # 🛠️ 核心修复：彻底删除了原本会将 Backup GPT 清零的 dd 毁灭命令，誓死保卫末尾的 GPT 备份表！
    mkfs.fat --invariant -F 32 -n kernel -C "$OUTPUT.kernel" -S 512 "$((KERNELSIZE / 1024))"
    LC_ALL=C dos_dircopy "$KERNELDIR" /
else
    make_ext4fs -J -L kernel -l "$KERNELSIZE" ${SOURCE_DATE_EPOCH:+-T ${SOURCE_DATE_EPOCH}} "$OUTPUT.kernel" "$KERNELDIR"
fi
dd if="$OUTPUT.kernel" of="$OUTPUT" bs=512 seek="$KERNELOFFSET" conv=notrunc
rm -f "$OUTPUT.kernel"
