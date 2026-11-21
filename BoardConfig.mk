#
# Copyright (C) 2026 The gn3002-phoenix Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

DEVICE_PATH := device/gionee/gbl7356

# ------------------------------------------------------------------------------
# 目标校验
#
# 刷入风险很高（boot/recovery 都只有 16MB，写坏就进 fastboot 抢救），
# 所以把这三个名字都放进来，刷错包时 OTA 脚本会直接中止而不是硬写。
# ------------------------------------------------------------------------------
TARGET_OTA_ASSERT_DEVICE := gbl7356,GIONEE_GBL7356,GN3002

# ------------------------------------------------------------------------------
# 架构
#
# 原厂是 64 位用户空间（ro.zygote=zygote64_32），lib/ 和 lib64/ 并存。
# 所以这里必须开 64 位 binder，否则 32 位 zygote 起不来。
# ------------------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_IS_64_BIT := true
TARGET_USES_64_BIT_BINDER := true
TARGET_SUPPORTS_64_BIT_APPS := true

# ------------------------------------------------------------------------------
# 内核
#
# 以下地址全部来自原厂 boot.img 的 header（实测，非推测）：
#   magic ANDROID! / page_size 2048
#   kernel_addr  0x40080000  -> base 0x40000000, offset 0x00080000
#   ramdisk_addr 0x44000000  -> offset 0x04000000
#   tags_addr    0x4e000000  -> offset 0x0e000000
#
# 注意 kernel offset 是 0x80000（512KB），不是 Android 默认的 0x8000（32KB）。
# MT6735 的前 512KB 被 LK / ATF 用掉了，写错这个值内核会解压到错误地址，
# 表现就是开机直接复位、无任何日志。
# ------------------------------------------------------------------------------
# loglevel=4：只把 KERN_WARNING 及以上送进 console/ram_console。
# 3.10 的 ram_console 只有 64 KB，用 ignore_loglevel 把所有级别都打出来时
# 3 秒就绕回一圈，早期的日志全被后半段的噪声冲掉，拉 last_kmsg 只剩结果
# 看不到原因。只留 warning/error，关键几行才能保留。
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6735 androidboot.selinux=permissive loglevel=4
# androidboot.hardware=mt6735：
#   7.1 的 init 会从 /proc/cpuinfo 里读 Hardware 字段猜硬件名
#   （system/core/init/util.cpp 的 get_hardware_name），原厂 5.1 的内核
#   已经把 Hardware 写成 mt6735，所以严格说这一项不是必需的。
#   但显式给上更稳：命令行优先于 cpuinfo，也省得将来换了内核或改了
#   cmdline 就莫名其妙找不到 init.mt6735.rc。
# androidboot.selinux=permissive：设备树里还没有 sepolicy，先用宽容模式
# 拿到开机日志，等系统能起来了再逐条收紧。
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_PAGESIZE := 2048

# 重要：TeamWin 的 android_build(android-8.1) 不认 BOARD_KERNEL_OFFSET /
# BOARD_RAMDISK_OFFSET / BOARD_TAGS_OFFSET（Makefile 里根本没有这些变量），
# 只认 BOARD_MKBOOTIMG_ARGS。不设这一行，mkbootimg 会用默认 offset
# （kernel 0x8000 / ramdisk 0x1000000 / tags 0x100），镜像能打包但永远开不了机。
# 这里全部是相对 base 的偏移，与上面 header 实测一致。
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00080000 --ramdisk_offset 0x04000000 --tags_offset 0x0e000000

# 原厂内核（Linux 3.10.65）Image.gz 后紧跟 DTB，header 的 dt_size 为 0。
# 直接用整块 Image.gz-dtb 作为预编译内核，不重新打包 DTB。
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
BOARD_INCLUDE_DTB_IN_BOOTIMG := false

