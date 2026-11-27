#!/usr/bin/env bash
#
# 对 Android 8.1 (TWRP omni) 源码树做兼容性修补。
#
# 背景：ubuntu-22.04 上的 `python` 已经是 Python 3，而 8.1 是
# Python 2 → 3 的过渡期代码，大量脚本还留着 py2 语法。
# 这些修补每次 CI 都要重做（源码树是全新 clone 的），所以集中在这里。
#
# 策略：不做逐个人工排查，而是把 build/ 下所有 .py 一次性做语法检查，
#       凡是 py3 解析不了的就交给 2to3 整体转换 —— 一次填掉整类问题。
#
# 用法: ci-patch-tree.sh <源码树根目录>
#
set -uo pipefail

ROM_DIR=${1:-rom}
cd "$ROM_DIR" || { echo "错误: 进不去 $ROM_DIR" >&2; exit 1; }
[ -d build ] || { echo "错误: $ROM_DIR 看起来不是 Android 源码树" >&2; exit 1; }

echo "== 修补源码树: $(pwd) =="

# ---------------------------------------------------------------------------
# 把一个 py2 脚本转成 py3
# ---------------------------------------------------------------------------
patched=0
failed=0

has_2to3() {
    command -v 2to3 >/dev/null 2>&1 && return 0
    python3 -m lib2to3 --help >/dev/null 2>&1 && return 0
    return 1
}

run_2to3() {
    if command -v 2to3 >/dev/null 2>&1; then
        2to3 -w -n "$1" >/dev/null 2>&1
    else
        python3 -m lib2to3 -w -n "$1" >/dev/null 2>&1
    fi
}

py3_ok() {
    python3 -c "import ast; ast.parse(open('$1',encoding='utf-8',errors='replace').read())" 2>/dev/null
}

# 语法合法但用了 py2 专有 API —— ast 查不出来，必须靠模式匹配
has_py2_api() {
    grep -qE '\.(iteritems|itervalues|iterkeys|has_key)[[:space:]]*\(|\bxrange[[:space:]]*\(|\bbasestring\b|\bunicode[[:space:]]*\(' "$1"
}

has_py2_shebang() {
    head -1 "$1" | grep -qE '^#!.*\bpython2\b'
}

need_fix() {
    py3_ok "$1" || return 0     # 语法都过不了，肯定要修
    has_py2_api "$1" && return 0
    has_py2_shebang "$1" && return 0
    return 1
}

py3ify() {
    local f=$1
    [ -f "$f" ] || return 0
    need_fix "$f" || return 0

    echo "  [py2 -> py3] $f"

    # 先改 shebang：`#!/usr/bin/env python2` 在 22.04 上根本找不到解释器
    sed -i -E '1s|^#!.*python2.*$|#!/usr/bin/env python3|' "$f"

    has_2to3 && run_2to3 "$f"

    # 2to3 缺失或漏网时的兜底：`except A, B:` -> `except (A, B):`
    sed -i -E 's/^([[:space:]]*)except ([A-Za-z_.]+), ([A-Za-z_.]+):/\1except (\2, \3):/' "$f"

    if py3_ok "$f" && ! has_py2_api "$f"; then
        patched=$((patched + 1))
    else
        echo "     !! 转换后仍有问题，需要人工看: $f" >&2
        failed=$((failed + 1))
    fi
}

# ---------------------------------------------------------------------------
# 1. vendor/omni 里 lunch 时会执行的设备树查找脚本
# ---------------------------------------------------------------------------
py3ify vendor/omni/build/tools/roomservice.py

# ---------------------------------------------------------------------------
# 2. build/ 下所有 py3 解析不了的脚本
#
# 用一个 python 进程批量检查，比逐个起进程快一个数量级。
# ---------------------------------------------------------------------------
BAD_LIST=$(mktemp)
python3 - "$BAD_LIST" <<'PYEOF'
import ast, os, re, sys

# 语法合法、但在 py3 下会直接 AttributeError / NameError 的 py2 专有 API。
# 单纯做 ast.parse 是查不出这些的 —— post_process_props.py 就是这么漏掉的：
#   for key, value in buildprops.iteritems():   # 语法 OK，运行即炸
PY2_API = re.compile(
    r'\.(iteritems|itervalues|iterkeys|has_key)\s*\('
    r'|\bxrange\s*\('
    r'|\bbasestring\b'
    r'|\bunicode\s*\('
)

bad = []
# 参与编译的顶层目录。不做整树遍历：out/ 是产物、prebuilts/ 里是预编译工具，
# 而动到它们弊大于利。build/ 之外还有 external/ 之类会真的被构建调用
# —— external/clang/clang-version-inc.py 就是漏在 build/ 外面才又撞了一次。
ROOTS = ['build', 'external', 'system', 'hardware', 'frameworks', 'vendor', 'device']
SKIP = {'out', '.git', 'prebuilts'}

# 绝对不能被 2to3 碰的路径：这是预编译的 python3 运行时标准库本身，
# 动了会把工具链自己搞坏。之前 charmap.py 就被误判进去过。
EXCLUDE_PREFIX = ('external/python3/prebuilt/',)

