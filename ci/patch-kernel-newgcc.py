#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
让 3.10 的内核能在现代 GCC（10/11/12/13）上编过。

这一步和 binder 的改动无关，纯粹是"2016 年的内核遇上 2024 年的编译器"。
Ubuntu 22.04 的 aarch64-linux-gnu-gcc 是 11.4，直接编 3.10 会撞两个墙：

1. include/linux/compiler-gcc.h 里是

       #include <linux/compiler-gcc##__GNUC__##.h>

   3.10 只带 compiler-gcc3.h / gcc4.h ... 到 gcc4.h 一类，没有 gcc11.h，
   于是 fatal error: linux/compiler-gcc11.h: No such file or directory。

   修法：生成一个 compiler-gccN.h（N = __GNUC__），内容按版本分支：
     - GCC >= 5  没有 __visible 之前的写法差异，直接 include gcc4.h 的内容
     - 但要补上 3.10 缺的 attribute 宏（__latent_entropy 之类用不到，
       实际只需要保证 include 链能走通）

2. GCC 10 起默认 -fno-common，多个 .c 里的同名全局变量会变成
   multiple definition。最典型的是 scripts/dtc 的

       /usr/bin/ld: dtc-parser.tab.o:(.bss+0x50):
       multiple definition of `yylloc'; dtc-lexer.lex.o 先定义

   修法：给编译加 -fcommon。加在 KCFLAGS / HOSTCFLAGS 都行，
   但 scripts/dtc 是 hostprogs，走 HOSTCFLAGS。

顺带处理第三个问题（GCC 12+ 才会遇到，一并写进来）：
   -Werror=use-after-free / -Warray-bounds 之类新增告警会把 -Werror 顶掉，
   3.10 的代码通不过。直接关掉这些新告警。

用法：
    python3 ci/patch-kernel-newgcc.py <kernel-dir>
"""
import os
import re
import sys


def write_compat_header(kdir):
    """生成 compiler-gccN.h，N 是当前交叉编译器的 __GNUC__。"""
    dst_dir = os.path.join(kdir, 'include', 'linux')
    if not os.path.isdir(dst_dir):
        sys.exit('找不到 %s，内核目录不对？' % dst_dir)

    # 3.10 里最高只到 compiler-gcc4.h，内容对 GCC 5+ 依然适用
    # （__visible / __noclone 那些宏的定义没变过）。
    tmpl = '''#ifndef __LINUX_COMPILER_H
#error "Please don't include <linux/compiler-gcc%(N)s.h> directly, include <linux/compiler.h> instead."
#endif

/* 3.10 只带 compiler-gcc4.h。GCC 5 之后 GCC 特有的宏集合没有再变，
 * 所以这里直接复用 gcc4.h 的内容，再补上 3.10 之后新增、但 3.10 的
 * 头文件里没有引用的几个（留着空定义，避免二次 include 出问题）。 */
#include <linux/compiler-gcc4.h>

#define __visible	__attribute__((externally_visible))
#define __noclone	__attribute__((__noclone__))

#define __latent_entropy
#define __no_sanitize_address
'''
    written = []
    for n in (11, 12, 13, 14, 15):
        p = os.path.join(dst_dir, 'compiler-gcc%d.h' % n)
        if os.path.exists(p):
            continue
        with open(p, 'w', encoding='utf-8', newline='\n') as f:
            f.write(tmpl % {'N': n})
        written.append(os.path.basename(p))
    print('  生成兼容头文件:', ', '.join(written) if written else '(已存在，跳过)')


def patch_top_makefile(kdir):
    """给顶层 Makefile 追加 -fcommon 和告警降级。"""
    p = os.path.join(kdir, 'Makefile')
    s = open(p, encoding='utf-8', errors='replace').read()

    if 'GN3002_NEW_GCC_COMPAT' in s:
        print('  顶层 Makefile 已处理，跳过')
        return

    # 找一个稳定的锚点：3.10 顶层 Makefile 里有一句
    #   KBUILD_CFLAGS   := -Wall -Wundef -Wstrict-prototypes ...
    # 注意 := 前面可能有多个空格，要用 \s* 而不是固定空格。
    m = re.search(r'^KBUILD_CFLAGS\s*:=.*$', s, re.M)
    if not m:
        sys.exit('顶层 Makefile 里没找到 KBUILD_CFLAGS，结构变了？')

    inject = m.group(0) + '''
# --- GN3002_NEW_GCC_COMPAT ------------------------------------------------
# 3.10 是 2016 年的代码，GCC 10+ 编不过。三处都是编译器换代带来的：
#   1. -fno-common 成了默认，多个 .c 里的同名全局变量变成 multiple
#      definition（scripts/dtc 的 yylloc 最典型）；
#   2. 新增的 -Wuse-after-free / -Warray-bounds 等告警把 -Werror 顶掉；
#   3. -Wmaybe-uninitialized 在 3.10 的代码里命中太多。
KBUILD_CFLAGS   += -fcommon
KBUILD_CFLAGS   += -Wno-error=use-after-free -Wno-error=array-bounds
KBUILD_CFLAGS   += -Wno-error=maybe-uninitialized -Wno-error=dangling-pointer
KBUILD_CFLAGS   += -Wno-error=stringop-overflow -Wno-error=stringop-overread
# scripts/dtc 是 hostprogs，不吃 KBUILD_CFLAGS，得单独给 HOSTCFLAGS
HOSTCFLAGS      += -fcommon
# -------------------------------------------------------------------------
'''
    s = s.replace(m.group(0), inject, 1)
    open(p, 'w', encoding='utf-8', newline='\n').write(s)
    print('  顶层 Makefile 已加 -fcommon 与告警降级')


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    kdir = sys.argv[1]
    write_compat_header(kdir)
    patch_top_makefile(kdir)
    print('完成: 3.10 内核已适配现代 GCC')


if __name__ == '__main__':
    main()