# ------------------------------------------------------------------------------
# 分区
#
# 大小按 scatter 表：boot/recovery 各 16MB，system 3GB，cache 400MB，
# userdata 1.5GB。block size 0x20000 = 131072。
# ------------------------------------------------------------------------------
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 16777216
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3221225472
BOARD_CACHEIMAGE_PARTITION_SIZE := 419430400
BOARD_USERDATAIMAGE_PARTITION_SIZE := 1610612736
BOARD_FLASH_BLOCK_SIZE := 131072

BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_USERIMAGES_USE_EXT4 := true
# 注意：不要设 TARGET_USERIMAGES_USE_F2FS。recovery 的 Android.mk 看到它就会
# 往 ramdisk 塞 mkfs.f2fs + fsck.f2fs（约 1.2MB）。本机 data/system 都是 ext4。
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

TARGET_COPY_OUT_VENDOR := system/vendor
BOARD_USES_MTK_HARDWARE := true

# ------------------------------------------------------------------------------
# Recovery / TWRP
# ------------------------------------------------------------------------------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/twrp.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "ABGR_8888"
TARGET_SCREEN_HEIGHT := 1280
TARGET_SCREEN_WIDTH := 720

TW_THEME := portrait_hdpi
TW_DEVICE_VERSION := gn3002-phoenix
# TeamWin 分支的 twres/languages/ 里没有 zh_CN.xml（只有 en + 欧洲语言），
# 设 zh_CN 只会 fallback 到内置英文。CI 的 strip 步骤会删掉整个 languages/，
# 所以这里明确设 en，避免误导。
TW_DEFAULT_LANGUAGE := en

# ---- 体积控制 --------------------------------------------------------------
# recovery 分区只有 16MB，实测原配置打出来的镜像是 20.7MB，装不进去：
#   total=21688320  maxsize=17031168
# 内核（原厂 Image.gz-dtb 6.9MB）动不了，只能压 ramdisk。
# 下面每一项都是可选的锦上添花，砍掉不影响刷机能力。
TW_EXTRA_LANGUAGES := false       # 全套语言包，最大的一笔（约 2MB）
TW_EXCLUDE_TZDATA := true         # 2.5MB；代价是 TWRP 里时间显示 UTC
TW_EXCLUDE_TWRPAPP := true        # 刷完提示安装 TWRP App，1MB
TW_EXCLUDE_NANO := true
TW_EXCLUDE_BASH := true           # TWRP 自己用 mksh，bash 只是附带
TW_EXCLUDE_LPDUMP := true
TW_EXCLUDE_PYTHON := true         # python3 二进制 3.7MB + 标准库约 2.5MB，
                                  # 是 ramdisk 里最大的单项（TeamWin 9.0 分支
                                  # 的 recovery 默认会塞进 python3_twrp）
TW_EXCLUDE_DEFAULT_USB_INIT := true
# 注意：不要设 TW_INCLUDE_JPEG := false。
# libminuitwrp 在 Android.mk 里静态依赖 libjpeg，把模块排除掉会让 ninja
# 直接报 "libjpeg_intermediates/export_includes missing and no known rule"，
# 连依赖图都建不起来。想省这几百 KB 得改 TWRP 源码，不值。

TW_INCLUDE_CRYPTO := false
TW_INCLUDE_NTFS_3G := false
TW_EXCLUDE_SUPERSU := true
TW_USE_TOOLBOX := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_HAS_EDL_MODE := true
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 140
TW_CUSTOM_BATTERY_PATH := /sys/class/power_supply/battery
TW_CUSTOM_CPU_TEMP_PATH := /sys/class/thermal/thermal_zone1/temp

# 触摸是汇顶 FT8606，走 input 子系统的 vm 设备，不需要在 TWRP 里屏蔽。
# 原厂 persist.sys.usb.config 是 mass_storage，recovery 里默认用 adb 更方便调试。
TW_INCLUDE_CRYPTO_FBE := false
RECOVERY_SDCARD_ON_DATA := true

# ------------------------------------------------------------------------------
# SELinux
#
# 编译期先不启用设备自己的 policy 目录，等 M2 起系统时再按 denial 逐条补。
# ------------------------------------------------------------------------------
# BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy


