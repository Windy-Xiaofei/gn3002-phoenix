# Phoenix · Gionee GN3002

> 一台被厂商遗弃的 MT6735 手机，重新开机计划。

厂商没了，OTA 服务器早关了，最后一版官方固件停在 Android 5.1。这台机器现在唯一的价值，
就是它是一块 4 核 A53 + 720p 屏幕 + 完整的硬件资料（我们全扒出来了）的开发板。

**当前目标：Android 8.1。** 不是 5.1 重打包，是真的从源码编译出来的 LineageOS 15.1。

---

## 状态

| 阶段 | 内容 | 状态 |
|---|---|---|
| M0 | 固件解剖、硬件档案、分区表 | ✅ 完成 |
| M1 | TWRP 可启动、能挂载全部分区 | 🚧 进行中 |
| M2 | LineageOS 15.1 首次开机（哪怕只有黑屏 + adb） | ⬜ 未开始 |
| M3 | 显示 / 触摸 / WiFi / 音频 / 相机逐个点亮 | ⬜ 未开始 |
| M4 | Android 9 试验 | ⬜ 未开始 |

主线内核（Linux 6.x）的尝试已经归档，结论写在
[GIONEE-GN3002-Mainline/docs/mainline-archive.md](https://github.com/Windy-Xiaofei/GIONEE-GN3002-Mainline/blob/main/docs/mainline-archive.md)：
MT6735 的 PSCI 是坏的，没有 UART 可以看日志，只能得到一个单核、无网、不能待机的开发板。不值得。

---

## 硬件速查

| | |
|---|---|
| SoC | MT6735，4×Cortex-A53 @1.3GHz，Mali-T720 MP2 |
| 代号 | `gbl7356`（原厂 `ro.product.device` = `GIONEE_GBL7356`） |
| 屏幕 | 720×1280，天马 `tm_ft8606`（触摸一体），320dpi |
| 内存/存储 | 2GB / 16GB eMMC，system 3GB |
| 用户空间 | 64 位（`zygote64_32`） |
| 安全 | 有 ATF + trustzone，bootloader 已解锁 |
| 相机 | 前 + 后，MTK legacy HAL1（`camera.mt6735.so`） |
| 连接 | MTK WMT WiFi/BT combo、pn54x NFC、CCCI 双卡 LTE |

关键偏移（全部来自原厂 boot.img header 实测）：

```
kernel_addr   0x40080000   → base 0x40000000 + offset 0x00080000
ramdisk_addr  0x44000000   → offset 0x04000000
tags_addr     0x4e000000   → offset 0x0e000000
page_size     2048
cmdline       bootopt=64S3,32N2,64N2
```

> `0x80000` 这个 offset 是整件事最容易翻车的地方。Android 默认给 `0x8000`，
> 而 MT6735 前面 512KB 被 LK 和 ATF 占了。写错的表现是：刷完开机黑屏、几秒后自己复位、
> 没有任何日志。别问怎么知道的。

---

## 目录说明

仓库根目录**就是** device tree，由 `manifest/phoenix.xml` 里的
`path="device/gionee/gbl7356"` 映射进源码树。所以 `BoardConfig.mk` 在顶层，
而不是 `device/gionee/gbl7356/BoardConfig.mk`。

```
.
├── BoardConfig.mk          # 分区表、内核地址、TWRP 参数
├── AndroidProducts.mk      # lunch 目标注册
├── omni_gbl7356.mk         # 产品定义（M1 TWRP 用）
├── twrp.fstab              # 分区挂载表
├── prebuilt/Image.gz-dtb   # 原厂内核（3.10.65 + DTB），6.9MB
├── manifest/phoenix.xml    # local manifest
└── .github/workflows/      # 云端构建
```

---

## 编译

### 方式一：GitHub Actions（推荐）

推一个 commit 就自动编，产物在 Actions 页面的 Artifacts 里。不用装 100GB 的工具链。

```
Actions → TWRP → Run workflow
```

### 方式二：本地

需要 200GB 空闲磁盘、16GB 内存、Linux（WSL2 也行但慢）。

```bash
mkdir -p ~/phoenix && cd ~/phoenix

# TWRP 8.1 最小源码树
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git \
          -b twrp-8.1 --depth=1
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags

# 放设备树
git clone https://github.com/Windy-Xiaofei/gn3002-phoenix.git device/gionee/gbl7356

source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch omni_gbl7356-eng
mka recoveryimage
```

产物：`out/target/product/gbl7356/recovery.img`

---

## 刷入

```bash
adb reboot bootloader          # 或者关机后按住音量下 + 电源
fastboot flash recovery recovery.img
fastboot reboot recovery
```

刷之前**务必**先在现有 TWRP 或 SP Flash Tool 的 readback 里备份
`nvram`、`nvdata`、`protect1`、`protect2` —— 这四个分区丢了，IMEI 就没了。

救援手段：SP Flash Tool + 原厂固件包（`gionee-gn3002_SV1.0_5.1_2017.10.11`），
走 Download Only 模式，只勾 preloader 以外的分区。**永远不要刷 preloader 和 lk**，那是唯一的救砖通道。

---

## 警告

这是一个自用项目，不是发行版。没有 OTA，没有签名，没有质量保证。
你的机器可能变砖，虽然目前每次都能救回来。

刷机前请确认你手上有原厂固件包和一根能用的数据线。

---

## 致谢

- [Coolpad mt6735-common](https://github.com/coolpadnote3litedevelopment/android_device_coolpad_mt6735-common) — MT6735 设备树的事实标准，本项目的 BoardConfig 大量参考
- TWRP minimal manifest
- 以及那台 2016 年出厂、至今还在服役的 GN3002
