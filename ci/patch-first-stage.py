#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
让 8.1 的 init 在没有设备树 fstab 时，用 ramdisk 里的 /fstab.mt6735 完成第一阶段挂载。

用法：
    python3 ci/patch-first-stage.py rom/system/core/init/init_first_stage.cpp

两个必须同时处理的点：

1) DT 里没有 /firmware/android/fstab 节点时，原代码直接 return，
   mount_fstab_recs_ 保持为空，DoFirstStageMount() 认为"没有要挂的东西"，
   /system 永远挂不上。

2) 回落时**不能**调用 fs_mgr_read_fstab_default()。它在 main() 里的执行位置
   在第 47 行（DoFirstStageMount），而 property_init() 在第 92 行、且在
   execv 之后。也就是说走到这里时属性区还没建，ro.hardware 读出来是空，
   拼出来的路径是 "/fstab."，必然失败。只能用固定路径尝试。

3) ramdisk 的 fstab 和 DT fstab 内容不同：ramdisk 那份还包含 /data、/cache、
   /protect_*、/nvdata 以及 voldmanaged 的 auto 条目。这些不属于第一阶段，
   而且 MountPartitions() 是对 mount_fstab_recs_ 里**每一条**调
   fs_mgr_do_mount_one()，任何一条失败就直接返回 false 让 init panic。
   所以只把 /system、/vendor 放进 vector。
"""
import sys

OLD = '''FirstStageMount::FirstStageMount()
    : need_dm_verity_(false), device_tree_fstab_(fs_mgr_read_fstab_dt(), fs_mgr_free_fstab) {
    if (!device_tree_fstab_) {
        LOG(ERROR) << "Failed to read fstab from device tree";
        return;
    }
    // Stores device_tree_fstab_->recs[] into mount_fstab_recs_ (vector<fstab_rec*>)
    // for easier manipulation later, e.g., range-base for loop.
    for (int i = 0; i < device_tree_fstab_->num_entries; i++) {
        mount_fstab_recs_.push_back(&device_tree_fstab_->recs[i]);
    }
}'''

NEW = '''FirstStageMount::FirstStageMount()
    : need_dm_verity_(false), device_tree_fstab_(fs_mgr_read_fstab_dt(), fs_mgr_free_fstab) {
    if (!device_tree_fstab_) {
        // 老平台（这颗 3.10 的 MTK 内核）的 DTB 里没有 /firmware/android/fstab。
        // 这里离 property_init() 还有很远（它在 main() 的第二阶段、execv 之后），
        // ro.hardware 此刻读不到，fs_mgr_read_fstab_default() 会拼出 "/fstab." 而失败，
        // 因此只能按固定路径依次尝试。
        static const char* kFallbackFstabPaths[] = {
                "/fstab.mt6735",
                "/vendor/etc/fstab.mt6735",
        };
        for (const char* path : kFallbackFstabPaths) {
            device_tree_fstab_.reset(fs_mgr_read_fstab(path));
            if (device_tree_fstab_) {
                LOG(WARNING) << "No fstab in device tree; using " << path;
                break;
            }
        }
        if (!device_tree_fstab_) {
            LOG(ERROR) << "Failed to read fstab from device tree or ramdisk";
            return;
        }
    }
    // Stores device_tree_fstab_->recs[] into mount_fstab_recs_ (vector<fstab_rec*>)
    // for easier manipulation later, e.g., range-base for loop.
    for (int i = 0; i < device_tree_fstab_->num_entries; i++) {
        struct fstab_rec* rec = &device_tree_fstab_->recs[i];
        // 设备树的 fstab 通常只有 system/vendor；ramdisk 这份还带着 /data、/cache、
        // /protect_*、/nvdata 和 voldmanaged 的 auto 条目。第一阶段只该挂 /system
        // 和 /vendor，其余留给第二阶段的 vold。若把 auto 条目也放进来，
        // MountPartitions() 会对它调 fs_mgr_do_mount_one() 并失败，init 随即 panic。
        if (std::string(rec->mount_point) != "/system" &&
            std::string(rec->mount_point) != "/vendor") {
            continue;
        }
        mount_fstab_recs_.push_back(rec);
    }
}'''

CTOR_MARK = 'No fstab in device tree; using '
GATE_MARK = 'falling back to ramdisk fstab'

# ---------------------------------------------------------------------------
# 第二处：守卫函数。这个才是真正拦路的地方。
#
# bool DoFirstStageMount() {
#     if (IsRecoveryMode()) { ... return true; }
#     // Firstly checks if device tree fstab entries are compatible.
#     if (!is_android_dt_value_expected("fstab/compatible", "android,fstab")) {
#         LOG(INFO) << "First stage mount skipped (missing/incompatible fstab in device tree)";
#         return true;            // ← 构造函数根本没被调用
#     }
#     std::unique_ptr<FirstStageMount> handle = FirstStageMount::Create();
#     ...
#
# 第一版补丁只改了构造函数，结果这个守卫在它之前就 return 了，
# ramdisk 里的 fstab 一次都没被读过（日志里连 "No fstab in device tree; using"
# 都看不到，只有一句 INFO 级的 skipped，被 ignore_loglevel 之外的因素吞掉了）。
# 所以必须把这道门也拆掉。
# ---------------------------------------------------------------------------
GATE_OLD = '''    // Firstly checks if device tree fstab entries are compatible.
    if (!is_android_dt_value_expected("fstab/compatible", "android,fstab")) {
        LOG(INFO) << "First stage mount skipped (missing/incompatible fstab in device tree)";
        return true;
    }'''

GATE_NEW = '''    // 这颗 3.10 的 MTK 内核 DTB 里没有 /firmware/android/fstab 节点。
    // 原逻辑直接 return true 跳过整个第一阶段挂载，/system 因此永远挂不上。
    // 这里改成继续往下走，由 FirstStageMount 的构造函数从 ramdisk 的固定路径读。
    if (!is_android_dt_value_expected("fstab/compatible", "android,fstab")) {
        LOG(WARNING) << "No fstab/compatible in device tree; falling back to ramdisk fstab";
    }'''


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    path = sys.argv[1]
    s = open(path, encoding='utf-8').read()

    todo = []
    if CTOR_MARK not in s:
        todo.append(('ctor', OLD, NEW))
    if GATE_MARK not in s:
        todo.append(('gate', GATE_OLD, GATE_NEW))

    if not todo:
        print('已经打过补丁，跳过')
        return

    for name, old, new in todo:
        if old not in s:
            sys.exit('没找到待替换片段(%s)，源码结构可能变了' % name)
        s = s.replace(old, new)
        print('  已替换:', name)

    open(path, 'w', encoding='utf-8').write(s)
    print('已给 init_first_stage.cpp 打补丁：拆掉 DT fstab 守卫 + DT 缺失时用固定路径回落')


if __name__ == '__main__':
    main()