# ==============================================================================
# LineageOS 14.1 专属配置
#
# 这一段只被 lineage_gbl7356 产品读取，对 TWRP（omni_gbl7356）构建无影响：
# 上面 TWRP 用不到的变量，7.1 的 build 系统会直接忽略。
# ==============================================================================

# 本机 scatter 里没有 vendor 分区，只能走非 Treble：
# 厂商内容全部落在 /system/vendor，不生成 vendor.img。
# （7.1 时代这个概念还没正式化，就是普通的 system/vendor 目录。）
BOARD_USES_VENDORIMAGE := false
# TARGET_COPY_OUT_VENDOR 已在上面（TWRP 段）声明为 system/vendor，此处不重复赋值。

# 7.1 的 init 直接从 ramdisk 起，**不需要** 8.1 那套
# "ramdisk init → 挂载 system → switch_root" 的两阶段流程。
# /system 由 init.rc 里的 mount_all 挂载。
BOARD_ROOT_EXTRA_FOLDERS := \
    oemkeystore

# 内核用原厂预编译 Image.gz-dtb，**一个字节都不改**。
# 这是 14.1 相对 15.1 最大的优势：8.1 需要 hwbinder/vndbinder 三域、
# 需要 FirstStageMount 的 DT fstab、需要 SELinux 降到 v29、需要绕过
# init 的 mmap_rnd_bits 硬化——这些在 7.1 上全都不存在。
# 详见 docs/DEBUG-LOG.md 的 B13 / B14。
TARGET_KERNEL_ARCH := arm64

# ==============================================================================
# Java 编译：7.1 必须用 Jack
# ==============================================================================
# 这一点和 8.1 相反，别搞混：
#
#   8.1：Jack 已被废弃，官方路线是 javac + dx。
#        所以那边设 ANDROID_COMPILE_WITH_JACK := false，让 setup-jack-server
#        从依赖图里消失。
#
#   7.1：Jack 还是主线。build/core/java.mk 里，生成
#        $(intermediates)/with-local/classes.dex 的规则**只在 Jack 分支**：
#           第 729 行  $(built_dex_intermediate): $(jack_all_deps) | setup-jack-server
#        而 ifndef LOCAL_JACK_ENABLED 那段（第 463~619 行）只设置了
#        PRIVATE_INTERMEDIATES_DIR / PRIVATE_DX_FLAGS，**没有任何生成规则**。
#        所以关掉 Jack 之后，每个 Java 模块都会报：
#           ninja: error: '.../APPS/BasicDreams_intermediates/with-local/classes.dex',
#           needed by '.../APPS/BasicDreams_intermediates/classes.dex',
#           missing and no known rule to make it
#        首轮全量构建（run 44908501825）就是挂在这里。
#
# Jack 在新 JDK 上会起不来，但那是 TLS 握手问题，不是不能用：
#   Jack server failed to (re)start
#   SSL error when connecting to the Jack server
# jack-admin 的服务端用 TLSv1 + 自签 JKS，而 Temurin 8u331 之后默认禁了
# TLSv1。CI 里会先改 jdk.tls.disabledAlgorithms 把它放开，
# 再给 server 足够的堆内存（规则见 build-lineage141.yml）。
ANDROID_COMPILE_WITH_JACK := true

# ==============================================================================
# SELinux
# ==============================================================================
# 这里**不需要** POLICYVERS。
#
# 8.1 那一轮必须设 POLICYVERS := 29，因为 8.1 默认产出 v30，而 3.10 内核
# 只支持到 29（SELinux: policydb version 30 does not match my version
# range 15-29）。还得额外给 libsepol 打补丁，把 v30 才有的 ioctl 扩展权限
# 从 avtab 里摘掉，否则 checkpolicy 拒绝写出。
#
# 7.1 默认产出的就是 v28 左右，内核原生支持，一行都不用改。
# 设备自己的 policy 目录也先不启用，等系统起来按 denial 逐条补。
# BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy
