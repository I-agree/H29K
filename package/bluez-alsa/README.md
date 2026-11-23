# bluez-alsa（H29K 用）

给蓝牙音频补一个 ALSA 后端。装它不是因为插件缺东西，而是因为 **BlueZ 自己不发声**。

## 为什么必须有它

BlueZ 只做蓝牙协议栈：配对、建链、协商 A2DP 能力。真正的音频流要走 BlueZ 的 Media API
拿到传输 FD，再由某个进程持续写 PCM 进去。没有这个"消费者"时：

1. 耳机连上，A2DP 配置完成；
2. 但没有任何进程去开流（Start Stream 之后没人读 FD）；
3. 耳机侧收不到数据，几秒到几十秒内主动断开；
4. 不少耳机（TWS/颈挂）断开时顺手把自己那边的配对信息也删掉，于是重新扫描显示
   "未配对 · 受信任"——这正是之前面板里看到的两个状态。

`bluealsad` 就是那个消费者：它向 BlueZ 注册 A2DP **source** 端点，并把流暴露成
ALSA PCM `bluealsa`（定义在 `/etc/alsa/conf.d/20-bluealsa.conf`，OpenWrt 的 alsa-lib
只加载这个目录；`/usr/share/alsa/alsa.conf.d` 是 Debian 的补丁路径，这里不生效）。

## 和固定 MAC 无关

ALSA 设备 `bluealsa` 的 `DEV` 默认是 `00:00:00:00:00:00`，官方语义是
**"当前最近连接的那台 A2DP 设备"**。所以：

- 换耳机不用改任何配置，新连上的那台自动成为目标；
- 同时连两台时，发给最后连上的那台；
- 流的归属性在 **PCM 打开时** 决定。中途换设备不会把已经开着的流迁过去，
  下一段音频（gmediarender 每首歌重新协商 sink）就会走新设备。

需要强制指定某台时再写完整设备串，例如
`bluealsa:DEV=54:A4:93:50:86:1B,PROFILE=a2dp`。

## DLNA 推流怎么接

gmediarender 走 GStreamer alsasink，把输出设备改成 `bluealsa` 即可：

```
option audiosink 'alsasink'
option audiodevice 'bluealsa'
```

改完 `/etc/init.d/gmediarender restart`。想看 HDMI 时把 `audiodevice` 改回
`plughw:0,0`（本机 card0 = rockchiphdmi）。

## 配置与常用命令

```
uci show bluealsa                  # 配置：enabled / profiles / loglevel / syslog / extra_args
/etc/init.d/bluealsa restart
logread -f | grep -i bluealsa      # 看端点注册、编解码协商、流开关
bluealsactl list-pcms              # 当前有哪些 PCM（连上设备后才有）
aplay -D bluealsa /tmp/test.wav    # 直接推一段音频验证链路
```

D-Bus 策略装在 `/etc/dbus-1/system.d/org.bluealsa.conf`（OpenWrt 的 dbus 读这里，
不是上游默认的 `/usr/share`）；缺了它 `bluealsad` 起不来，日志里会是
"Failed to register org.bluealsa"。

只编了 **A2DP source + SBC**（SBC 是 A2DP 强制编码）。AAC/aptX/LDAC 需要额外库，
HFP/HSP 需要 oFono，本机用不到，全部关掉，固件体积和内存都省。

## 排查

- `bluealsad` 没起来：`ps | grep bluealsad`；启动日志在 `logread -t bluealsa`。
- 起来了但 `bluealsactl list-pcms` 空：说明设备没连上，或对端还在用旧的能力缓存，
  删掉配对重配一次。
- 播放有声但断续：A2DP 是 2.4G 共享带宽，和 WiFi 抢；把 WiFi 切 5G 或换信道。
- 只连不用（长时间闲置）：部分耳机在没有活动流时会自己断，这是对端策略，
  `option profiles 'a2dp-source'` 下无法阻止；DLNA 真正在放的时候流是开着的，不受影响。
