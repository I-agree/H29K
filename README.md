适配设备：hinlink_h29k
兼容5G模块：FM350-GL
插件汉化以及性能优化（BBR + Irqbalance）
直接使用OpenWrt官方最新稳定版源码库
含小屏幕显示的完整系统镜像

注意：我仓库直接编译出来的固件不支持从 SD 卡启动，但是你可以修改mmc.bootscript文件来改变启动方式。
当从 eMMC 启动时，${devnum} 是 0，内核收到的就是 root=/dev/mmcblk0p2（点对点直达 eMMC）。
当从 SD 卡启动时，${devnum} 是 1，内核收到的就是 root=/dev/mmcblk1p2（点对点直达 SD 卡）

📥 刷机时的简单说明
固件编译出来并解压出 .img 文件，打开刷机工具：

情况 A：如果工具底部显示 “发现一个 LOADER 设备”
操作：直接取消勾选第一行原厂 Loader。

原因：此时盒子里的暂存内存已经是初始化状态，直接勾选第二行 system（地址 0x00000000）导入你的 OpenWrt 镜像，点击“执行”即可。

情况 B：如果工具底部显示 “发现一个 MASKROM 设备”
操作：你必须保持勾选第一行原厂 Loader（路径指向 H29K-Boot-Loader.bin），同时勾选第二行写入 OpenWrt 镜像。


原因：别担心！正如前面所说，因为第一行的地址是 0xCCCCCCCC，工具只会把原厂 Loader 发送到盒子的 RAM（运行内存） 里充当临时桥梁来激活 eMMC 写入通道，绝对不会拉低写入你 eMMC 闪存的第 64 扇区。真正落地写进闪存的，只有第二行完整的 OpenWrt 镜像 。

## Credits

- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
