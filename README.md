# Phoenix · Gionee GN3002

> 一台被厂商遗弃的 MT6735 手机，重新开机计划。

厂商没了，OTA 服务器早关了，最后一版官方固件停在 Android 5.1（2017-10-11）。
这台机器现在唯一的价值，就是它是一块 4 核 A53 + 720p 屏 + 硬件资料被扒干净的开发板。

**目标：Android 8.1（LineageOS 15.1），从源码编译，不是 5.1 重打包。**

---

## 状态

| 阶段 | 内容 | 状态 |
|---|---|---|
| M0 | 固件解剖、分区表、硬件档案 | ✅ 完成 |
| M1 | TWRP 可启动、中文界面、能读 TF 卡 | ✅ 可用（13.9 MB，装进 16 MB 分区） |
| M2a | LineageOS 15.1 编译出包 | ✅ `system.img` 3.0 GB(raw)，能刷进机器 |
| M2b | **首次开机** | ❌ **卡在第一屏**，见下 |
| M3 | 显示 / 触摸 / WiFi / 音频 / 相机 | ⬜ 未开始 |
| M4 | Android 9 | ⬜ 未开始 |

### 当前卡点：`/system` 从未挂载

`/proc/last_kmsg` 里的确切症状：

```
init: [libfs_mgr]fs_mgr_read_fstab_dt(): failed to read fstab from dt
init: /recovery not specified in fstab
init: Couldn't load property file: /system/etc/prop.default: No such file
init: do_start: Service logd not found
```

Android 8 的第一阶段挂载（`FirstStageMount`）**只从设备树的 `/firmware/android/fstab`
节点读挂载表**。我们的 DTB 里没有这个节点，于是它认为「没有要挂的东西」直接返回，
ramdisk 里的 `/fstab.mt6735` 一次都没被用过；`/system` 挂不上，
`logd` / `servicemanager` / `vold` 的 rc 全在 `/system/etc/init` 里 → 全部 not found → 卡死。

修复在 [`ci/patch-first-stage.py`](ci/patch-first-stage.py)，**尚未在真机验证**。

---

## 硬件

| | |
|---|---|
| SoC | MT6735，4×Cortex-A53 @1.3GHz，Mali-T720 MP2 |
| 代号 | `gbl7356`（原厂 `ro.product.device` = `GIONEE_GBL7356`） |
| 屏幕 | 720×1280，天马 `tm_ft8606`（触摸一体），320dpi，**BGR 排列** |
| 内存/存储 | 2 GB / 16 GB eMMC，system 3 GB |
| 用户空间 | 64 位（`zygote64_32`） |
| 内核 | 3.10.65，arm64，原厂 `Image.gz-dtb`，**不改** |
| 安全 | ATF + trustzone，bootloader 已解锁 |
| 相机 | 前 + 后，MTK legacy HAL1（`camera.mt6735.so`） |
| 连接 | MTK WMT WiFi/BT combo、pn54x NFC、CCCI 双卡 LTE |

### 内核加载地址（全部来自原厂 boot.img header 实测）

```
kernel_addr   0x40080000   → base 0x40000000 + offset 0x00080000
ramdisk_addr  0x44000000   → offset 0x04000000
tags_addr     0x4e000000   → offset 0x0e000000
page_size     2048
```

> `0x80000` 这个 offset 是最容易翻车的地方。Android 默认给 `0x8000`，
> 而 MT6735 前面 512 KB 被 LK 和 ATF 占了。写错的表现：刷完开机黑屏、几秒后自己复位、
> 没有任何日志。

---

## 目录

仓库根目录**就是** device tree，由 `manifest/phoenix.xml` 的
`path="device/gionee/gbl7356"` 映射进源码树。所以 `BoardConfig.mk` 在顶层。

