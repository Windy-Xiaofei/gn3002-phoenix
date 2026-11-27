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

# 注意：这里不能用 $(call my-dir)。
# device.mk 是在 product_config.mk 解析产品时被 inherit-product 拉进来的，
# 那个阶段 definitions.mk 还没加载，my-dir 是空函数，LOCAL_PATH 会被清成空串，
# 于是所有 COPY_FILES 的源路径都变成 /blobs/xxx（首轮 CI 就挂在这：
# ninja: error: '/blobs/lib/hw/local_time.default.so' missing）。
# 直接写死相对路径，跟 AOSP 树根对齐，最稳。
DEVICE_ROOT := device/gionee/gbl7356

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
MTK_BLOBS := $(DEVICE_ROOT)/blobs

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
ifneq ($(wildcard $(DEVICE_ROOT)/blobs/proprietary-files.txt),)
include $(DEVICE_ROOT)/blobs/blobs.mk
endif

# ------------------------------------------------------------------------------
# 配置文件
# ------------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_ROOT)/configs/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(DEVICE_ROOT)/configs/audio_policy.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy.conf \
    $(DEVICE_ROOT)/configs/thermal.conf:$(TARGET_COPY_OUT_VENDOR)/etc/.tp/thermal.conf \
    $(DEVICE_ROOT)/configs/thermal.off.conf:$(TARGET_COPY_OUT_VENDOR)/etc/.tp/thermal.off.conf

# ------------------------------------------------------------------------------
# init / ueventd
#
# 8.1 的 /init.rc 里写的是：
#     import /vendor/etc/init/hw/init.${ro.hardware}.rc
# 注意那个 hw/ 子目录，少一层就不会被加载，表现为「设备服务一个都没起」。
# ------------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_ROOT)/rootdir/init.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.rc \
    $(DEVICE_ROOT)/rootdir/fstab.mt6735:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6735 \
    $(DEVICE_ROOT)/rootdir/fstab.mt6735:root/fstab.mt6735 \
    $(DEVICE_ROOT)/rootdir/ueventd.mt6735.rc:root/ueventd.mt6735.rc \
    $(DEVICE_ROOT)/rootdir/sbin/bootlog.sh:root/sbin/bootlog.sh \
    $(DEVICE_ROOT)/rootdir/init.mt6735.rc:root/init.mt6735.rc

# 上面几条 root/ 是打进 ramdisk 的，位置不能改：
#
#   root/init.mt6735.rc
#     7.1（14.1）：init 在解析完 AOSP /init.rc 后 import /init.${ro.hardware}.rc，
#                 它只认 ramdisk 根这一份。少了它，设备服务一个都不起、
#                 mount_all 也没人调 —— 表现就是静默卡第一屏。
#     8.1（15.1）：改读 /vendor/etc/init/hw/init.${ro.hardware}.rc，所以两份都拷。
#
#   root/fstab.mt6735
#     7.1：fs_mgr_read_fstab_default() 只按 /fstab.<hw> 找，也就是这一份。
#     8.1：fs_mgr_read_fstab_default()（core/fs_mgr/fs_mgr_fstab.cpp:708）按
#          /odm/etc/fstab.<hw> → /vendor/etc/fstab.<hw> → /fstab.<hw> 找，
#          前两个在 init 第一阶段（此时 /system 还没挂上，/vendor 只是断链）
#          根本访问不到，仍只有 ramdisk 根这份能命中。
#     缺了它 mount_all 直接失败，/system 挂不上，开机停在 logo。
#
#   root/sbin/bootlog.sh
#     开机日志落盘脚本：/proc/last_kmsg 是内核 ram console 的 64 KB 环形缓冲，
#     硬断电即丢失（本项目实测拿到过两次全 NUL），所以改成把 dmesg / logcat
#     写进 /cache/gn3002/。由设备 rc 以
#         service bootlog /system/bin/sh /sbin/bootlog.sh
#     方式执行，不依赖可执行位，但内容必须是 LF 换行。
#
#   root/ueventd.mt6735.rc
#     ueventd.cpp:230-242 读的是 /ueventd.rc、/vendor/ueventd.rc、
#     /odm/ueventd.rc，最后再补一个 /ueventd.<hardware>.rc。
#     注意 /vendor/ueventd.rc ≠ /vendor/etc/ueventd.rc，之前拷到
#     vendor/etc 下那份其实一次都没被读过，已删除。

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

# ==============================================================================
# 调试：默认打开 adb
# ==============================================================================
# 系统起不来时最需要的是 logcat。8.1 默认 persist.sys.usb.config=none，
# 即使 adbd 起来了也不会去拉 USB 配置，调试只能靠屏幕猜。
#
# 注意不能用 ADDITIONAL_DEFAULT_PROPERTIES：envsetup.mk:208 在 include
# BoardConfig 之前就把产品配置读完，所以设备树里任何位置设置它都会撞上
# main.mk:105 的校验：
#     ADDITIONAL_DEFAULT_PROPERTIES must not be set before here
# 8.1 也没有 PRODUCT_DEFAULT_PROPERTY_OVERRIDES（Android 9 才有）。
# 走 build.prop 这条路：persist.* 属性开机时会被读进属性服务，一样生效。
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=adb
