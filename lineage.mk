#
# LineageOS 15.1 product configuration — Gionee GN3002 (gbl7356)
#
# 文件名必须叫 lineage.mk：8.1 的 build/core/product_config.mk 里，
# 只要 lunch 的产品名以 lineage_ 开头（envsetup.sh 会把 LINEAGE_BUILD
# 设成 gbl7356），找产品文件的方式就退化成
#     find device -path "*/$(LINEAGE_BUILD)/lineage.mk"
# 叫 lineage_gbl7356.mk 会直接报 "Can not locate config makefile"。
#
# 64 位用户空间（原厂 ro.product.cpu.abilist = arm64-v8a,armeabi-v7a,armeabi）
#

$(call inherit-product, build/target/product/embedded.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# LineageOS 自己的公共配置：overlays、默认应用、lineage 属性。
# 少了它编出来的只是个裸 AOSP，没有 Trebuchet，也没有设置里的 Lineage 选项。
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

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
