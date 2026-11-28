#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TWRP 源码级修复：adb shell 不可用 + /data 读不到。

在 bootable/recovery/Android.mk 的 LOCAL_POST_INSTALL_CMD 注入一行调用，
由 tools/postinstall-adb-data.py 直接修 TARGET_RECOVERY_ROOT_OUT。
这样复杂逻辑都在可本地测试的 Python 里，shell 注入保持极简。

用法:
    python3 patch-twrp-adb-data.py <rom_root> <device_tree_dir>
"""
import os
import sys

ROM = sys.argv[1] if len(sys.argv) > 1 else '.'
DT = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.getcwd()
MK = os.path.join(ROM, 'bootable/recovery/Android.mk')
POSTINSTALL = os.path.join(DT, 'tools', 'postinstall-adb-data.py')
MARK = 'phoenix adb-data fix'

BLOCK = r'''
# ---- phoenix adb-data fix (injected by patch-twrp-adb-data.py) ----
# 让 adb shell / 终端可用、/data 可读。必须在 mkbootfs 之前生效。
# 注意：不能用 $(TARGET_RECOVERY_ROOT_OUT) —— 在 recovery 模块上下文里它
# 指向 system root，不是 recovery ramdisk 根（2026-11-28 CI 实测：改的文件
# 没进 ramdisk）。真正的 recovery ramdisk 根是 $(PRODUCT_OUT)/recovery/root。
LOCAL_POST_INSTALL_CMD += \
    python3 %s $(PRODUCT_OUT)/recovery/root && \
    echo "phoenix adb-data fix: done" || \
    echo "::error::phoenix adb-data fix FAILED"

''' % POSTINSTALL


def main():
    if not os.path.isfile(POSTINSTALL):
        print('ERROR: 找不到 %s' % POSTINSTALL, file=sys.stderr)
        return 1
    if not os.path.isfile(MK):
        print('ERROR: 找不到 %s（不是 TWRP 源码树？）' % MK, file=sys.stderr)
        return 1
    s = open(MK, encoding='utf-8', errors='surrogateescape').read()
    if MARK in s:
        print('[adb-data] 已打过补丁，跳过')
        return 0

    marker = 'include $(BUILD_EXECUTABLE)'
    pos = s.find(marker)
    if pos < 0:
        print('ERROR: %s 里找不到 "%s"' % (MK, marker), file=sys.stderr)
        return 1
    s = s[:pos] + BLOCK + s[pos:]
    open(MK, 'w', encoding='utf-8', errors='surrogateescape').write(s)
    print('[adb-data] 注入 POST_INSTALL 到 %s' % MK)
    print('[adb-data] 调用: python3 %s' % POSTINSTALL)
    return 0


if __name__ == '__main__':
    sys.exit(main())
