#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
替换 Android boot.img 的 ramdisk 里某个文件（默认改 sepolicy）。

用法：
    python tools/patch_boot_ramdisk.py 输入boot.img 输出boot.img 源文件 [目标路径]

背景：MT6735 的 3.10.65 内核只认老格式的 SELinux 二进制策略。Android 8.1
编出来的 /sepolicy 虽然版本号也是 30，但里面带了 policycap 之类的新结构，
内核 security_load_policy() 直接返回 EINVAL，init 走 security_failure()
panic 重启进 bootloader。换成原厂 5.1 的 /sepolicy 就能加载，再配合
androidboot.selinux=permissive 跑起来。
"""
import sys
import os
import gzip
import struct


def parse_cpio(buf):
    """返回 [(name, mode, uid, gid, nlink, mtime, data)]，保持原顺序"""
    out = []
    i = 0
    while i < len(buf):
        if buf[i:i + 6] != b'070701':
            raise ValueError('cpio magic 不对，offset=%d' % i)
        h = buf[i:i + 110]
        uint = lambda a, b: int(h[a:b], 16)
        mode, uid, gid, nlink, mtime = uint(14, 22), uint(22, 30), uint(30, 38), uint(38, 46), uint(46, 54)
        filesize, devmajor, devminor = uint(54, 62), uint(62, 70), uint(70, 78)
        rdevmajor, rdevminor = uint(78, 86), uint(86, 94)
        namesize = uint(94, 102)
        name = buf[i + 110:i + 110 + namesize - 1].decode('utf-8', 'replace')
        i += 110 + namesize
        i = (i + 3) & ~3
        data = buf[i:i + filesize]
        i += filesize
        i = (i + 3) & ~3
        out.append((name, mode, uid, gid, nlink, mtime, data, devmajor, devminor, rdevmajor, rdevminor))
        if name == 'TRAILER!!!':
            break
    return out


def build_cpio(entries):
    buf = bytearray()
    ino = 1
    for (name, mode, uid, gid, nlink, mtime, data, dmaj, dmin, rmaj, rmin) in entries:
        nm = name.encode('utf-8') + b'\x00'
        buf += b'070701'
        buf += b'%08X' % ino
        buf += b'%08X' % mode
        buf += b'%08X' % uid
        buf += b'%08X' % gid
        buf += b'%08X' % nlink
        buf += b'%08X' % mtime
        buf += b'%08X' % len(data)
        buf += b'%08X' % dmaj
        buf += b'%08X' % dmin
        buf += b'%08X' % rmaj
        buf += b'%08X' % rmin
        buf += b'%08X' % len(nm)
        buf += b'00000000'
        buf += nm
        while len(buf) % 4:
            buf += b'\x00'
        buf += data
        while len(buf) % 4:
            buf += b'\x00'
        ino += 1
    return bytes(buf)


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    src, dst, newsrc = sys.argv[1], sys.argv[2], sys.argv[3]
    target = sys.argv[4] if len(sys.argv) > 4 else 'sepolicy'

    d = open(src, 'rb').read()
    if d[:8] != b'ANDROID!':
        sys.exit('不是标准 Android boot image')
    f = lambda o: struct.unpack_from('<I', d, o)[0]
    ksz, rsz, ssz, pg = f(8), f(16), f(24), f(36)
    page = pg

    header = bytearray(d[:page])
    kernel = d[page:page + ksz]
    r_off = page + ((ksz + page - 1) // page) * page
    ramdisk = d[r_off:r_off + rsz]
    s_off = r_off + ((rsz + page - 1) // page) * page
    second = d[s_off:s_off + ssz]

    raw = gzip.decompress(ramdisk)
    ents = parse_cpio(raw)

    newdata = open(newsrc, 'rb').read()
    hit = False
    out_ents = []
    for e in ents:
        if e[0] == target:
            out_ents.append((e[0], e[1], e[2], e[3], e[4], e[5], newdata, e[7], e[8], e[9], e[10]))
            hit = True
        else:
            out_ents.append(e)
    if not hit:
        # 插在 TRAILER 之前
        idx = next(i for i, e in enumerate(out_ents) if e[0] == 'TRAILER!!!')
        out_ents.insert(idx, (target, 0o100644, 0, 0, 1, 0, newdata, 0, 0, 0, 0))

    nc = build_cpio(out_ents)
    gz = gzip.compress(nc, 9)

    # 更新头部里的 ramdisk 大小
    struct.pack_into('<I', header, 16, len(gz))

    out = bytearray()
    out += header
    out += kernel
    while len(out) % page:
        out += b'\x00'
    out += gz
    while len(out) % page:
        out += b'\x00'
    if second:
        out += second
        while len(out) % page:
            out += b'\x00'

    open(dst, 'wb').write(out)
    print('已写出:', dst)
    print('  原 ramdisk %d → 新 %d（cpio %d → %d）' % (rsz, len(gz), len(raw), len(nc)))
    print('  镜像 %d 字节（%.2f MB）' % (len(out), len(out) / 1048576))
    print('  被替换的条目: %s' % target)


if __name__ == '__main__':
    main()
