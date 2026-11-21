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
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6735 androidboot.selinux=permissive
# androidboot.hardware=mt6735：8.1 的 init 不再从 /proc/cpuinfo 猜硬件名
# （5.1 时代那个 get_hardware_name() 已经删掉），只认 ro.boot.hardware，
# 为空时 export_kernel_boot_props() 把 ro.hardware 设成 "unknown"。
# 后果是 fs_mgr 找 /fstab.unknown、init.rc 找 /init.unknown.rc，全部落空，
# 第一阶段挂不上 /system，开机直接死在 init。原厂 5.1 的 cmdline 里没有
# 这一项（它靠 cpuinfo），所以必须自己补。
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
# LineageOS 15.1 专属配置
#
# 这一段只被 lineage_gbl7356 产品读取，对 TWRP（omni_gbl7356）构建无影响：
# 上面 TWRP 用不到的变量，8.1 的 build 系统会直接忽略。
# ==============================================================================

# 本机 scatter 里没有 vendor 分区，只能走非 Treble：
# 厂商内容全部落在 /system/vendor，不生成 vendor.img，也不需要 VNDK。
BOARD_USES_VENDORIMAGE := false
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false
# TARGET_COPY_OUT_VENDOR 已在上面（TWRP 段）声明为 system/vendor，此处不重复赋值。

# 8.1 的 init 从 ramdisk 起，system 挂载后再 switch_root，
# 所以 ramdisk 里必须有完整的 init + 第一阶段的 rc。
BOARD_ROOT_EXTRA_FOLDERS := \
    oemkeystore

# 内核暂用原厂预编译 Image.gz-dtb。
# TWRP（同为 Android 8.1 用户空间）已经在这颗内核上跑通了，先不动它，
# 把变量减到最少；等系统能起、确认 sdcardfs / memfd_create 确实是瓶颈，
# 再切到自编内核（TARGET_KERNEL_SOURCE）。
# TARGET_KERNEL_SOURCE := kernel/gionee/gbl7356
# TARGET_KERNEL_CONFIG := gbl7356_defconfig
TARGET_KERNEL_ARCH := arm64

# ==============================================================================
# Java 编译：关掉 Jack
# ==============================================================================
# build/core/clear_vars.mk:111 会把每个 Java 模块的 LOCAL_JACK_ENABLED 预置成
# DEFAULT_JACK_ENABLED，而 config.mk:662 在 ANDROID_COMPILE_WITH_JACK=true 时
# 把它设成 full。于是整棵树的 Java 模块都挂着 `| setup-jack-server` 这个
# order-only 依赖，构建一上来就得先起 Jack 服务。
#
# jack-admin 起服务用的是 TLSv1 + 自签 JKS，现在的 Temurin 8 已经把旧协议和
# 弱算法禁掉了，服务端每次都在握手里死掉：
#   Jack server failed to (re)start
#   SSL error when connecting to the Jack server
# 而且 Jack 在 8.0 就已经被 AOSP 废弃，官方路线是 javac + dx。
#
# 设为 false 后 configure_local_jack.mk:21 会清空所有模块的 LOCAL_JACK_ENABLED，
# setup-jack-server 从依赖图里消失，改用 javac 编译、dx 生成 dex。
ANDROID_COMPILE_WITH_JACK := false

# ==============================================================================
# SELinux 策略：8.1 的 v30 加载不了，构建后要换成原厂 5.1 的 v26
# ==============================================================================
# 开机日志：
#   SELinux: policydb version 30 does not match my version range 15-29
#   init: Failed to load monolithic SELinux policy: Invalid argument
#   init: panic: rebooting to bootloader
#
# 这颗 3.10.65 内核的 SELinux 只到策略版本 29。想用
# `POLICYVERS := 29` 让构建系统直接产出 v29 也不行，实测编译就挂：
#   libsepol.avtab_write_item: policy version 29 does not support ioctl
#   extendedpermissions rules and one was specified
# 8.1 的策略大量使用 ioctl 扩展权限，那是 v30 才有的特性，降不下来。
#
# 所以走事后替换：构建出 boot.img 之后，把 ramdisk 里的 /sepolicy 换成
# 原厂 5.1 系统那份（v26，284365 字节，从 work/rom/boot.img 里取的，
# 就是这台机器当年真正跑过的策略）。见 ci/patch_boot_ramdisk.py
# 和工作流里的 "Patch boot sepolicy" 步骤。
# 配合 cmdline 的 androidboot.selinux=permissive，标签对不上也不会拦。
