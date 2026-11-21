#
# LineageOS 14.1 product configuration — Gionee GN3002 (gbl7356)
#
# 文件名：14.1 的 build/core/product_config.mk:183 是
#     ifneq ($(CM_BUILD),)
#       all_product_configs := $(shell find device -path "*/$(CM_BUILD)/lineage.mk")
#       # Fall back to cm.mk
#       all_product_configs := $(shell find device -path "*/$(CM_BUILD)/cm.mk")
#       endif
# 也就是先找 lineage.mk，找不到再退回 cm.mk。两种都行，这里用 lineage.mk
# 保持和 15.1 那边一致，将来切回去时不用改。
#
# 注意变量名：14.1 是 CM_BUILD（不是 15.1 的 LINEAGE_BUILD），
# 由 build/envsetup.sh 在 lunch 时设置。
#
# 64 位用户空间（原厂 ro.product.cpu.abilist = arm64-v8a,armeabi-v7a,armeabi）
#

# 7.1 的基础产品配置。
# 注意 14.1 里没有 build/target/product/embedded.mk 这个文件（那是 8.0+ 才拆出来的），
# 基础配置走 full.mk / full_base_telephony.mk 这一套。
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# 语言包
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# LineageOS 自己的公共配置：overlays、默认应用、系统属性。
# 14.1 的路径是 vendor/cm（CyanogenMod 时代的目录名），
# 不是 15.1 的 vendor/lineage。写错会报
#   inherit-product: no such file
$(call inherit-product, vendor/cm/config/common_full_phone.mk)

# 设备配置放最后，保证 common 的默认值先落地、设备侧再覆盖
$(call inherit-product, device/gionee/gbl7356/device.mk)

# 以下必须在所有 inherit 之后
PRODUCT_NAME := lineage_gbl7356
PRODUCT_DEVICE := gbl7356
PRODUCT_BRAND := Gionee
PRODUCT_MODEL := GN3002
PRODUCT_MANUFACTURER := Gionee
PRODUCT_RELEASE_NAME := GN3002

TARGET_SCREEN_DENSITY := 320

# 原厂 system 是 3 GB，7.1 编出来大概 1.2~1.5 GB，余量充足。
# 但 userdata 只有 1.5 GB，装不下 3 GB 的卡刷包，所以只能走
# fastboot / SPFT / TWRP 刷镜像，不做 OTA zip 的 sd 卡安装。
