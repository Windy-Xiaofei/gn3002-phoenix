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


def link_mach_headers(kdir):
    """建 arch/arm64/include/mach 软链。

    MTK 的源码树把自己那堆 mach 头文件放在
        drivers/misc/mediatek/mach/<soc>/include/mach/
    然后让 arch/<arch>/include/mach 指向它。这个软链是 MTK 的构建脚本
    （build.sh / mk_xxx.pl）创建的，直接 git clone 下来是没有的。

    缺了它的症状：
        include/mach/mtk_rtc.h:6:10: fatal error:
            mach/mt_typedefs.h: No such file or directory
    """
    arch = os.path.join(kdir, 'arch', 'arm64', 'include')
    if not os.path.isdir(arch):
        sys.exit('找不到 %s，内核目录不对？' % arch)

    link = os.path.join(arch, 'mach')
    # 软链建在 <kdir>/arch/arm64/include/ 里，要回到 <kdir> 需要向上三层：
    #   .../include -> .../arm64 -> .../arch -> <kdir>
    target_rel = '../../../drivers/misc/mediatek/mach/mt6735/include/mach'

    # 目标目录必须真的存在，否则软链建了也是断的
    real_target = os.path.normpath(os.path.join(arch, target_rel))
    if not os.path.isdir(real_target):
        print('  警告: %s 不存在，跳过 mach 软链' % real_target)
        return

    if os.path.islink(link) or os.path.exists(link):
        print('  mach 软链已存在，跳过')
        return

    # Windows 上建软链需要管理员权限，CI 跑在 Linux 所以没问题
    try:
        os.symlink(target_rel, link)
        print('  已建 arch/arm64/include/mach -> %s' % target_rel)
    except OSError as e:
        print('  警告: 建软链失败(%s)，改用复制' % e)
        import shutil
        shutil.copytree(real_target, link)


def fix_alarmtimer(kdir):
    """修 kernel/time/alarmtimer.c 里 MTK 注释掉声明却还留着使用的地方。

    MTK 把这三行注释掉了（含 rtctimer 的声明与启动）：
        /* rtc_timer_cancel(alarm_rtc_dev, &rtctimer);
           now = rtc_tm_to_ktime(alm.time);
           rtc_timer_start(alarm_rtc_dev, &rtctimer, now, ktime_set(0, 0)); */
    但紧接着的 rtc_timer_cancel(alarm_rtc_dev, &rtctimer) 没注释，
    于是 rtctimer 未声明：

        kernel/time/alarmtimer.c:177:42: error: 'rtctimer' undeclared

    这是源码自己的 bug，不是编译器换代导致的，-Wno-error 救不了。
    处理：把那一行也一并注释掉（保留 MTK 原本的意图）。
    """
    p = os.path.join(kdir, 'kernel', 'time', 'alarmtimer.c')
    if not os.path.exists(p):
        print('  警告: 找不到 %s，跳过' % p)
        return
    s = open(p, encoding='utf-8', errors='replace').read()

    if 'GN3002_FIXED_RTCTIMER' in s:
        print('  alarmtimer 已修过，跳过')
        return

    bad = '\trtc_timer_cancel(alarm_rtc_dev, &rtctimer);\n\trtc_set_alarm(alarm_rtc_dev, &alm);'
    if bad not in s:
        print('  警告: alarmtimer.c 里没找到预期的片段，跳过')
        return

    good = ('\t/* GN3002_FIXED_RTCTIMER: MTK 把 rtctimer 的声明注释掉了，\n'
            '\t * 这一行却留着用，必然 rtctimer undeclared。一并注掉。 */\n'
            '\t/* rtc_timer_cancel(alarm_rtc_dev, &rtctimer); */\n'
            '\trtc_set_alarm(alarm_rtc_dev, &alm);')
    s = s.replace(bad, good, 1)
    open(p, 'w', encoding='utf-8', newline='\n').write(s)
    print('  已修 alarmtimer.c 的 rtctimer 未声明')


def fix_rt_rq(kdir):
    """修 kernel/sched/rt.c 里 MTK 调试代码引用 rt_rq->rq 的问题。

    MTK 在 sched_rt_runtime_exceeded() 里加了一段 printk 调试输出：

        struct rt_bandwidth *rt_b = sched_rt_bandwidth(rt_rq);
        int cpu = rq_cpu(rt_rq->rq);
        printk_deferred("sched: cpu=%d rt_time ...", cpu, ...);

    `rt_rq->rq` 这个字段在上游早被删掉了（现在是 rq_of_rt_rq() 系列辅助函数），
    所以：

        kernel/sched/rt.c:1084:39: error: 'struct rt_rq' has no member named 'rq'

    这段是**无条件**的（不在 CONFIG_RT_GROUP_SCHED 里），所以关配置没用。

    处理：cpu 号只用于调试打印，直接用 raw_smp_processor_id() 代替 ——
    这段代码本身在持有 rq->lock 的上下文里跑，当前 CPU 就是它关心的那个。
    """
    p = os.path.join(kdir, 'kernel', 'sched', 'rt.c')
    if not os.path.exists(p):
        print('  警告: 找不到 %s，跳过' % p)
        return
    s = open(p, encoding='utf-8', errors='replace').read()

    if 'GN3002_FIXED_RT_RQ' in s:
        print('  rt.c 已修过，跳过')
        return

    bad = '\t\tint cpu = rq_cpu(rt_rq->rq);'
    if bad not in s:
        print('  警告: rt.c 里没找到 rq_cpu(rt_rq->rq)，跳过')
        return

    good = ('\t\t/* GN3002_FIXED_RT_RQ: rt_rq->rq 上游已删除，'
            'cpu 号只用于这条调试打印，\n'
            '\t\t * 用 raw_smp_processor_id() 代替（此处持有 rq->lock）。 */\n'
            '\t\tint cpu = raw_smp_processor_id();')
    s = s.replace(bad, good, 1)
    open(p, 'w', encoding='utf-8', newline='\n').write(s)
    print('  已修 rt.c 的 rt_rq->rq')


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
    link_mach_headers(kdir)
    fix_alarmtimer(kdir)
    fix_rt_rq(kdir)
    patch_top_makefile(kdir)
    print('完成: 3.10 内核已适配现代 GCC')


if __name__ == '__main__':
    main()
