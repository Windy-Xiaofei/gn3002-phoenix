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


def _cc_supports(flag):
    """用交叉编译器编一个空文件，看它认不认这个告警选项。

    比查文档可靠：GCC 的告警选项在不同 minor 版本之间也会增删，
    而且这里用的是发行版打的 cross toolchain，patchlevel 未必和上游一致。
    """
    cc = os.environ.get('CROSS_COMPILE', '') + 'gcc'
    try:
        r = subprocess.run(
            [cc, '-Werror', flag, '-x', 'c', '-c', '-o', os.devnull, '-'],
            input='int main(void){return 0;}\n',
            capture_output=True, text=True, timeout=30)
        return r.returncode == 0
    except Exception:
        return False


def _cc_version():
    """返回交叉编译器的主版本号；拿不到就当 0。"""
    cc = os.environ.get('CROSS_COMPILE', '') + 'gcc'
    try:
        r = subprocess.run([cc, '-dumpversion'], capture_output=True, text=True, timeout=30)
        if r.returncode == 0 and r.stdout.strip():
            return int(r.stdout.strip().split('.')[0])
    except Exception:
        pass
    return 0


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

    # 告警降级不能写死：GCC 版本之间这些选项的可用性差别很大。
    # 实测 GCC 11 上直接写 -Wno-error=use-after-free 会让 cc1 直接报错退出：
    #   cc1: error: '-Wno-error=use-after-free': no option '-Wuse-after-free'
    # （use-after-free 是 GCC 12 才加的，dangling-pointer 也是）。
    # 所以这里先探测，只保留编译器认识的。
    candidates = [
        '-Wno-error=use-after-free',
        '-Wno-error=dangling-pointer',
        '-Wno-error=array-bounds',
        '-Wno-error=maybe-uninitialized',
        '-Wno-error=stringop-overflow',
        '-Wno-error=stringop-overread',
        '-Wno-error=address',
        '-Wno-error=tautological-compare',
        '-Wno-error=misleading-indentation',
        '-Wno-error=shift-negative-value',
    ]
    supported = [f for f in candidates if _cc_supports(f)]
    dropped = [f for f in candidates if f not in supported]

    # 一个都没探测到，通常是编译器根本不在这台机器上（脚本单独跑的场景）。
    # 这时不要静默退化成"只有 -fcommon"。但也不能乱猜：老编译器（GCC 9 以下）
    # 可能根本不认识这些告警，加了反而让 cc1 直接报错。
    # 折中：只探测编译器版本，GCC >= 10 才用保守默认（-fno-common 是 GCC 10
    # 才改成默认的，只有这一代以上才需要这些降级）。
    if not supported:
        ver = _cc_version()
        if ver >= 10:
            print('  没探测到告警选项，但编译器是 GCC %d，用保守默认' % ver)
            supported = [
                '-Wno-error=array-bounds',
                '-Wno-error=maybe-uninitialized',
                '-Wno-error=stringop-overflow',
            ]
            dropped = [f for f in candidates if f not in supported]
        else:
            print('  编译器是 GCC %d，不需要告警降级（只需 -fcommon）' % ver)
            dropped = list(candidates)

    print('  编译器认识的告警选项:', ', '.join(supported) if supported else '(无)')
    if dropped:
        print('  跳过不支持的:', ', '.join(dropped))

    warn_lines = '\n'.join('KBUILD_CFLAGS   += %s' % f for f in supported)

    inject = '''
# --- GN3002_NEW_GCC_COMPAT ------------------------------------------------
# 3.10 是 2016 年的代码，GCC 10+ 编不过。两个来源：
#   1. -fno-common 成了默认，多个 .c 里的同名全局变量变成 multiple
#      definition（scripts/dtc 的 yylloc 最典型）-> 加 -fcommon；
#   2. 新增的告警把 -Werror 顶掉 -> 逐项降级为非错误。
#      注意绝不能写死列表：GCC 11 上 '-Wno-error=use-after-free' 会让 cc1
#      直接报 "no option"，连编译都起不来。这里只用探测通过的选项。
KBUILD_CFLAGS   += -fcommon
%s
# scripts/dtc 是 hostprogs，不吃 KBUILD_CFLAGS，得单独给 HOSTCFLAGS
HOSTCFLAGS      += -fcommon
# -------------------------------------------------------------------------
''' % warn_lines

    s = s[:insert_at] + inject + s[insert_at:]
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
