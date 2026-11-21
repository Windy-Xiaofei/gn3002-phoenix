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
import subprocess
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

    # 锚点：3.10 顶层 Makefile 里 KBUILD_CFLAGS 的第一个赋值，是**续行块**：
    #   KBUILD_CFLAGS   := -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs \
    #                      -fno-strict-aliasing -fno-common \
    #                      ... (若干续行) ...
    #
    # 关键：必须整块匹配到"最后一行不带反斜杠"为止。插在块中间的话，后面
    # 那些缩进的续行会变成孤立的 recipe 行，make 报
    #   Makefile:387: *** recipe commences before first target.  Stop.
    # 用正则一次吃掉整块：(行尾带 \ 的若干行) + (一行不带 \ 的结尾行)。
    m = re.search(
        r'^KBUILD_CFLAGS\s*:=.*?(?<!\\)\n',
        s, re.M | re.S)
    if not m:
        sys.exit('顶层 Makefile 里没找到 KBUILD_CFLAGS，结构变了？')
    # 上面的惰性匹配可能只吃到第一行，再往后吃掉所有续行
    end = m.end()
    while s[:end].rstrip('\r\n').endswith('\\'):
        nl = s.find('\n', end)
        if nl < 0:
            break
        end = nl + 1
    insert_at = end

    # 首选做法：直接交给内核自己的 cc-option 机制。
    # 3.10 的顶层 Makefile 里有 $(call cc-option,-flag,...)，它会真的去编一遍，
    # 不支持的选项返回空。这样"编译器认不认"根本不用我们猜 —— 比在 Python
    # 里另起一个探测进程可靠得多，也不会因为 CROSS_COMPILE 没传进来而失效。
    #
    # 为什么必须这样：GCC 11 上写死 -Wno-error=use-after-free 会让 cc1 直接
    # 报 "no option '-Wuse-after-free'" 然后终止，连编译都起不来。
    #
    # 列表来源：跑一轮 make -k 把所有被 -Werror 顶成 error 的告警收集起来，
    # 3.10 的代码在新 GCC 下会命中的基本都在这里了。
    warn_flags = [
        # GCC 12+ 新增
        '-Wno-error=use-after-free',
        '-Wno-error=dangling-pointer',
        '-Wno-error=stringop-overread',
        # GCC 7~10 陆续加严的
        '-Wno-error=format-truncation',
        '-Wno-error=format-overflow',
        '-Wno-error=array-bounds',
        '-Wno-error=maybe-uninitialized',
        '-Wno-error=stringop-overflow',
        '-Wno-error=tautological-compare',
        '-Wno-error=misleading-indentation',
        '-Wno-error=shift-negative-value',
        # 3.10 的代码在 64 位上本来就有这些老问题，新 GCC 把告警级别调高了
        '-Wno-error=implicit-function-declaration',
        '-Wno-error=int-to-pointer-cast',
        '-Wno-error=pointer-to-int-cast',
        '-Wno-error=address',
        '-Wno-error=unused-but-set-variable',
        '-Wno-error=nonnull',
        '-Wno-error=restrict',
    ]

    warn_lines = '\n'.join(
        'KBUILD_CFLAGS   += $(call cc-option,%s,)' % f for f in warn_flags)

    inject = '''
# --- GN3002_NEW_GCC_COMPAT ------------------------------------------------
# 3.10 是 2016 年的代码，GCC 10+ 编不过。两个来源：
#
# 1. GCC 10 把 -fno-common 改成了默认，多个 .c 里的同名全局变量变成
#    multiple definition。最典型的是 scripts/dtc：
#      /usr/bin/ld: dtc-parser.tab.o:(.bss+0x50): multiple definition
#      of `yylloc'; dtc-lexer.lex.o 先定义
#    -> 加 -fcommon 回到老行为。
#
# 2. 新 GCC 陆续加严的告警把 3.10 的代码顶成 error，例如
#      error: '/input1' directive output may be truncated [-Werror=format-truncation=]
#      error: implicit declaration of function 'dmac_flush_range' [-Werror=implicit-function-declaration]
#      error: cast from pointer to integer of different size [-Werror=pointer-to-int-cast]
#    -> 逐项降级成非错误。
#
#    这里用内核自带的 $(call cc-option,FLAG,) 包一层，而不是直接写死。
#    cc-option 会真的用当前编译器编一个空文件来试，不支持的选项返回空。
#    这一步不能省：GCC 11 上直接写 -Wno-error=use-after-free 会让 cc1 报
#      cc1: error: '-Wno-error=use-after-free': no option '-Wuse-after-free'
#    然后直接终止，连编译都起不来（use-after-free 是 GCC 12 才有的）。
KBUILD_CFLAGS   += -fcommon
%s
# scripts/dtc 是 hostprogs，不吃 KBUILD_CFLAGS，得单独给 HOSTCFLAGS
HOSTCFLAGS      += -fcommon
# -------------------------------------------------------------------------
''' % warn_lines

    s = s[:insert_at] + inject + s[insert_at:]
    open(p, 'w', encoding='utf-8', newline='\n').write(s)
    print('  顶层 Makefile 已加 -fcommon 与 %d 条告警降级（均经 cc-option 过滤）'
          % len(warn_flags))


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
