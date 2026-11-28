# 由 tools/extract-files.sh 自动生成，请勿手改
LOCAL_BLOBS := $(DEVICE_ROOT)/blobs

# MTK 私有库完整依赖闭包（audio/camera/bt/wifi HAL 所需）
# 由 tools/extract_full_closure.py + gen_missing_libs_mk.py 生成
include $(LOCAL_BLOBS)/missing_libs.mk

PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/egl/egl.cfg:$(TARGET_COPY_OUT_VENDOR)/lib/egl/egl.cfg
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/egl/libGLES_android.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/libGLES_android.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/egl/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/libGLES_mali.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/audio.primary.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/audio.primary.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/audio.primary.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/audio.primary.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/audio.r_submix.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/audio.r_submix.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/audio.usb.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/audio.usb.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/audio_policy.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/audio_policy.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/audio_policy.stub.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/audio_policy.stub.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/bluetooth.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/bluetooth.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/camera.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/camera.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/gps.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/gps.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/gralloc.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/gralloc.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/gralloc.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/gralloc.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/hwcomposer.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/hwcomposer.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/keystore.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/keystore.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/lights.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/lights.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/local_time.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/local_time.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/memtrack.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/memtrack.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/mmsdk.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/mmsdk.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/nfc_nci.pn54x.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/nfc_nci.pn54x.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/power.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/power.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/sensors.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/sensors.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/hw/vibrator.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/vibrator.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxAdpcmDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxAdpcmDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxAdpcmEnc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxAdpcmEnc.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxAlacDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxAlacDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxApeDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxApeDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxCore.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxCore.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxFlacDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxFlacDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxG711Dec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxG711Dec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxGsmDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxGsmDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxMp3Dec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxMp3Dec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxRawDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxRawDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxVdec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxVdec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxVenc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxVenc.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkOmxVorbisEnc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxVorbisEnc.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkVideoSpeedEffect.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkVideoSpeedEffect.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libMtkVideoTranscoder.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkVideoTranscoder.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libaudiocustparam.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiocustparam.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libaudiodcrflt.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiodcrflt.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libbessound_hd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbessound_hd_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libbluetooth_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbluetooth_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libbluetoothem_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbluetoothem_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libcamera_client_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcamera_client_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libcvsd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcvsd_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libdcfdecoderjni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libdcfdecoderjni.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libdpframework.so:$(TARGET_COPY_OUT_VENDOR)/lib/libdpframework.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libdrmmtkutil.so:$(TARGET_COPY_OUT_VENDOR)/lib/libdrmmtkutil.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libdrmmtkwhitelist.so:$(TARGET_COPY_OUT_VENDOR)/lib/libdrmmtkwhitelist.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libextsys.so:$(TARGET_COPY_OUT_VENDOR)/lib/libextsys.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libextsys_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libextsys_jni.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libfeatureio.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfeatureio.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libfeatureiodrv.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfeatureiodrv.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libfile_op.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfile_op.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libged.so:$(TARGET_COPY_OUT_VENDOR)/lib/libged.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libgpu_aux.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgpu_aux.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libgralloc_extra.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgralloc_extra.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libhwm.so:$(TARGET_COPY_OUT_VENDOR)/lib/libhwm.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libion_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libion_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libm4u.so:$(TARGET_COPY_OUT_VENDOR)/lib/libm4u.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmediatek_exceptionlog.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmediatek_exceptionlog.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmhalImageCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmhalImageCodec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmsbc_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmsbc_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtk_drvb.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtk_drvb.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtk_mmutils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtk_mmutils.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtkbtextspp.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtkbtextspp.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtkjpeg.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtkjpeg.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtklimiter.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtklimiter.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtkplayer.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtkplayer.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtkshifter.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtkshifter.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtksqlite3_android.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtksqlite3_android.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libmtksqlite3_custom.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtksqlite3_custom.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libnvram.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libnvram_daemon_callback.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram_daemon_callback.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libnvram_platform.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram_platform.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libnvram_sec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram_sec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libnvramagentclient.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvramagentclient.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libpalsecurity.so:$(TARGET_COPY_OUT_VENDOR)/lib/libpalsecurity.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libsec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libsec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libsecurity.so:$(TARGET_COPY_OUT_VENDOR)/lib/libsecurity.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libsrsprocessing.so:$(TARGET_COPY_OUT_VENDOR)/lib/libsrsprocessing.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libudf.so:$(TARGET_COPY_OUT_VENDOR)/lib/libudf.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib/libwifi-service.so:$(TARGET_COPY_OUT_VENDOR)/lib/libwifi-service.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/egl/libGLES_android.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLES_android.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/egl/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLES_mali.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/audio.primary.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.primary.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/audio.primary.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.primary.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/audio.r_submix.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.r_submix.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/audio.usb.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.usb.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/audio_policy.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio_policy.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/audio_policy.stub.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio_policy.stub.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/camera.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/camera.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/gps.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/gps.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/gralloc.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/gralloc.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/gralloc.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/gralloc.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/hwcomposer.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/hwcomposer.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/keystore.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/keystore.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/lights.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/lights.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/local_time.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/local_time.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/memtrack.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/memtrack.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/mmsdk.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/mmsdk.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/nfc_nci.pn54x.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/nfc_nci.pn54x.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/power.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/power.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/sensors.mt6735.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/sensors.mt6735.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/hw/vibrator.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/vibrator.default.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxAdpcmDec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxAdpcmDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxAdpcmEnc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxAdpcmEnc.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxAlacDec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxAlacDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxApeDec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxApeDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxCore.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxCore.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxG711Dec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxG711Dec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxGsmDec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxGsmDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxMp3Dec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxMp3Dec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxRawDec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxRawDec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkOmxVorbisEnc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkOmxVorbisEnc.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libMtkVideoTranscoder.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libMtkVideoTranscoder.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libaudiocustparam.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudiocustparam.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libaudiodcrflt.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudiodcrflt.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libbessound_hd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbessound_hd_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libbluetooth_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbluetooth_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libbluetoothem_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbluetoothem_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libcamera_client_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcamera_client_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libcvsd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcvsd_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libdcfdecoderjni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libdcfdecoderjni.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libdpframework.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libdpframework.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libdrmmtkutil.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libdrmmtkutil.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libdrmmtkwhitelist.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libdrmmtkwhitelist.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libextsys.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libextsys.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libextsys_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libextsys_jni.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libfeatureio.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfeatureio.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libfeatureiodrv.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfeatureiodrv.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libfile_op.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfile_op.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libged.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libged.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libgpu_aux.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgpu_aux.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libgralloc_extra.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgralloc_extra.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libhwm.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libhwm.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libion_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libion_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libm4u.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libm4u.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmediatek_exceptionlog.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmediatek_exceptionlog.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmhalImageCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmhalImageCodec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmsbc_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmsbc_mtk.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtk_drvb.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtk_drvb.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtk_mmutils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtk_mmutils.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtkjpeg.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtkjpeg.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtklimiter.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtklimiter.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtkplayer.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtkplayer.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtkshifter.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtkshifter.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtksqlite3_android.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtksqlite3_android.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libmtksqlite3_custom.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtksqlite3_custom.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libnvram.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libnvram_daemon_callback.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram_daemon_callback.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libnvram_platform.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram_platform.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libnvram_sec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram_sec.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libnvramagentclient.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvramagentclient.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libterservice.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libterservice.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libudf.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libudf.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libwapi.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwapi.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libwifi-service.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwifi-service.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/lib64/libwifitest.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwifitest.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/6620_launcher:$(TARGET_COPY_OUT_VENDOR)/bin/6620_launcher
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/6620_wmt_concurrency:$(TARGET_COPY_OUT_VENDOR)/bin/6620_wmt_concurrency
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/6620_wmt_lpbk:$(TARGET_COPY_OUT_VENDOR)/bin/6620_wmt_lpbk
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/MtkCodecService:$(TARGET_COPY_OUT_VENDOR)/bin/MtkCodecService
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/akmd09911:$(TARGET_COPY_OUT_VENDOR)/bin/akmd09911
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/akmd8963:$(TARGET_COPY_OUT_VENDOR)/bin/akmd8963
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/akmd8975:$(TARGET_COPY_OUT_VENDOR)/bin/akmd8975
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/audiocmdservice_atci:$(TARGET_COPY_OUT_VENDOR)/bin/audiocmdservice_atci
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/autokd:$(TARGET_COPY_OUT_VENDOR)/bin/autokd
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/ccci_fsd:$(TARGET_COPY_OUT_VENDOR)/bin/ccci_fsd
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/ccci_mdinit:$(TARGET_COPY_OUT_VENDOR)/bin/ccci_mdinit
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/cmddumper:$(TARGET_COPY_OUT_VENDOR)/bin/cmddumper
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/dualmdlogger:$(TARGET_COPY_OUT_VENDOR)/bin/dualmdlogger
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/emdlogger1:$(TARGET_COPY_OUT_VENDOR)/bin/emdlogger1
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/fsck_msdos_mtk:$(TARGET_COPY_OUT_VENDOR)/bin/fsck_msdos_mtk
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/fuelgauged:$(TARGET_COPY_OUT_VENDOR)/bin/fuelgauged
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/geomagneticd:$(TARGET_COPY_OUT_VENDOR)/bin/geomagneticd
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/gsm0710muxd:$(TARGET_COPY_OUT_VENDOR)/bin/gsm0710muxd
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/gsm0710muxdmd2:$(TARGET_COPY_OUT_VENDOR)/bin/gsm0710muxdmd2
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/kpoc_charger:$(TARGET_COPY_OUT_VENDOR)/bin/kpoc_charger
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/lsm303md:$(TARGET_COPY_OUT_VENDOR)/bin/lsm303md
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/md_ctrl:$(TARGET_COPY_OUT_VENDOR)/bin/md_ctrl
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/md_monitor:$(TARGET_COPY_OUT_VENDOR)/bin/md_monitor
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/md_monitor_ctrl:$(TARGET_COPY_OUT_VENDOR)/bin/md_monitor_ctrl
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/mdlogger:$(TARGET_COPY_OUT_VENDOR)/bin/mdlogger
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/meta_tst:$(TARGET_COPY_OUT_VENDOR)/bin/meta_tst
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/msensord:$(TARGET_COPY_OUT_VENDOR)/bin/msensord
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/mtk_agpsd:$(TARGET_COPY_OUT_VENDOR)/bin/mtk_agpsd
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/mtk_setprop:$(TARGET_COPY_OUT_VENDOR)/bin/mtk_setprop
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/mtkbt:$(TARGET_COPY_OUT_VENDOR)/bin/mtkbt
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/mtkrild:$(TARGET_COPY_OUT_VENDOR)/bin/mtkrild
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/mtkrildmd2:$(TARGET_COPY_OUT_VENDOR)/bin/mtkrildmd2
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/mtkvfc:$(TARGET_COPY_OUT_VENDOR)/bin/mtkvfc
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/muxreport:$(TARGET_COPY_OUT_VENDOR)/bin/muxreport
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/nvram_agent_binder:$(TARGET_COPY_OUT_VENDOR)/bin/nvram_agent_binder
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/nvram_backup_binder:$(TARGET_COPY_OUT_VENDOR)/bin/nvram_backup_binder
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/nvram_daemon:$(TARGET_COPY_OUT_VENDOR)/bin/nvram_daemon
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/sn:$(TARGET_COPY_OUT_VENDOR)/bin/sn
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/stp_dump3:$(TARGET_COPY_OUT_VENDOR)/bin/stp_dump3
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/thermal:$(TARGET_COPY_OUT_VENDOR)/bin/thermal
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/thermal_manager:$(TARGET_COPY_OUT_VENDOR)/bin/thermal_manager
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/thermald:$(TARGET_COPY_OUT_VENDOR)/bin/thermald
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/bin/wmt_loader:$(TARGET_COPY_OUT_VENDOR)/bin/wmt_loader
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/.tp/thermal.conf:$(TARGET_COPY_OUT_VENDOR)/etc/thermal.conf
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/.tp/thermal.off.conf:$(TARGET_COPY_OUT_VENDOR)/etc/thermal.off.conf
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/agps_profiles_conf2.xml:$(TARGET_COPY_OUT_VENDOR)/etc/agps_profiles_conf2.xml
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/audio_device.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_device.xml
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/audio_effects.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.conf
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/audio_policy.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy.conf
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/mtk_omx_core.cfg:$(TARGET_COPY_OUT_VENDOR)/etc/mtk_omx_core.cfg
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/etc/mtklog-config.prop:$(TARGET_COPY_OUT_VENDOR)/etc/mtklog-config.prop
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/ROMv2_lm_patch_1_0_hdr.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/ROMv2_lm_patch_1_0_hdr.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/ROMv2_lm_patch_1_1_hdr.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/ROMv2_lm_patch_1_1_hdr.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/WIFI_RAM_CODE_6735:$(TARGET_COPY_OUT_VENDOR)/firmware/WIFI_RAM_CODE_6735
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/WMT_SOC.cfg:$(TARGET_COPY_OUT_VENDOR)/firmware/WMT_SOC.cfg
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/boot_3_3g_n.rom:$(TARGET_COPY_OUT_VENDOR)/firmware/boot_3_3g_n.rom
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/catcher_filter_1_ltg_n.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/catcher_filter_1_ltg_n.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/catcher_filter_1_lwg_n.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/catcher_filter_1_lwg_n.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/dsp_1_ltg_n.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/dsp_1_ltg_n.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/dsp_1_lwg_n.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/dsp_1_lwg_n.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/em_filter_1_ltg_n.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/em_filter_1_ltg_n.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/em_filter_1_lwg_n.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/em_filter_1_lwg_n.bin
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/fsm_cust_df_3_3g_n.img:$(TARGET_COPY_OUT_VENDOR)/firmware/fsm_cust_df_3_3g_n.img
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/fsm_rf_df_3_3g_n.img:$(TARGET_COPY_OUT_VENDOR)/firmware/fsm_rf_df_3_3g_n.img
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/fsm_rw_df_3_3g_n.img:$(TARGET_COPY_OUT_VENDOR)/firmware/fsm_rw_df_3_3g_n.img
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/libpn547_fw.so:$(TARGET_COPY_OUT_VENDOR)/firmware/libpn547_fw.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/libpn548ad_fw.so:$(TARGET_COPY_OUT_VENDOR)/firmware/libpn548ad_fw.so
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/modem_1_ltg_n.img:$(TARGET_COPY_OUT_VENDOR)/firmware/modem_1_ltg_n.img
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/modem_1_lwg_n.img:$(TARGET_COPY_OUT_VENDOR)/firmware/modem_1_lwg_n.img
PRODUCT_COPY_FILES += $(LOCAL_BLOBS)/vendor/firmware/modem_3_3g_n.img:$(TARGET_COPY_OUT_VENDOR)/firmware/modem_3_3g_n.img
# ---- 显示栈缺失依赖（2026-11-28 用 tools/check_elf_deps.py 离线查出）----
# hwcomposer.mt6735.so 的 DT_NEEDED 里有 5 个库在镜像和 blobs 中都不存在：
#   libion.so  libbwc.so  libgui_ext.so  libui_ext.so  libperfservicenative.so
# gralloc.mt6735.so 也缺 libion.so。
# HWC/gralloc 都是 dlopen 加载的，缺依赖会导致 HAL 初始化失败、
# surfaceflinger 直接 abort（signal 6）——这正是 14.1 卡在显示阶段的原因。
# 这些库从原厂 5.1 的 system.img 提取（tools/extract_factory_libs.py），
# 放到 /system/vendor/lib{,64}（7.1 非 Treble，vendor = system/vendor）。
PRODUCT_COPY_FILES += \
    $(LOCAL_BLOBS)/lib/libion.so:$(TARGET_COPY_OUT_VENDOR)/lib/libion.so \
    $(LOCAL_BLOBS)/lib/libbwc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbwc.so \
    $(LOCAL_BLOBS)/lib/libgui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgui_ext.so \
    $(LOCAL_BLOBS)/lib/libui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib/libui_ext.so \
    $(LOCAL_BLOBS)/lib/libperfservicenative.so:$(TARGET_COPY_OUT_VENDOR)/lib/libperfservicenative.so \
    $(LOCAL_BLOBS)/lib64/libion.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libion.so \
    $(LOCAL_BLOBS)/lib64/libbwc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbwc.so \
    $(LOCAL_BLOBS)/lib64/libgui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgui_ext.so \
    $(LOCAL_BLOBS)/lib64/libui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libui_ext.so \
    $(LOCAL_BLOBS)/lib64/libperfservicenative.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libperfservicenative.so

