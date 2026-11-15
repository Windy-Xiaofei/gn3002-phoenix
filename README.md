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
| M1 | TWRP 可启动、能挂载全部分区 | 🟡 CI 已产出镜像（15.5MB，装得进 16MB 分区），**待真机验证** |
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

## 下载

首个可刷镜像：**[twrp-0.1](https://github.com/Windy-Xiaofei/gn3002-phoenix/releases/tag/twrp-0.1)**

```
twrp-gbl7356.img   15,542,272 B
sha256  c6651b382b0dbc12a44d2b3a69c3c46c45655b66621465268b35d2a8e0a8e68d
```

CI（[Actions](https://github.com/Windy-Xiaofei/gn3002-phoenix/actions)）每次推送 `.mk` / workflow 会自动构建，
产物在 Artifacts（保留 30 天），发版时同步传到 Releases（长期保留）。

镜像 header 已用脚本校验，与原厂 boot.img 实测值完全一致：

```
kernel_addr 0x40080000   ramdisk_addr 0x44000000
tags_addr   0x4e000000   page_size 2048
```

> 内核用的是原厂 `Image.gz-dtb`，**一个字节都没改**。为了压进 16MB 分区，
> 只裁掉了 TWRP 的可选组件（python3 及标准库、bash、tzdata、多语言包等），
> 刷机、备份、挂载、adb、MTP 能力都在。

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

### 方式一：fastboot flash（推荐，不需要 root）

关机后按物理键组合进 fastboot（这台机 `adb reboot recovery` 不可靠，
`adb reboot bootloader` 又需要 USB 调试授权）。进去后：

```bash
fastboot devices                       # 应看到 BM...  fastboot
fastboot getvar unlocked                # 应为 yes
fastboot flash recovery twrp-gbl7356.img
```

实测成功（2026-11-15）：

```
Sending 'recovery' (15178 KB)   OKAY [  1.452s]
Writing  'recovery'             OKAY [  0.354s]
```

> 之前记录的「LK 误报低电量导致 fastboot 不能用」只发生在 **`fastboot boot`**
> （把镜像加载到内存里启动，走 download 路径，会报
> `low power, need battery charging`，即使电池 98%）。
> **`fastboot flash` 不受影响**，且 `getvar all` 能正常返回。
> bootloader 已解锁（`unlocked: yes` / `secure: no`），所以也不需要 root。

### 方式二：adb + dd（需要 root）

原厂 5.1 默认没 root，所以这条路在刚刷完原厂包时**用不了**。
但在 TWRP 里 adbd 本身就是 root，或者系统已 root 时可用：

```bash
adb start-server
adb devices                      # 确认 online 且 shell 是 uid=0
adb push twrp-gbl7356.img /sdcard/twrp.img
adb shell 'dd if=/sdcard/twrp.img of=/dev/block/platform/mtk-msdc.0/by-name/recovery bs=1048576'
adb shell 'sync; md5sum /dev/block/platform/mtk-msdc.0/by-name/recovery'
```

`by-name/recovery` 对应 `mmcblk0p8`（16MB），`by-name/boot` 是 `mmcblk0p7`。
**写错分区就会变砖**，dd 之前先用
`adb shell ls -l /dev/block/platform/mtk-msdc.0/by-name/` 确认。

### 备份 IMEI 分区

刷 recovery 不会动到这几个分区，但**开始刷 system 之前务必**备份
`nvram`、`nvdata`、`protect1`、`protect2` —— 丢了 IMEI 就没了。
原厂系统没 root 时读不了块设备，最方便的是刷好 TWRP 后在 TWRP 里做：

```bash
adb shell 'dd if=/dev/block/platform/mtk-msdc.0/by-name/nvram of=/sdcard/nvram.img'
adb shell 'dd if=/dev/block/platform/mtk-msdc.0/by-name/nvdata of=/sdcard/nvdata.img'
adb pull /sdcard/nvram.img /sdcard/nvdata.img ./
```

或者用 SP Flash Tool 的 Readback 功能。

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
