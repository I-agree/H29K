#!/bin/sh
# 统计接入客户端数。busybox ash 兼容（无 sed、无 $(cmd|cmd) 嵌套）。
#
# 你的拓扑: lan=br-lan(eth0 + phy0-ap0); eth1=WAN(2_1)。
# 关键修正:
#   1) WiFi AP 口(phy0-ap0) carrier 恒为 1，绝不能按 carrier 计入"有线"。
#      -> 有线段只数名字以 eth 开头、且不是 eth1(WAN) 的口。
#   2) 你这台无线口可能没有 wireless sysfs 软链，
#      -> 改用 ubus network.wireless 找出所有 AP 接口名再数关联站点。
# 调试: CLIENTS_DEBUG=1 /usr/sbin/clients_online.sh ; cat /tmp/.clients_debug
n=0
if [ "$CLIENTS_DEBUG" = "1" ]; then
    DBG=/tmp/.clients_debug
    echo "===== check =====" > "$DBG"
else
    DBG=/dev/null
fi

# ---------- 有线：LAN 桥成员里，只数 eth*(非 eth1) 且 carrier=1 ----------
wired=0
lan_dev=""
if command -v ubus >/dev/null 2>&1; then
    ubus call network.interface.lan status > /tmp/.lan_status 2>/dev/null
    grep -o '"device" *: *"[^"]*"' /tmp/.lan_status > /tmp/.lan_kv 2>/dev/null
    if [ ! -s /tmp/.lan_kv ]; then
        grep -o '"l3_device" *: *"[^"]*"' /tmp/.lan_status > /tmp/.lan_kv 2>/dev/null
    fi
    if [ -s /tmp/.lan_kv ]; then
        lan_dev=$(cut -d'"' -f4 /tmp/.lan_kv | head -1)
    fi
fi
echo "lan_dev=[$lan_dev]" >> "$DBG"

if [ -n "$lan_dev" ] && [ -d "/sys/class/net/$lan_dev/brif" ]; then
    ls "/sys/class/net/$lan_dev/brif" > /tmp/.br_members 2>/dev/null
else
    # 不是桥或 ubus 失败：直接扫 eth*
    ls /sys/class/net > /tmp/.br_members 2>/dev/null
fi

while read m; do
    [ -z "$m" ] && continue
    # 只认纯以太网口 eth*；排除 eth1(WAN/上联)
    case "$m" in
        eth*) ;;
        *) echo "  skip non-eth member $m" >> "$DBG"; continue ;;
    esac
    if [ "$m" = "eth1" ]; then
        echo "  skip WAN eth1" >> "$DBG"
        continue
    fi
    c=$(cat "/sys/class/net/$m/carrier" 2>/dev/null)
    echo "  wired $m carrier=[$c]" >> "$DBG"
    if [ "$c" = "1" ]; then
        wired=$((wired + 1))
    fi
done < /tmp/.br_members
n=$((n + wired))
echo "wired=$wired" >> "$DBG"

# ---------- 无线：用 ubus 找 AP 接口名，再数关联站点 ----------
wifi=0
: > /tmp/.ap_ifaces
if command -v ubus >/dev/null 2>&1; then
    ubus call network.wireless status > /tmp/.wstatus 2>/dev/null
    # 抓 "ifname" : "phy0-ap0" 这类（AP 接口）
    grep -o '"ifname" *: *"[^"]*"' /tmp/.wstatus > /tmp/.ap_ifaces 2>/dev/null
fi
# ubus 没拿到就用已知命名兜底
if [ ! -s /tmp/.ap_ifaces ]; then
    for cand in phy0-ap0 wlan0 ath0 ra0 ap0; do
        if [ -e "/sys/class/net/$cand" ]; then
            echo "\"ifname\": \"$cand\"" >> /tmp/.ap_ifaces
        fi
    done
fi

cut -d'"' -f4 /tmp/.ap_ifaces > /tmp/.ap_list 2>/dev/null
while read ap; do
    [ -z "$ap" ] && continue
    [ -e "/sys/class/net/$ap" ] || continue
    c=0
    if command -v hostapd_cli >/dev/null 2>&1; then
        hostapd_cli -i "$ap" all_sta_info > /tmp/.sta 2>/dev/null
        c=$(grep -c "^sta " /tmp/.sta)
    fi
    if [ -z "$c" ] || [ "$c" = "0" ]; then
        if command -v iw >/dev/null 2>&1; then
            iw "$ap" station dump > /tmp/.sta 2>/dev/null
            c=$(grep -c "^Station" /tmp/.sta)
        fi
    fi
    if [ -z "$c" ] || [ "$c" = "0" ]; then
        iwinfo "$ap" assoclist > /tmp/.sta 2>/dev/null
        c=$(grep -ci "dBm" /tmp/.sta)
    fi
    [ -z "$c" ] && c=0
    echo "wifi $ap sta=$c" >> "$DBG"
    wifi=$((wifi + c))
done < /tmp/.ap_list
n=$((n + wifi))
echo "wifi=$wifi" >> "$DBG"
echo "TOTAL=$n" >> "$DBG"

echo $n