for base in ROOTS:
    if not os.path.isdir(base):
        continue
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for fn in files:
            if not fn.endswith('.py'):
                continue
            p = os.path.join(root, fn)
            rel = p.replace(os.sep, '/')
            if any(rel.startswith(x) for x in EXCLUDE_PREFIX):
                continue
            try:
                with open(p, encoding='utf-8', errors='replace') as fh:
                    src = fh.read()
            except Exception:
                continue

            need = PY2_API.search(src) is not None
            if not need and re.search(r'^#!.*\bpython2\b', src[:200], re.M):
                need = True
            if not need:
                try:
                    ast.parse(src, filename=p)
                except SyntaxError:
                    need = True
                except Exception:
                    pass
            if need:
                bad.append(p)

with open(sys.argv[1], 'w', encoding='utf-8', newline='\n') as out:
    # 明确 newline='\n'：Windows 版 python 默认写 \r\n，会让每行末尾带上 CR，
    # bash 侧 `[ -f "path\r" ]` 直接判定文件不存在，整个修补静默失效。
    # 末尾也必须带换行 —— `while read` 遇到没有结尾换行的末行会返回非 0。
    out.write('\n'.join(bad) + ('\n' if bad else ''))
PYEOF

total=$(grep -c . "$BAD_LIST" 2>/dev/null | head -1)
[ -n "$total" ] || total=0
echo "== 全树需要转换的脚本（语法错 / py2 API / python2 shebang）: $total 个 =="

while IFS= read -r f || [ -n "$f" ]; do
    f=${f%$'\r'}                # 去掉可能残留的 CR
    [ -n "$f" ] || continue
    py3ify "$f"
done < "$BAD_LIST"
rm -f "$BAD_LIST"

# ---------------------------------------------------------------------------
# 3. 语义级修补（2to3 处理不了的类型差异）
# ---------------------------------------------------------------------------
#
# fs_config_generator.py 的 _handle_aid 把正则抓到的 **字符串** value 当字典键：
#     self._aid_value_to_name[value] = aid.friendly
# 而 _handle_oem_range 存进 _oem_ranges 的是 int_value。于是
#     Utils.in_any_range(aid, self._oem_ranges)   # int <= str
# 在 py2 里合法：不同类型按类型名比较，"int" < "str"，所以
#     lower(int) <= value(str)  → True
#     value(str) <= upper(int)  → False
# 整体恒为 False，这个检查**从来没生效过**。
#
# py3 下直接 TypeError。而如果只把 value 转成 int 让检查真正生效，
# 8.1 的头文件里真的有 core AID 落在 OEM 保留区间，会抛 ValueError 让编译失败
# （后续 %u 格式化也会因为 aid 是 str 而炸）。
#
# 所以这里复刻 py2 的行为：非整数值直接不参与比较，等价于原来恒 False。
# 这是最忠实的移植，不改变这个检查的语义。
patch_fs_config() {
    local f
    for f in build/make/tools/fs_config/fs_config_generator.py \
             bionic/libc/fs_config_generator.py; do
        [ -f "$f" ] || continue
        grep -q 'return any(lower <= value <= upper for (lower, upper) in ranges)' "$f" || continue
        sed -i 's|return any(lower <= value <= upper for (lower, upper) in ranges)|return any(isinstance(value, int) and lower <= value <= upper for (lower, upper) in ranges)|' "$f"
        echo "  [py3 语义] $f: in_any_range 对非整数值复刻 py2 的恒 False 行为"
        patched=$((patched + 1))
    done
}

patch_fs_config