# ---- libstlport.so（Mali 驱动的旧 STL 依赖，2026-11-28 实机堆栈定位）----
# 崩溃点：eglGetDisplay() -> libEGL.so -> SurfaceFlinger::init()，signal 6。
# libGLES_mali.so 的 DT_NEEDED 里有 libstlport.so —— 原厂 5.1 时代的 STL，
# AOSP 7.1 已改用 libc++，系统里没有；缺它 dlopen 失败，eglGetDisplay 返回
# NULL，surfaceflinger 直接 abort。原厂镜像里两份都在，直接搬过来。
PRODUCT_COPY_FILES += \
    $(LOCAL_BLOBS)/lib/libstlport.so:$(TARGET_COPY_OUT_VENDOR)/lib/libstlport.so \
    $(LOCAL_BLOBS)/lib64/libstlport.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libstlport.so

# ---- libpq_prot.so（dpframework 的第三层依赖；2026-11-28 递归排查定位）----
# 崩溃链：surfaceflinger -> libGLES_mali.so -> libdpframework.so -> libpq_prot.so
# libdpframework.so 的 DT_NEEDED 里有 libpq_prot.so，
# 原厂把它放在 /system/lib{,64}（不在 vendor 下），所以前几轮清单都漏了它。
# 缺它 -> dpframework 加载失败 -> libGLES_mali 加载失败 ->
#        eglGetDisplay() 返回 NULL -> libEGL 报
#        "couldn't find an OpenGL ES implementation" -> signal 6。
PRODUCT_COPY_FILES += \
    $(LOCAL_BLOBS)/lib/libpq_prot.so:$(TARGET_COPY_OUT_VENDOR)/lib/libpq_prot.so \
    $(LOCAL_BLOBS)/lib64/libpq_prot.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libpq_prot.so

# ---- WiFi wpa_supplicant + config (2026-11-28) ----
# 2026-11-28 实机：镜像里完全没有 wpa_supplicant，导致 WiFi HAL 起不来
# （WifiNative-HAL: HAL isn't started）。从原厂提取 64-bit wpa_supplicant
# + libwapi.so（已在上面）+ /etc/wifi 配置。
PRODUCT_COPY_FILES += \
    $(LOCAL_BLOBS)/bin/wpa_supplicant:/system/bin/wpa_supplicant \
    $(LOCAL_BLOBS)/etc/wifi/wpa_supplicant.conf:/system/etc/wifi/wpa_supplicant.conf \
    $(LOCAL_BLOBS)/etc/wifi/wpa_supplicant_overlay.conf:/system/etc/wifi/wpa_supplicant_overlay.conf
