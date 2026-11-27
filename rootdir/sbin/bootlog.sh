#!/system/bin/sh
# /sbin/bootlog.sh — 由 init 的 bootlog 服务启动（class core，oneshot）
#
# 本文件装到 ramdisk 的 /sbin/（见 device.mk 的 PRODUCT_COPY_FILES），
# 由设备 rc 以 `/system/bin/sh /sbin/bootlog.sh` 方式执行，
# 所以不需要可执行位，但内容必须用 LF 换行。
#
# 为什么不靠 /proc/last_kmsg：它是内核 ram console 的 64 KB 环形缓冲，
# 硬断电 / 拔电池就整块丢失。本项目实测连续两次只拿到全 NUL，正文只剩
# "ram console header, hw_status: 0... header may be corrupted" 这一句头。
# /cache 是 ext4 持久分区，写进去断电不丢。
#
# 第一件事是把「上一轮启动」的内核日志抢救到 /cache —— 那是本次开机之前的
# 最后一次，正好就是要看的那次。之后才刷本轮日志。
#
# 用 cat 而不是 cp：/proc/last_kmsg 的 st_size 是 0，按 size 拷贝只会得到
# 空文件（init 的 copy 内置命令也有同样的问题）；cat 是流式读，能拿全。
#
# 若 /system 没挂上，本脚本根本起不来，init 会在内核日志里留
# "cannot execute" 之类，并且 /cache/gn3002/ 下不会有 dmesg-*.txt
# —— 「没有这些文件」本身就是诊断结论。

DIR=/cache/gn3002
mkdir -p $DIR

# ① 抢救上一轮内核日志 + 本轮最初的现场
cat /proc/last_kmsg > $DIR/last_kmsg-prev.txt 2>/dev/null
cat /proc/cmdline   > $DIR/cmdline.txt 2>/dev/null
mount               > $DIR/mounts-start.txt 2>/dev/null

# ② 本轮日志：20 × 5 秒 ≈ 开机后 100 秒，足够走完 framework 启动
i=0
while [ $i -lt 20 ]; do
    dmesg            > $DIR/dmesg-$i.txt   2>&1
    logcat -d -b all > $DIR/logcat-$i.txt  2>&1
    ps -A            > $DIR/ps-$i.txt      2>&1
    getprop          > $DIR/getprop-$i.txt 2>&1
    i=$((i+1))
    sleep 5
done

dmesg            > $DIR/dmesg-final.txt  2>&1
logcat -d -b all > $DIR/logcat-final.txt 2>&1
ps -A            > $DIR/ps-final.txt     2>&1
mount            > $DIR/mounts-final.txt 2>&1
