#!/bin/sh

misectel_led_init()
{
	local board

	board="$(cat /tmp/sysinfo/board_name 2>/dev/null)"
	case "$board" in
		misectel,m01k43|misectel,m01k43-usb|misectel,m01k43-usb-p|misectel,m01k43-p)
			LED_4G_POOR='yellow:4g'
			LED_4G_GOOD='blue:4g'
			LED_5G_POOR='yellow:5g'
			LED_5G_GOOD='blue:5g'
			LED_INTERNET_BLUE='blue:wan'
			LED_INTERNET_RED='red:wan'
			;;
		misectel,m02k45)
			LED_4G_POOR='4g:yellow'
			LED_4G_GOOD='4g:blue'
			LED_5G_POOR='5g:yellow'
			LED_5G_GOOD='5g:blue'
			LED_INTERNET_BLUE='sys:blue'
			LED_INTERNET_RED='sys:red'
			;;
		hinlink,h29k)
			# 单色灯：POOR 与 GOOD 指向同一物理灯
			#   弱信号 → 该灯 timer 慢闪
			#   中/强  → 该灯常亮
			#   无信号/无SIM → 不点(灭)
			LED_4G_POOR='red:4g'
			LED_4G_GOOD='red:4g'
			LED_5G_POOR='blue:5g'
			LED_5G_GOOD='blue:5g'
			LED_INTERNET_BLUE='green:work'
			LED_INTERNET_RED='green:work'
			;;
		*) return 1 ;;
	esac
}

led_turn()
{
	local path="/sys/class/leds/$1"
	local value="$2"
	local brightness

	[ -e "$path/brightness" ] || return
	[ ! -e "$path/trigger" ] || echo none > "$path/trigger" 2>/dev/null
	if [ "$value" = 1 ]; then
		brightness="$(cat "$path/max_brightness")"
	else
		brightness=0
	fi
	echo "$brightness" > "$path/brightness"
}

led_heartbeat()
{
	local path="/sys/class/leds/$1"

	[ -e "$path/brightness" ] || return
	echo "$(cat "$path/max_brightness")" > "$path/brightness"
	echo heartbeat > "$path/trigger"
}

# 慢闪：timer 触发器，1秒亮 / 1秒灭（内核自管，无后台进程）
led_slowblink()
{
	local path="/sys/class/leds/$1"

	[ -e "$path/brightness" ] || return
	echo timer > "$path/trigger"
	echo 1000 > "$path/delay_on" 2>/dev/null
	echo 1000 > "$path/delay_off" 2>/dev/null
}

led_netdev()
{
	local path="/sys/class/leds/$1"
	local device="$2"

	[ -e "$path/brightness" ] || return
	[ -n "$device" ] && [ -e "/sys/class/net/$device" ] || {
		led_heartbeat "$1"
		return
	}
	echo 1 > "$path/brightness"
	echo netdev > "$path/trigger"
	echo "$device" > "$path/device_name"
	echo 1 > "$path/link"
	echo 1 > "$path/rx"
	echo 1 > "$path/tx"
}

modem_leds_off()
{
	led_turn "$LED_4G_POOR" 0
	led_turn "$LED_4G_GOOD" 0
	led_turn "$LED_5G_POOR" 0
	led_turn "$LED_5G_GOOD" 0
}

internet_leds_off()
{
	led_turn "$LED_INTERNET_BLUE" 0
	led_turn "$LED_INTERNET_RED" 0
}

internet_led_connected()
{
	case "$(cat /tmp/sysinfo/board_name 2>/dev/null)" in
		hinlink,h29k)
			led_turn "$LED_INTERNET_BLUE" 1
			;;
		*)
			led_turn "$LED_INTERNET_RED" 0
			led_turn "$LED_INTERNET_BLUE" 1
			;;
	esac
}

internet_led_disconnected()
{
	case "$(cat /tmp/sysinfo/board_name 2>/dev/null)" in
		hinlink,h29k)
			led_turn "$LED_INTERNET_BLUE" 0
			;;
		*)
			led_turn "$LED_INTERNET_BLUE" 0
			led_turn "$LED_INTERNET_RED" 1
			;;
	esac
}
