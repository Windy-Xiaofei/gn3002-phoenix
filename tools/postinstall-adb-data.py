#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""在 LOCAL_POST_INSTALL_CMD 阶段调用，直接修 ramdisk 根目录。

参数: <TARGET_RECOVERY_ROOT_OUT>

做四件事（都幂等）：
  1. 放宽 /sbin 目录与 shell 工具到 0755（DAC 层）
  2. 造 /system/bin/sh（从 sbin/sh 复制），0755
  3. file_contexts 追加 /system/bin/sh -> shell_exec
  4. init.rc 追加 on post-fs: restorecon_recursive /system/bin + chmod 0771 /data
"""
import os
import shutil
import stat
import sys

ROOT = sys.argv[1]
MARK = 'phoenix-adbdata'


def fix_perms():
    """放宽 /sbin 与常用工具权限。"""
    targets = ['sbin', 'sbin/sh', 'sbin/toybox', 'sbin/ls', 'sbin/cat',
               'sbin/sed', 'sbin/grep']
    for rel in targets:
        p = os.path.join(ROOT, rel)
        if os.path.exists(p):
            os.chmod(p, 0o755)
            print('  chmod 755 %s' % rel)


def make_system_shell():
    """在 ramdisk 造 /system/bin/sh，adbd 默认就指向它。"""
    src = os.path.join(ROOT, 'sbin/sh')
    dstdir = os.path.join(ROOT, 'system/bin')
    dst = os.path.join(dstdir, 'sh')
    if not os.path.isfile(src):
        print('  !! sbin/sh 不存在，无法造 /system/bin/sh', file=sys.stderr)
        return
    os.makedirs(dstdir, exist_ok=True)
    shutil.copyfile(src, dst)
    os.chmod(dst, 0o755)
    os.chmod(dstdir, 0o755)
    print('  created /system/bin/sh (%d bytes)' % os.path.getsize(dst))


def fix_file_contexts():
    p = os.path.join(ROOT, 'file_contexts')
    if not os.path.isfile(p):
        print('  !! file_contexts 不存在，跳过标签规则', file=sys.stderr)
        return
    s = open(p, encoding='utf-8', errors='surrogateescape').read()
    if MARK in s or '/system/bin/sh' in s:
        print('  file_contexts 已有 /system/bin/sh 规则，跳过')
        return
    with open(p, 'a', encoding='utf-8', errors='surrogateescape') as f:
        f.write('\n# %s: adbd shell\n' % MARK)
        f.write('/system/bin/sh u:object_r:shell_exec:s0\n')
    print('  file_contexts: + /system/bin/sh -> shell_exec')


def fix_init_rc():
    p = os.path.join(ROOT, 'init.rc')
    if not os.path.isfile(p):
        print('  !! init.rc 不存在，跳过', file=sys.stderr)
        return
    s = open(p, encoding='utf-8', errors='surrogateescape').read()
    if MARK in s:
        print('  init.rc 已含修复段，跳过')
        return
    block = (
        '\n# %s: relabel shell + ensure /data readable\n' % MARK
        + 'on post-fs\n'
        + '    restorecon_recursive /system/bin\n'
        + '    chmod 0771 /data\n'
        + '    write /dev/kmsg "<3>phoenix: adb-data fix applied"\n'
    )
    with open(p, 'a', encoding='utf-8', errors='surrogateescape') as f:
        f.write(block)
    print('  init.rc: + on post-fs restorecon/chmod')


def main():
    if not os.path.isdir(ROOT):
        print('ERROR: 目录不存在: %s' % ROOT, file=sys.stderr)
        return 1
    print('[postinstall-adb-data] %s' % ROOT)
    fix_perms()
    make_system_shell()
    fix_file_contexts()
    fix_init_rc()
    return 0


if __name__ == '__main__':
    sys.exit(main())