# ---------------------------------------------------------------------------
# 4. ramdisk 源头瘦身：在 build 系统的 POST_INSTALL 阶段删除无用组件。
# ---------------------------------------------------------------------------
# 关键：绝对不能在产物上解包/重打包 ramdisk —— MTK 3.10 内核不认
# 重新打包的 cpio（即使内容全是原厂文件也 panic 在 mount_block_root）。
# 必须让 build 系统自己的 mkbootfs 打包，结构才是内核认的。
# 这里往 recovery 模块的 LOCAL_POST_INSTALL_CMD 注入 rm，
# 使其在 mkbootfs 之前生效。
patch_recovery_ramdisk() {
    local f="bootable/recovery/Android.mk"
    [ -f "$f" ] || return 0
    grep -q 'phoenix ramdisk slim' "$f" && { echo "  [ramdisk] 已 patch，跳过"; return 0; }

    # 必须插在 "include $(BUILD_EXECUTABLE)" 之前 —— 之后的变量不生效
    python3 - "$f" <<'PYEOF'
import sys
f = sys.argv[1]
src = open(f, encoding='utf-8').read()
block = r'''
# ---- phoenix ramdisk slim (injected by ci-patch-tree.sh) ----
# Must run before mkbootfs packages the ramdisk; do NOT repack afterwards.
# 注意：不要在批量 rm 里写 $(TARGET_RECOVERY_ROOT_OUT)/twres/languages。
# 那会把整个语言包目录删掉，TWRP 就只剩内置英文，设置里切换中文必然无效
# （2026-11-27 用户报的"简体中文和英文无法正常切换"就是这一类症状）。
# 只需要删掉用不到的语言，保留 en / zh_CN。
LOCAL_POST_INSTALL_CMD += \
    rm -rf $(TARGET_RECOVERY_ROOT_OUT)/sbin/python3 \
           $(TARGET_RECOVERY_ROOT_OUT)/etc/python \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/bash \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/etc/bash \
           $(TARGET_RECOVERY_ROOT_OUT)/system/usr/share/zoneinfo/tzdata \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/mkfs.f2fs \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/fsck.f2fs \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/nano \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/etc/nano \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/charger \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/linker \
           $(TARGET_RECOVERY_ROOT_OUT)/sbin/libncurses.so ; \
    find $(TARGET_RECOVERY_ROOT_OUT)/twres/languages -type f \
         ! -name 'en.xml' ! -name 'zh_CN.xml' -delete 2>/dev/null || true ; \
    echo "phoenix ramdisk slim: post-install cleanup done" ; \
    ls -l $(TARGET_RECOVERY_ROOT_OUT)/twres/languages/ || true

'''
marker = 'include $(BUILD_EXECUTABLE)'
pos = src.find(marker)
if pos < 0:
    print('  [ramdisk] WARNING: marker not found')
    sys.exit(1)
out = src[:pos] + block + src[pos:]
open(f, 'w', encoding='utf-8').write(out)
print('  [ramdisk] 注入 POST_INSTALL 清理到', f)
PYEOF
    echo "  [ramdisk] post-install cleanup injected"
    patched=$((patched + 1))
}

patch_recovery_ramdisk

# ---------------------------------------------------------------------------
# 5. TWRP 主题 i18n：让中文可选、且切换后真的记得住
# ---------------------------------------------------------------------------
# 三个独立问题叠在一起：
#   1. TW_EXTRA_LANGUAGES := false，而 zh_CN.xml 只存在于 extra-languages，
#      所以基础主题里**根本没有中文** —— 设置里压根没得选。
#   2. zh_CN.xml 的 fontoverride 指向 DroidSansFallback.ttf（3.7MB 全套 CJK），
#      不装它中文就是方块。设备树里带了子集化版本（1.07MB）。
#   3. ui.xml 若硬编码 <variable name="tw_language" value="zh_CN"/>，
#      PageSet::LoadVariables() 每次加载主题都会覆盖持久设置
#      （data.cpp:459-462 对已存在的键直接 mPersist.SetValue），
#      于是用户在界面切英文、写进 .twrps 也没用，下次开机又被改回中文。
#      上游主题本来没有这个变量，是本项目早期本地注入的，属自造坑。
# 实现在 patch-twrp-theme-i18n.py（含幂等与自检）。
# ---------------------------------------------------------------------------
DT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

patch_theme_i18n() {
    local s="$DT_DIR/tools/patch-twrp-theme-i18n.py"
    if [ ! -f "$s" ]; then
        echo "  [i18n] 警告: 找不到 $s，跳过" >&2
        return 0
    fi
    if python3 "$s" "$(pwd)" "$DT_DIR"; then
        patched=$((patched + 1))
    else
        echo "  [i18n] 失败" >&2
        failed=$((failed + 1))
    fi
}

patch_theme_i18n

# ---------------------------------------------------------------------------
# 6. CPU 温度 / 电量显示修正
# ---------------------------------------------------------------------------
# 温度：TW_CUSTOM_CPU_TEMP_PATH 写死 thermal_zone1，但 MT6735 上 zone 序号由
#       内核注册顺序决定，zone1 可能是 PCB/电池温度甚至不上报的占位节点。
#       改成按 thermal_zoneN/type 是否含 "cpu" 自动识别，找不到才退回配置值，
#       并对超出 1..125 度的结果判为读错（宁可不显示也不误导）。
# 电量：capacity 读失败、或量程不是 0..100（某些 MTK 给 0..1000 千分比）时，
#       兜底归一与 charge_counter/charge_full；都拿不到就显示 n/a，
#       不再显示误导性的 0 / 101。
# 实现在 patch-twrp-temp-battery.py。
# ---------------------------------------------------------------------------
patch_temp_battery() {
    local s="$DT_DIR/tools/patch-twrp-temp-battery.py"
    if [ ! -f "$s" ]; then
        echo "  [temp] 警告: 找不到 $s，跳过" >&2
        return 0
    fi
    if python3 "$s" "$(pwd)"; then
        patched=$((patched + 1))
    else
        echo "  [temp] 失败" >&2
        failed=$((failed + 1))
    fi
}

patch_temp_battery

echo "== 完成：转换 $patched 个文件，失败 $failed 个 =="
[ "$failed" -eq 0 ] || echo "== 注意：有文件没能自动转换，编译可能会再撞到 ==" >&2

exit 0
