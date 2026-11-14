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

for base in ROOTS:
    if not os.path.isdir(base):
        continue
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for fn in files:
            if not fn.endswith('.py'):
                continue
            p = os.path.join(root, fn)
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

total=$(grep -c . "$BAD_LIST" 2>/dev/null || echo 0)
echo "== 全树需要转换的脚本（语法错 / py2 API / python2 shebang）: $total 个 =="

while IFS= read -r f || [ -n "$f" ]; do
    f=${f%$'\r'}                # 去掉可能残留的 CR
    [ -n "$f" ] || continue
    py3ify "$f"
done < "$BAD_LIST"
rm -f "$BAD_LIST"

echo "== 完成：转换 $patched 个文件，失败 $failed 个 =="
[ "$failed" -eq 0 ] || echo "== 注意：有文件没能自动转换，编译可能会再撞到 ==" >&2

exit 0