```
.
├── BoardConfig.mk           板级配置（注释密度很高，每个坑都写在里面）
├── device.mk                包、文件拷贝、HAL 变量
├── lineage.mk               产品定义（必须叫这个名字，见下）
├── AndroidProducts.mk       lunch 目标注册
├── omni_gbl7356.mk          M1 TWRP 的产品定义
├── twrp.fstab               TWRP 分区挂载表
├── ci/                      ★ 三个构建期源码补丁（见「三个补丁」）
├── blobs/                   233 个原厂闭源文件（86 MB）
├── rootdir/                 init.mt6735.rc / ueventd.mt6735.rc / fstab.mt6735
├── configs/                 audio_policy / media_codecs / thermal
├── prebuilt/Image.gz-dtb    原厂内核，6,928,802 字节，一个字节没改
├── manifest/phoenix.xml     local manifest
├── tools/ci-patch-tree.sh   TWRP 构建时的源码级瘦身
└── .github/workflows/       build-lineage.yml / build-twrp.yml
```

---

## 硬约束

| 项 | 值 | 影响 |
|---|---|---|
| 内核 | 原厂 3.10.65，不改 | 只有 `Image.gz-dtb`，没源码树；所有内核限制都用源码补丁绕过 |
| boot / recovery 分区 | 各 16 MB | boot 7.8 MB、recovery 13.9 MB |
| system 分区 | 3 GB | raw 3.0 GB，**没有余量** |
| userdata | 1.5 GB | 装不下 3 GB 卡刷包，只能 fastboot / SPFT / TWRP 刷镜像 |
| vendor 分区 | 无 | 非 Treble，`TARGET_COPY_OUT_VENDOR=system/vendor` |
| SELinux | 内核只支持策略 **15–29** | 8.1 默认 v30，必须 `POLICYVERS := 29` + libsepol 补丁 |
| 内核 DTB | 无 `/firmware/android/fstab` | 第一阶段挂载会跳过，必须打补丁 |
| 内核 | 无 devtmpfs、无 `mmap_rnd_bits` | `/dev` 靠 ueventd 建；init 硬化检查会 panic |

---

## 编译

### GitHub Actions（推荐）

```bash
# 全量（约 1 小时）
gh workflow run "LineageOS 15.1" -R Windy-Xiaofei/gn3002-phoenix --ref main

# 只打 boot.img（约 10 分钟，调 ramdisk / cmdline 时用）
gh workflow run "LineageOS 15.1" -R Windy-Xiaofei/gn3002-phoenix --ref main -f target=bootimage

# 取产物
gh run download <run-id> -R Windy-Xiaofei/gn3002-phoenix -n lineage-gbl7356-<n> -D out/boot
```

推送这些路径会自动触发：`device.mk`、`lineage.mk`、`AndroidProducts.mk`、
`BoardConfig.mk`、`blobs/**`、`rootdir/**`、`configs/**`、`overlay/**`、`sepolicy/**`、
本工作流文件。`concurrency` 是 `cancel-in-progress`，**推送会取消正在跑的那一轮**。

### 本地

需要 Ubuntu 20.04/22.04、≥120 GB 磁盘、≥16 GB 内存、JDK 8、python2.7。

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-15.1 --depth=1
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags

# 三个补丁（顺序无所谓，必须在编译前）
python3 ci/patch-libsepol.py     external/selinux/libsepol/src/write.c
python3 ci/patch-init.py         system/core/init/init.cpp
python3 ci/patch-first-stage.py  system/core/init/init_first_stage.cpp

mkdir -p device/gionee/gbl7356
rsync -a --exclude=.git ./ device/gionee/gbl7356/

sudo ln -sf "$(command -v python2.7)" /usr/local/bin/python   # 8.1 脚本是 py2 语法
source build/envsetup.sh
lunch lineage_gbl7356-userdebug
mka bootimage -j$(nproc)
```

TWRP（M1）走另一套 manifest：

```bash
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git \
          -b twrp-8.1 --depth=1
