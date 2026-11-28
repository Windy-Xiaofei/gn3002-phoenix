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
import glob
import os
import shutil
import stat
import sys

MARK = 'phoenix-adbdata'


def resolve_root(arg):
    """确定 recovery ramdisk 根目录。

    POST_INSTALL 里 make 变量有时不展开（$(PRODUCT_OUT) 传进来会是字面量），
    所以不能只信参数。策略：
      1. 参数是个真实目录且含 sbin/ -> 用它
      2. 否则在 out/target/product/*/recovery/root 里搜索含 sbin/sh 的目录
    """
    if arg and os.path.isdir(arg) and os.path.isdir(os.path.join(arg, 'sbin')):
        return arg
    # 向上找 rom 根（脚本位于 <rom>/device/gionee/gbl7356/tools/）
    here = os.path.dirname(os.path.abspath(__file__))
    rom = here
    for _ in range(8):
        if os.path.isdir(os.path.join(rom, 'out', 'target', 'product')):
            break
        parent = os.path.dirname(rom)
        if parent == rom:
            break
        rom = parent
    candidates = glob.glob(os.path.join(rom, 'out', 'target', 'product', '*',
                                        'recovery', 'root'))
    for c in candidates:
        if os.path.isfile(os.path.join(c, 'sbin', 'sh')) or \
           os.path.isdir(os.path.join(c, 'sbin')):
            print('  [auto] 定位 recovery root: %s' % c, flush=True)
            return c
    return arg  # 让后续报错暴露真实收到的值


ROOT = resolve_root(sys.argv[1] if len(sys.argv) > 1 else '')


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
        print('ERROR: 目录不存在: %s' % ROOT, file=sys.stderr, flush=True)
        return 1
    print('[postinstall-adb-data] ROOT=%s' % ROOT, flush=True)
    fix_perms()
    make_system_shell()
    fix_file_contexts()
    fix_init_rc()
    # 写一个标记到 ramdisk，验证步骤可直接确认脚本真的作用到了这个目录
    try:
        with open(os.path.join(ROOT, 'phoenix-adbdata-applied'), 'w') as f:
            f.write(ROOT + '\n')
        print('  wrote marker phoenix-adbdata-applied', flush=True)
    except Exception as e:
        print('  !! 写标记失败: %s' % e, file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
