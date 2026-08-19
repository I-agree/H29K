#!/bin/sh
# 统计当前接入的客户端设备数（有线 LAN + WiFi 关联）
# 输出一个整数；>0 表示至少有一台设备接入
n=0

# 收集 DSA master 口（内部恒连通，不算客户端）
masters=" "
for d in /sys/class/net/*; do
    t=$(readlink "$d/dsa" 2>/dev/null) || continue
    m=$(basename "$t")
    case "$masters" in *" $m "*) ;; *) masters="$masters$m ";; esac
done

wan_dev=$(uci -q get network.wan.device 2>/dev/null)

# --- 有线：carrier=1 且 非无线/非桥/非master/非WAN上联/非模块口 ---
for d in /sys/class/net/*; do
    i=${d##*/}
    case "$i" in
        lo|br-*|ppp*|tun*|tap*|wg*|vxlan*|gre*|ip6*|sit*|6in4*) continue ;;
        wwan*|rmnet*|mbim*|qmi*|usb[0-9]*|modem*) continue ;;
    esac
    [ -e "$d/wireless" ] && continue
    [ -e "$d/bridge" ] && continue
    case "$masters" in *" $i "*) continue ;; esac
    [ -n "$wan_dev" ] && [ "$i" = "$wan_dev" ] && continue
    c=$(cat "$d/carrier" 2>/dev/null) || continue
    [ "$c" = "1" ] && n=$((n+1))
done

# --- 无线：关联站点数 ---
have_iw=$(command -v iw 2>/dev/null)
for d in /sys/class/net/*; do
    i=${d##*/}
    [ -e "$d/wireless" ] || continue
    case "$i" in apcli*|wds*|mon.*) continue ;; esac
    if [ -n "$have_iw" ]; then
        c=$(iw "$i" station dump 2>/dev/null | grep -c "^Station")
    else
        c=$(iwinfo "$i" assoclist 2>/dev/null | grep -c "dBm")
    fi
    [ -n "$c" ] && n=$((n+c))
done

echo $n