lunch omni_gbl7356-eng
mka recoveryimage
```

---

## 三个补丁

工作流在 `repo sync` 之后、编译之前执行。为什么需要它们，逐条写在 `BoardConfig.mk` 的注释里。

### `ci/patch-libsepol.py`

内核只认 SELinux 策略 15–29，8.1 默认 30。改成 `POLICYVERS := 29` 后
`checkpolicy` 会拒绝写出，因为 8.1 策略用了 `ioctl` 扩展权限（v30 特性）：

```
libsepol.avtab_write_item: policy version 29 does not support ioctl extendedpermissions rules
```

补丁在写策略前把这些节点从 avtab 哈希桶摘掉并 `a->nel--`（不能简单 `return`，
计数会错）。内核本来不支持这些规则，丢掉后策略依然自洽。

### `ci/patch-init.py`

3.10 没有 `/proc/sys/vm/mmap_rnd_bits`（Linux 4.1 才有），8.1 的
`set_mmap_rnd_bits_action()` 写失败就 `security_failure()` → 重启进 bootloader。
`set_kptr_restrict_action()` 同理。补丁把这两处降级成 `LOG(WARNING)`。

### `ci/patch-first-stage.py`

`FirstStageMount` 只从设备树读挂载表。补丁在 DT 缺失时回落到固定路径
`/fstab.mt6735`、`/vendor/etc/fstab.mt6735`，并且**只把 `/system`、`/vendor`
放进挂载队列**。

> 两个坑：① 不能用 `fs_mgr_read_fstab_default()`，它依赖 `ro.hardware`，
> 而 `FirstStageMount` 构造时属性区还没初始化（`DoFirstStageMount()` 在 main 第 47 行，
> `property_init()` 在第 92 行），路径会拼成 `/fstab.`；
> ② 队列里每一条都会被 `fs_mgr_do_mount_one()`，任何一条失败就让 init panic，
> 所以 `/data`、`/cache` 这些不能放进去。

---

## 刷入

产物：`boot.img`（7.8 MB）、`recovery.img`（13.9 MB）、`system.img`（3.0 GB raw）。

### fastboot（改 boot 时最快）

```bash
fastboot devices
fastboot flash boot boot.img
fastboot reboot
```

成功失败都会明确报出来，比 SP Flash Tool 的静默失败好定位。

### SP Flash Tool（整包）

关机 → 加载 scatter（只勾 boot / recovery / system）→ **Download Only** →
Start → **然后才插线**。

> **永远不要刷 preloader、lk、nvram、protect1/2**。sparse 格式的 `system.img`
> SPFT 不认，必须先转 raw。

### TWRP（只有 TF 卡时）

TWRP → 安装 → **安装镜像** → 选 `system.img` → 目标 **System Image**；
再选 `boot.img` → 目标 **Boot**。最后 **格式化 Data**（不是「清除 Data」，
后者是文件级删除，5.1 的加密分区挂不上就必然失败）。

### 一个历史坑：原厂恢复自恢复

原厂 `init.rc` 里有 `service flash_recovery /system/bin/install-recovery.sh`，
每次正常开机都会校验 recovery 分区 SHA1，不是原厂就用 `boot` +
`/system/recovery-from-boot.p` 把原厂 recovery 写回去。
所以在只刷 recovery、没刷 system 的阶段，「刷成功、进系统后又被还原」是这个机制。
刷了 8.1 的 system.img 之后这些脚本就不存在了。

---

## 已知问题

| 问题 | 状态 |
|---|---|
| `/system` 不挂载 | 补丁已写，待验证 |
| TWRP 在 SELinux enforcing 下权限不足（不能格式化 /data） | 未解决。原厂 5.1 的 init 是 user 版，`write /sys/fs/selinux/enforce 0` 被策略拒 |
| 电池 / 温度读数不准 | 未解决，低优先级。诊断钩子已在 `sbin/sysprobe.sh` |
| `sdcardfs` / `memfd_create` 缺失 | 未验证，可能要动内核 |
| camera1 → camera3、RIL v6 → v11 | 未开始 |

---

## 警告

自用项目，不是发行版。没有 OTA，没有签名，没有质量保证。
你的机器可能变砖，虽然目前每次都能救回来。

刷机前请确认手上有原厂固件包和一根能用的数据线。

---

## 致谢

- [Coolpad mt6735-common](https://github.com/coolpadnote3litedevelopment/android_device_coolpad_mt6735-common)
  — MT6735 设备树的事实标准，本项目的 BoardConfig 大量参考
- TWRP minimal manifest
- 以及那台 2016 年出厂、至今还在服役的 GN3002

## License

Apache-2.0，见 [LICENSE](LICENSE)。
`blobs/` 下的闭源二进制来自原厂固件，版权归各自权利人，仅用于让这台机器重新开机。
