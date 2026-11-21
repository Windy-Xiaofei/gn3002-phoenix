#
# LineageOS 14.1 device configuration — Gionee GN3002 (gbl7356)
#
# 硬件底座：MT6735 / 3.10.65 内核（原厂，不改） / 5.0" 720x1280 / 64 位用户空间
#
# 为什么是 14.1 而不是 15.1
# -------------------------
# 8.1 那一轮的结论写在 docs/DEBUG-LOG.md 的 B13/B14：8.1 需要内核提供
# /dev/hwbinder 和 /dev/vndbinder（HIDL 的三个 binder 域），而 3.10 只有
# /dev/binder。要补就得重编内核，而这棵公开源码树缺金立的板级配置
# （drvgen 生成的 cust_gpio_*.h / cust_eint.h 等），补不出来。
#
# 7.1 完全没有这个问题：
#   - binder 只有单域，/dev/binder 足够
#   - init 没有 FirstStageMount（不需要 DT fstab）
#   - SELinux 策略 v30 是 8.0 才引入的，7.1 的 v26~v28 内核原生支持
#   - init 没有 mmap_rnd_bits / kptr_restrict 那套硬化检查
# 所以 7.1 能直接用原厂内核，一个字节都不用动。
#
# 目录约定：
#   blobs/            从原厂 ROM 提取的厂商组件
#   rootdir/          init 脚本
#   configs/          media / audio / thermal 等配置文件
#

# 注意：这里不能用 $(call my-dir)。
# device.mk 是在 product_config.mk 解析产品时被 inherit-product 拉进来的，
# 那个阶段 definitions.mk 还没加载，my-dir 是空函数，LOCAL_PATH 会被清成空串，
# 于是所有 COPY_FILES 的源路径都变成 /blobs/xxx
# （8.1 那轮的首轮 CI 就挂在这：ninja: error: '/blobs/lib/hw/local_time.default.so' missing）。
# 直接写死相对路径，跟源码树根对齐，最稳。
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
    ro.opengles.version=196608

# 7.1 的 init 从 /proc/cpuinfo 或 bootargs 取硬件名，没有 8.1 那套
# export_kernel_boot_props 的机制，所以也没有 ro.boot.hardware 可用。
# 但 BoardConfig 里仍然给了 androidboot.hardware，两边都留一手。

# ------------------------------------------------------------------------------
# 厂商 blobs
#
# 本机没有独立 vendor 分区（scatter 里不存在 vendor），所以
# BOARD_USES_VENDORIMAGE 必须是 false，TARGET_COPY_OUT_VENDOR 指向 system/vendor。
# 7.1 同样是非 Treble 布局。
# ------------------------------------------------------------------------------
MTK_BLOBS := $(DEVICE_ROOT)/blobs

# HAL 模块：7.1 用的就是 legacy hw_get_module，5.1 的 .so 直接能用。
# 这也是 7.1 比 8.1 省事的地方——8.1 虽然还留着兼容路径，但 ABI 已经开始漂移。
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

# 32 位 HAL：有些代码路径（bluetooth、部分老 app）只走 32 位。
# 原厂是 64 位系统 + 32 位兼容库，两套都要。
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
#      自己编的版本和厂商 HAL 的 ABI 对不上，必须用原厂的
# 清单由 blobs.blk 提供，源文件由 tools/extract-files.py 从原厂 ROM 提取。
#
# 7.1 相比 8.1 的好处：这些库的 ABI 与 7.1 源码树更接近，
# 需要「用原厂替换」的数量少很多。
# ------------------------------------------------------------------------------
ifneq ($(wildcard $(DEVICE_ROOT)/blobs/blobs.mk),)
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
# 7.1 与 8.1 的加载方式**完全不同**，这是两个版本之间最容易搞错的地方：
#
#   8.1：/init.rc 里写 import /vendor/etc/init/hw/init.${ro.hardware}.rc
#        （注意那个 hw/ 子目录），而且挂载由 init 的 C++ 代码（fs_mgr）完成。
#
#   7.1：init.rc 里写 import /init.${ro.hardware}.rc，直接放 ramdisk 根目录。
#        挂载靠 init.rc 里的 mount_all /system/vendor/etc/fstab.${ro.hardware}。
#
# 所以 7.1 的 init.mt6735.rc 和 fstab.mt6735 都要放 ramdisk 根，
# 而不是 vendor/etc/init/hw/。
# ------------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_ROOT)/rootdir/init.mt6735.rc:root/init.mt6735.rc \
    $(DEVICE_ROOT)/rootdir/fstab.mt6735:root/fstab.mt6735 \
    $(DEVICE_ROOT)/rootdir/ueventd.mt6735.rc:root/ueventd.mt6735.rc

# ------------------------------------------------------------------------------
# 外部存储
#
# 内核 3.10.65 没有编 sdcardfs（fuse 相关符号有 802 处，sdcardfs 为 0），
# 所以必须用 FUSE。7.1 默认就是 FUSE，这里显式钉死，防止源码树里
# 某个 common 配置把它切走。
# ------------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sys.sdcardfs=false

# ------------------------------------------------------------------------------
# SELinux：先 permissive 跑通，再按 denial 逐条补 policy
#
# 7.1 的内核原生支持策略版本 ≤ 29，7.1 自己产出的是 v28 左右，
# **不需要** 8.1 那套 POLICYVERS=29 + libsepol 补丁。
# ------------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.boot.selinux=permissive

# ------------------------------------------------------------------------------
# 调试：默认打开 adb
#
# 7.1 里 PRODUCT_DEFAULT_PROPERTY_OVERRIDES 还不存在（Android 9 才有），
# ADDITIONAL_DEFAULT_PROPERTIES 又不能放在设备树（8.1 的 main.mk:105 有校验，
# 7.1 的校验位置类似）。走 build.prop 这条路最稳：
# persist.* 属性开机时会被属性服务读进去。
# ------------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=adb
