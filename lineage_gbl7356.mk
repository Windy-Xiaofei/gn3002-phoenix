#
# LineageOS 15.1 product configuration — Gionee GN3002 (gbl7356)
#
# 64 位用户空间（原厂 ro.product.cpu.abilist = arm64-v8a,armeabi-v7a,armeabi）
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
$(call inherit-product, device/gionee/gbl7356/device.mk)

PRODUCT_NAME := lineage_gbl7356
PRODUCT_DEVICE := gbl7356
PRODUCT_BRAND := Gionee
PRODUCT_MODEL := GN3002
PRODUCT_MANUFACTURER := Gionee
PRODUCT_RELEASE_NAME := GN3002

TARGET_SCREEN_DENSITY := 320
