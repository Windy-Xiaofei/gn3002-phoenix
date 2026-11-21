#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
让 8.1 的 init 在没有设备树 fstab 时回落到 ramdisk 的 /fstab.<hardware>。

用法：
    python3 ci/patch-first-stage.py rom/system/core/init/init_first_stage.cpp

背景：Android 8 起，第一阶段挂载（DoFirstStageMount）只使用设备树里的
/firmware/android/fstab 节点：

    FirstStageMount::FirstStageMount()
        : device_tree_fstab_(fs_mgr_read_fstab_dt(), fs_mgr_free_fstab) {
        if (!device_tree_fstab_) {
            LOG(ERROR) << "Failed to read fstab from device tree";
            return;      // mount_fstab_recs_ 保持空
        }
        ...
    }

    bool FirstStageMount::DoFirstStageMount() {
        if (mount_fstab_recs_.empty()) return true;   // 认为"没有要挂的"
        ...
    }

这颗 3.10 的内核 DTB 里没有该节点（日志：fs_mgr_read_fstab_dt():
failed to read fstab from dt），于是 init 直接跳过挂载，/system 永远挂不上，
后面 logd / servicemanager 等服务的 .rc 都读不到，卡死在开机第一屏。

补丁：DT 读不到时改用 fs_mgr_read_fstab_default()（就是 ramdisk 里的
/fstab.${ro.hardware}），对非 Treble、老 DTB 的设备是等效的。
"""
import sys


OLD = '''    if (!device_tree_fstab_) {
        LOG(ERROR) << "Failed to read fstab from device tree";
        return;
    }'''

NEW = '''    if (!device_tree_fstab_) {
        LOG(WARNING) << "No fstab in device tree; falling back to ramdisk fstab";
        device_tree_fstab_.reset(fs_mgr_read_fstab_default());
        if (!device_tree_fstab_) {
            LOG(ERROR) << "Failed to read fstab from ramdisk either";
            return;
        }
    }'''


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    path = sys.argv[1]
    s = open(path, encoding='utf-8').read()

    if 'falling back to ramdisk fstab' in s:
        print('已经打过补丁，跳过')
        return

    if OLD not in s:
        sys.exit('没找到待替换片段，源码结构可能变了')

    s = s.replace(OLD, NEW)
    open(path, 'w', encoding='utf-8').write(s)
    print('已给 init_first_stage.cpp 打补丁：DT 无 fstab 时回落 ramdisk')


if __name__ == '__main__':
    main()
