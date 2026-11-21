#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
让 libsepol 在写 v29 策略时丢弃 ioctl 扩展权限节点。

用法：
    python3 ci/patch-libsepol.py rom/external/selinux/libsepol/src/write.c

背景：这颗 3.10 内核的 SELinux 只到策略版本 29，而 Android 8.1 的策略用了
ioctl 扩展权限（v30 特性）。直接 `POLICYVERS := 29` 编译会在这里失败：

    libsepol.avtab_write_item: policy version 29 does not support ioctl
    extendedpermissions rules and one was specified
    Failed to write binary policy: -1

avtab_write() 的结构是「先写节点总数 nel，再逐个写节点」，所以在写单个节点
时直接 return 会破坏计数。正确做法是在写之前把 xperm 节点从哈希桶里摘掉，
同时把 a->nel 减掉。内核本来就不支持这些规则，丢弃后策略依然自洽。
"""
import sys


PATCH = """\tif (p->policyvers < POLICYDB_VERSION_XPERMS_IOCTL) {
\t\t/* 目标内核只支持 v29：丢弃 ioctl 扩展权限节点 */
\t\tfor (i = 0; i < a->nslot; i++) {
\t\t\tavtab_ptr_t *pp = &a->htable[i];
\t\t\twhile (*pp) {
\t\t\t\tif ((*pp)->key.specified & AVTAB_XPERMS) {
\t\t\t\t\t*pp = (*pp)->next;
\t\t\t\t\ta->nel--;
\t\t\t\t} else {
\t\t\t\t\tpp = &(*pp)->next;
\t\t\t\t}
\t\t\t}
\t\t}
\t}

"""


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    path = sys.argv[1]
    s = open(path, encoding='utf-8').read()

    if '丢弃 ioctl 扩展权限节点' in s:
        print('已经打过补丁，跳过')
        return

    anchor = 'static int avtab_write(struct policydb *p, avtab_t * a, struct policy_file *fp)\n{'
    i = s.find(anchor)
    if i < 0:
        sys.exit('找不到 avtab_write，源码结构可能变了')

    j = s.find('if (oldvers) {', i)
    if j < 0:
        sys.exit('找不到 oldvers 分支，源码结构可能变了')

    s = s[:j] + PATCH + s[j:]
    open(path, 'w', encoding='utf-8').write(s)
    print('已给 %s 打补丁：v29 下丢弃 xperm 节点' % path)


if __name__ == '__main__':
    main()
