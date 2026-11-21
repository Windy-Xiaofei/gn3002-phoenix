#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 8.1 init 里两处「内核太旧就 panic」的硬化检查降级为警告。

用法：
    python3 ci/patch-init.py rom/system/core/init/init.cpp

背景：Android 8.1 的 init 在启动早期会调用：
  - set_mmap_rnd_bits_action()  写 /proc/sys/vm/mmap_rnd_bits
  - set_kptr_restrict_action()  写 /proc/sys/kernel/kptr_restrict
写不进去就 security_failure() → panic 重启进 bootloader。

3.10.65 内核没有 /proc/sys/vm/mmap_rnd_bits（4.1 才引入），于是必然 panic：
    init: Cannot open for reading: /proc/sys/vm/mmap_rnd_bits
    init: Unable to set adequate mmap entropy value!
    init: Security failure...

这两项是 ASLR / 内核指针泄露的加固措施，老内核上做不了，跳过即可。
"""
import sys


REPLACEMENTS = [
    (
        '''        LOG(ERROR) << "Unable to set adequate mmap entropy value!";
        security_failure();''',
        '''        // 3.10 内核没有 mmap_rnd_bits，跳过这项加固，不要 panic
        LOG(WARNING) << "Unable to set adequate mmap entropy value! (old kernel, ignored)";''',
    ),
    (
        '''        LOG(ERROR) << "Unable to set adequate kptr_restrict value!";
        security_failure();''',
        '''        LOG(WARNING) << "Unable to set adequate kptr_restrict value! (old kernel, ignored)";''',
    ),
]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    path = sys.argv[1]
    s = open(path, encoding='utf-8').read()

    changed = 0
    for old, new in REPLACEMENTS:
        if old in s:
            s = s.replace(old, new)
            changed += 1
        elif new in s:
            pass  # 已经打过
        else:
            print('警告：没找到待替换片段（源码可能变了）：', old.split('\n')[0].strip())

    open(path, 'w', encoding='utf-8').write(s)
    print('init.cpp 已处理 %d 处' % changed)


if __name__ == '__main__':
    main()
