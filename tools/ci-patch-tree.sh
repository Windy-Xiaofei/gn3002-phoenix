#!/usr/bin/env bash
#
# 对 Android 8.1 (TWRP omni) 源码树做兼容性修补。
#
# 背景：ubuntu-22.04 上的 `python` 已经是 Python 3，而 8.1 时代的脚本
# 还留着 Python 2 语法；同时 gcc 11/12 对旧代码更严格。
# 这些修补每次 CI 都要重做（源码树是全新 clone 的），所以集中在这里。
#
# 用法: ci-patch-tree.sh <源码树根目录>
#
set -euo pipefail

ROM_DIR=${1:-rom}
cd "$ROM_DIR"

if [ ! -d build ]; then
    echo "错误: $ROM_DIR 看起来不是 Android 源码树" >&2
    exit 1
fi

patched=0

# 把 `except A, B:` 改成 `except (A, B):`
# 保守起见只在文件当前语法确实是坏的才改，避免误伤已经正确的文件。
fix_py2_except() {
    local f=$1
    [ -f "$f" ] || return 0

    if python3 -c "import ast,sys; ast.parse(open('$f',encoding='utf-8',errors='replace').read())" 2>/dev/null; then
        return 0
    fi

    if grep -qE '^[[:space:]]*except [A-Za-z_.]+, [A-Za-z_.]+:' "$f"; then
        sed -i -E 's/^([[:space:]]*)except ([A-Za-z_.]+), ([A-Za-z_.]+):/\1except (\2, \3):/' "$f"
        python3 -c "import ast,sys; ast.parse(open('$f',encoding='utf-8',errors='replace').read())"
        echo "  [py2->py3] $f"
        patched=$((patched + 1))
    else
        echo "  [跳过] $f 语法错误但不是 except 形式，需要人工看" >&2
    fi
}

echo "== 修补源码树: $(pwd) =="

# lunch 时执行的设备树自动查找脚本
fix_py2_except vendor/omni/build/tools/roomservice.py

echo "== 完成，修补 $patched 个文件 =="
