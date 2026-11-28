#!/system/bin/sh
# /sbin/bootlog.sh — 由 init 的 bootlog 服务启动（class core）
#
# 三层保险，从"一定看得到"到"最完整"：
#   ① 起步就打一条 /dev/kmsg —— 用来确认本服务到底有没有被启动
#      （2026-11-28 的教训：/data/gn3002 目录建出来了却始终是空的，
#        无法区分"服务没起"和"服务起了但写文件失败"）
#   ② 每轮把 logcat crash 缓冲的**尾部若干行**写进 /dev/kmsg
#      crash 缓冲里就是 native 崩溃（signal 6 / SIGABRT）的直接原因，
#      几百字节足够，塞得进 64 KB 内核环形缓冲
#   ③ 同时尽力把完整日志刷进 /data/gn3002 与 /cache/gn3002
#
# 为什么优先 /data：/cache（p21）挂载在这台机器上不稳定，实测经常一整轮
# checkpoint 一个文件都不剩；/data（p22，25 GB）必须挂上，否则 framework 起不来。
# 目录权限设成 0777：这样在 LineageOS 正常跑着的时候，adbd（shell 用户）
# 也能直接 `adb pull /data/gn3002/` 把日志取出来，不必先关机进 recovery。

DIRS="/data/gn3002 /cache/gn3002"

echo "<3>gn3002: bootlog.sh started (pid $$)" > /dev/kmsg

for d in $DIRS; do
    mkdir -p $d 2>/dev/null
    chmod 0777 $d 2>/dev/null
done

# 选一个真正可写的目录
OUT=""
for d in $DIRS; do
    if touch $d/.w 2>/dev/null; then rm -f $d/.w; OUT=$d; break; fi
done
[ -z "$OUT" ] && { OUT=/tmp/gn3002; mkdir -p $OUT; }
echo "<3>gn3002: bootlog OUT=$OUT" > /dev/kmsg

# ① 抢救上一轮内核日志
cat /proc/last_kmsg > $OUT/last_kmsg-prev.txt 2>/dev/null
cat /proc/mounts    > $OUT/mounts-start.txt 2>/dev/null
echo "started OUT=$OUT" > $OUT/state.txt 2>/dev/null

# ② 主循环：24 轮 × 5 秒 ≈ 120 秒
i=0
while [ $i -lt 24 ]; do
    dmesg                 > $OUT/dmesg-$i.txt    2>&1
    logcat -d -b all      > $OUT/logcat-$i.txt   2>&1
    logcat -d -b crash    > $OUT/crash-$i.txt    2>&1
    ps -A                 > $OUT/ps-$i.txt       2>&1
    cat /proc/mounts      > $OUT/mounts-$i.txt   2>&1
    cat /proc/last_kmsg   > $OUT/lastkmsg-$i.txt 2>&1

    # 把崩溃缓冲的最后几行压成一行写进内核日志（关键：这是唯一必然可见的通道）
    C=$(logcat -d -b crash 2>/dev/null | tail -n 12 | tr '\n' '|' | tr -s ' ' | cut -c1-1500)
    [ -n "$C" ] && echo "<3>gn3002 crash[$i]: $C" > /dev/kmsg

    # surfaceflinger / zygote 相关行也挑几行进内核日志
    S=$(logcat -d -b all 2>/dev/null | grep -iE 'surfaceflinger|zygote|EGL|gralloc|libGLES|FATAL' | tail -n 8 | tr '\n' '|' | cut -c1-1200)
    [ -n "$S" ] && echo "<3>gn3002 sf[$i]: $S" > /dev/kmsg

    i=$((i+1))
    sleep 5
done

dmesg            > $OUT/dmesg-final.txt  2>&1
logcat -d -b all > $OUT/logcat-final.txt 2>&1
echo "<3>gn3002: bootlog.sh finished" > /dev/kmsg
echo "done" >> $OUT/state.txt 2>/dev/null