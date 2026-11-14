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

py3ify() {
    local f=$1
    [ -f "$f" ] || return 0
    py3_ok "$f" && return 0

    echo "  [py2 -> py3] $f"
    has_2to3 && run_2to3 "$f"

    # 2to3 缺失或漏网时的兜底：`except A, B:` -> `except (A, B):`
    sed -i -E 's/^([[:space:]]*)except ([A-Za-z_.]+), ([A-Za-z_.]+):/\1except (\2, \3):/' "$f"

    if py3_ok "$f"; then
        patched=$((patched + 1))
    else
        echo "     !! 转换后仍无法解析，需要人工看: $f" >&2
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
import ast, os, sys

bad = []
for root, _dirs, files in os.walk('build'):
    for fn in files:
        if not fn.endswith('.py'):
            continue
        p = os.path.join(root, fn)
        try:
            with open(p, encoding='utf-8', errors='replace') as fh:
                ast.parse(fh.read(), filename=p)
        except SyntaxError:
            bad.append(p)
        except Exception:
            pass

with open(sys.argv[1], 'w', encoding='utf-8') as out:
    out.write('\n'.join(bad))
PYEOF

total=$(grep -c . "$BAD_LIST" 2>/dev/null || echo 0)
echo "== build/ 下 py3 解析失败的脚本: $total 个 =="

while IFS= read -r f; do
    [ -n "$f" ] || continue
    py3ify "$f"
done < "$BAD_LIST"
rm -f "$BAD_LIST"

echo "== 完成：转换 $patched 个文件，失败 $failed 个 =="
[ "$failed" -eq 0 ] || echo "== 注意：有文件没能自动转换，编译可能会再撞到 ==" >&2

exit 0
