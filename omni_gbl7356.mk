#
# TWRP product configuration — Gionee GN3002 (gbl7356)
#
# 继承 64 位核心，然后只装 recovery 需要的东西。
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

PRODUCT_NAME := omni_gbl7356
PRODUCT_DEVICE := gbl7356
PRODUCT_BRAND := Gionee
PRODUCT_MODEL := GN3002
PRODUCT_MANUFACTURER := Gionee
PRODUCT_RELEASE_NAME := GN3002

PRODUCT_SYSTEM_PROPERTY_BLACKLIST := ro.product.model

# 屏幕密度 320dpi，与原厂 ro.sf.lcd_density 一致
TARGET_SCREEN_DENSITY := 320
