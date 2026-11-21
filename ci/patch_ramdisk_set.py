#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量替换 boot.img ramdisk 里的多个条目。

用法：
    python tools/patch_ramdisk_set.py 输入boot.img 输出boot.img 清单文件

清单文件每行 "<ramdisk 内路径> <本地文件>"，本地文件不存在或写 "-" 表示置空。

用途：Android 8.1 的 SELinux 标签表引用了大量 5.1 策略里没有的类型，
内核 setxattr 会返回 EINVAL，init 的 restorecon 是致命错误。把整套上下文表
换回原厂 5.1 的，标签才都能解析。
"""
import sys
import os
import gzip
import struct

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patch_boot_ramdisk import parse_cpio, build_cpio  # noqa: E402


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    src, dst, manifest = sys.argv[1], sys.argv[2], sys.argv[3]

    mapping = {}
    with open(manifest, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            name = parts[0]
            path = parts[1] if len(parts) > 1 else '-'
            mapping[name] = b'' if path in ('-', '') else open(path, 'rb').read()

    d = open(src, 'rb').read()
    if d[:8] != b'ANDROID!':
        sys.exit('不是标准 Android boot image')
    f = lambda o: struct.unpack_from('<I', d, o)[0]
    ksz, rsz, ssz, pg = f(8), f(16), f(24), f(36)

    header = bytearray(d[:pg])
    kernel = d[pg:pg + ksz]
    r_off = pg + ((ksz + pg - 1) // pg) * pg
    ramdisk = d[r_off:r_off + rsz]
    s_off = r_off + ((rsz + pg - 1) // pg) * pg
    second = d[s_off:s_off + ssz]

    ents = parse_cpio(gzip.decompress(ramdisk))
    out = []
    done = set()
    for e in ents:
        if e[0] in mapping:
            out.append((e[0], e[1], e[2], e[3], e[4], e[5], mapping[e[0]], e[7], e[8], e[9], e[10]))
            done.add(e[0])
        else:
            out.append(e)
    for name in mapping:
        if name not in done:
            idx = next(i for i, e in enumerate(out) if e[0] == 'TRAILER!!!')
            out.insert(idx, (name, 0o100644, 0, 0, 1, 0, mapping[name], 0, 0, 0, 0))
            done.add(name)

    nc = build_cpio(out)
    gz = gzip.compress(nc, 9)
    struct.pack_into('<I', header, 16, len(gz))

    # 重算头部的 id（SHA1），算法同 mkbootimg：
    #   sha1(kernel || len(kernel) || ramdisk || len(ramdisk)
    #        || second || len(second) || extra_cmdline)
    # 改了 ramdisk 而不更新它，部分 bootloader 会认为镜像损坏直接拒绝启动。
    import hashlib
    extra = bytes(d[608:608 + 1024]).split(b'\x00')[0]
    sha = hashlib.sha1()
    sha.update(kernel)
    sha.update(struct.pack('<I', len(kernel)))
    sha.update(gz)
    sha.update(struct.pack('<I', len(gz)))
    sha.update(second)
    sha.update(struct.pack('<I', len(second)))
    sha.update(extra)
    header[576:596] = sha.digest()
    header[596:608] = b'\x00' * 12

    buf = bytearray()
    buf += header
    buf += kernel
    while len(buf) % pg:
        buf += b'\x00'
    buf += gz
    while len(buf) % pg:
        buf += b'\x00'
    if second:
        buf += second
        while len(buf) % pg:
            buf += b'\x00'

    open(dst, 'wb').write(buf)
    print('已写出:', dst)
    print('  镜像 %d 字节 (%.2f MB)' % (len(buf), len(buf) / 1048576))
    print('  替换/新增条目 %d 个:' % len(done))
    for k in sorted(done):
        print('    %-26s %8d 字节' % (k, len(mapping[k])))


if __name__ == '__main__':
    main()
