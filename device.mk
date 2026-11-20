#
# LineageOS 15.1 device configuration — Gionee GN3002 (gbl7356)
#
# 硬件底座：MT6735 / 3.10.65 内核 / 5.0" 720x1280 / 64 位用户空间
#
# 目录约定：
#   blobs/            从原厂 ROM 提取的厂商组件（extract-files.sh 生成）
#   rootdir/          init 脚本
#   sepolicy/         设备 SELinux 策略
#   overlay/          RRO 覆盖（framework 配置）
#   configs/          media / audio / thermal 等配置文件
#

LOCAL_PATH := $(call my-dir)

# ------------------------------------------------------------------------------
# 构建目标校验：刷错包直接中止
# ------------------------------------------------------------------------------
TARGET_OTA_ASSERT_DEVICE := gbl7356,GIONEE_GBL7356,GN3002

# ------------------------------------------------------------------------------
# 屏幕与 AAPT
# ------------------------------------------------------------------------------
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi
PRODUCT_CHARACTERISTICS := phone
TARGET_SCREEN_DENSITY := 320

# ------------------------------------------------------------------------------
# 硬件标识
#
# ro.hardware 决定 init 加载哪个 init.${ro.hardware}.rc，以及 HAL 的默认实现后缀
# （hw_get_module 会先找 <id>.$(ro.hardware).so，再退回 <id>.default.so）。
# 原厂是 mt6735，必须一致，否则 HAL 全部 fallback 到 default（等于没有加速）。
# ------------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware=mt6735 \
    ro.board.platform=mt6735 \
    ro.mediatek.platform=MT6735 \
    ro.mediatek.chip_ver=S01 \
    ro.sf.lcd_density=320 \
    ro.opengles.version=196608 \
    ro.kernel.android.checkjni=0

# ------------------------------------------------------------------------------
# 厂商 blobs
#
# 全部按 8.1 的 non-Treble 约定放到 /system/vendor。
# 本机没有独立 vendor 分区（scatter 里不存在 vendor），所以 BOARD_USES_VENDORIMAGE
# 必须是 false，TARGET_COPY_OUT_VENDOR 指向 system/vendor。
# ------------------------------------------------------------------------------
MTK_BLOBS := $(LOCAL_PATH)/blobs

# HAL 模块：8.1 仍支持 legacy hw_get_module，直接用 5.1 的 .so
MTK_HAL_MODULES := \
    gralloc.mt6735 \
    hwcomposer.mt6735 \
    memtrack.mt6735 \
    sensors.mt6735 \
    camera.mt6735 \
    audio.primary.mt6735 \
    audio_policy.default \
    audio.r_submix.default \
    audio.usb.default \
    gps.default \
    lights.default \
    power.default \
    vibrator.default \
    keystore.default \
    local_time.default \
    nfc_nci.pn54x.default \
    mmsdk.default

$(foreach m,$(MTK_HAL_MODULES), \
    $(eval PRODUCT_COPY_FILES += \
        $(MTK_BLOBS)/lib64/hw/$(m).so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/$(m).so))

# 32 位 HAL：有些代码路径（尤其 bluetooth、老 app）只走 32 位
MTK_HAL_MODULES_32 := \
    gralloc.mt6735 \
    hwcomposer.mt6735 \
    memtrack.mt6735 \
    sensors.mt6735 \
    camera.mt6735 \
    audio.primary.mt6735 \
    audio_policy.default \
    audio.r_submix.default \
    audio.usb.default \
    gps.default \
    lights.default \
    power.default \
    vibrator.default \
    keystore.default \
    local_time.default \
    nfc_nci.pn54x.default \
    mmsdk.default \
    bluetooth.default

$(foreach m,$(MTK_HAL_MODULES_32), \
    $(eval PRODUCT_COPY_FILES += \
        $(MTK_BLOBS)/lib/hw/$(m).so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/$(m).so))

# ------------------------------------------------------------------------------
# 厂商库
#
# 两类：
#   1) MTK 专有（libmtk*、libMtkOmx*、libion_mtk 等），AOSP 不会编
#   2) 被 MTK 改过的 AOSP 库（libcamera_client、libstagefright、libgui 等），
#      8.1 自己编的版本和厂商 HAL 的 ABI 对不上，必须用原厂的
# 清单由 tools/extract-files.sh 生成，见 blobs/proprietary-files.txt
# ------------------------------------------------------------------------------
ifneq ($(wildcard $(LOCAL_PATH)/blobs/proprietary-files.txt),)
include $(LOCAL_PATH)/blobs/blobs.mk
endif

# ------------------------------------------------------------------------------
# 配置文件
# ------------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(LOCAL_PATH)/configs/audio_policy.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy.conf \
    $(LOCAL_PATH)/configs/thermal.conf:$(TARGET_COPY_OUT_VENDOR)/etc/.tp/thermal.conf \
    $(LOCAL_PATH)/configs/thermal.off.conf:$(TARGET_COPY_OUT_VENDOR)/etc/.tp/thermal.off.conf

# ------------------------------------------------------------------------------
# init / ueventd
#
# 8.1 的 /init.rc 里写的是：
#     import /vendor/etc/init/hw/init.${ro.hardware}.rc
# 注意那个 hw/ 子目录，少一层就不会被加载，表现为「设备服务一个都没起」。
# ------------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/init.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.rc \
    $(LOCAL_PATH)/rootdir/ueventd.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc \
    $(LOCAL_PATH)/rootdir/fstab.mt6735:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6735

# ------------------------------------------------------------------------------
# 基础包
#
# 只列 8.1 源码树里真实存在的模块。厂商那批（libGLES_mali、libion_mtk……）
# 由 blobs/blobs.mk 以 PRODUCT_COPY_FILES 拷进 /system/vendor，
# 写进 PRODUCT_PACKAGES 会直接报 "module not found"。
# ------------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    libion \
    libstagefright_omx \
    libstagefright_omx_soft

# ------------------------------------------------------------------------------
# 外部存储
#
# 内核 3.10.65 没有编 sdcardfs（8.0+ 默认用它替代 FUSE）。先用 FUSE 跑通，
# 等自编内核后再切回 sdcardfs。
# ------------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.fuse=true

# ------------------------------------------------------------------------------
# SELinux：先 permissive 跑通，再按 denial 逐条补 policy
# ------------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.boot.selinux=permissive
