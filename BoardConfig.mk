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
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x04000000
BOARD_TAGS_OFFSET := 0x0E000000
BOARD_KERNEL_PAGESIZE := 2048

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
TARGET_USERIMAGES_USE_F2FS := true
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
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := zh_CN
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
