#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI 源码级补丁：让 GitHub Actions 编出的 TWRP 真正支持中英文切换。

== 为什么要补这个 ==
现状有三个互相独立的问题叠在一起，只有全解决才能"切得了、且切完记得住"：

1) **语言包根本不在基础主题里**
   TWRP 把 zh_CN.xml 放在 `gui/theme/extra-languages/languages/`，而该目录
   只有在 `TW_EXTRA_LANGUAGES := true` 时才会被装进 ramdisk（见
   bootable/recovery/Android.mk:126-128）。本项目为省 2MB 设的是 false，
   所以**CI 产物只有英文**，设置里根本没有中文可选项。

2) **中文语言包依赖专用字体**
   zh_CN.xml 的四个 fontoverride 都指向 DroidSansFallback.ttf。该字体只在
   extra-languages/fonts 里（3.7MB，全套 CJK）。不装它，中文就是方块。
   本项目用子集化版本（GB2312 + 语言包用字，1.07MB）放进设备树
   `prebuilt/fonts/DroidSansFallback.ttf`，由本脚本拷进主题。

3) **ui.xml 里硬编码 tw_language 导致"切换不生效"**（最关键的一条）
   如果 ui.xml 写了 `<variable name="tw_language" value="zh_CN"/>`，
   `PageSet::LoadVariables()`（gui/pages.cpp:1014）在**每次加载主题时**都会
   对带 value 的变量调 SetValue；而 `DataManager::SetValue()`（data.cpp:459-465）
   在键已存在于持久设置时会**直接覆盖持久设置**：
       int persistChk = mPersist.GetValue(varName, test);
       if (persistChk == 0) mPersist.SetValue(varName, value);  // ← 覆盖用户选择
       else                 mData.SetValue(varName, value);
   于是用户在界面里选了 English，写进 /data/recovery/.twrps 也没用，
   下次开机主题一加载又被改回 zh_CN。表现就是"切了没用 / 切完自己跳回中文"。
   **正确做法是不要在 ui.xml 里声明 tw_language**，默认值交给编译期的
   `TW_DEFAULT_LANGUAGE`（data.cpp:872），用户选择则由 .twrps 持久化。
   TWRP 上游主题本来就没有这个变量 —— 是本项目早期在本地工具里注入的，属自造坑。

== 本脚本做什么（幂等）==
  a. 把 extra-languages 的 zh_CN.xml 拷进 common/languages/
  b. 把设备树的 DroidSansFallback.ttf 拷进 common/fonts/
  c. 从所有主题 ui.xml 里删掉 tw_language / tw_language_display 的 <variable>
  d. 校验：common/languages/zh_CN.xml 存在、字体存在、ui.xml 不再含 tw_language 变量

用法: python3 patch-twrp-theme-i18n.py <ROM 根目录> <设备树根目录>
"""
import os
import re
import shutil
import sys

MARK = '<!-- phoenix i18n patch applied -->'


def find_theme_dir(rom):
    for p in ('bootable/recovery/gui/theme',
              'bootable/recovery/gui/theme/common/..'):
        d = os.path.join(rom, p)
        if os.path.isdir(d):
            return d
    return None


def copy_language(theme):
    """把 zh_CN.xml 从 extra-languages 拷进 common/languages。"""
    src = os.path.join(theme, 'extra-languages', 'languages', 'zh_CN.xml')
    dst_dir = os.path.join(theme, 'common', 'languages')
    dst = os.path.join(dst_dir, 'zh_CN.xml')
    if not os.path.isfile(src):
        return False, '找不到源语言包 %s' % src
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copyfile(src, dst)
    return True, 'zh_CN.xml -> common/languages (%d 字节)' % os.path.getsize(dst)


def copy_font(theme, devtree):
    """把设备树里的子集化 DroidSansFallback.ttf 拷进 common/fonts。"""
    src = os.path.join(devtree, 'prebuilt', 'fonts', 'DroidSansFallback.ttf')
    dst_dir = os.path.join(theme, 'common', 'fonts')
    dst = os.path.join(dst_dir, 'DroidSansFallback.ttf')
    if not os.path.isfile(src):
        return False, '找不到字体 %s' % src
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copyfile(src, dst)
    return True, 'DroidSansFallback.ttf -> common/fonts (%d 字节)' % os.path.getsize(dst)


VAR_RE = re.compile(
    r'[ \t]*<variable\s+name="tw_language(?:_display)?"[^>]*/>\s*\n', re.I)


def strip_language_vars(theme):
    """从所有主题 ui.xml 删掉 tw_language / tw_language_display 变量声明。

    这是修复"切换不生效"的关键：详见文件头第 3 条。
    """
    changed = []
    for root, _dirs, files in os.walk(theme):
        for fn in files:
            if fn != 'ui.xml':
                continue
            p = os.path.join(root, fn)
            with open(p, encoding='utf-8', errors='surrogateescape') as f:
                txt = f.read()
            new = VAR_RE.sub('', txt)
            if new != txt:
                if MARK not in new:
                    # 在 <theme ...> 之后插入标记，便于人工确认补丁已生效
                    m = re.search(r'<theme[^>]*>', new)
                    if m:
                        new = new[:m.end()] + '\n\t' + MARK + new[m.end():]
                with open(p, 'w', encoding='utf-8',
                          errors='surrogateescape', newline='\n') as f:
                    f.write(new)
                changed.append(os.path.relpath(p, theme))
    return changed


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    rom, devtree = sys.argv[1], sys.argv[2]

    theme = find_theme_dir(rom)
    if not theme:
        sys.exit('找不到 TWRP 主题目录 bootable/recovery/gui/theme')
    print('  主题目录: %s' % theme)

    ok, msg = copy_language(theme)
    print('  [语言包] %s' % msg)
    if not ok:
        sys.exit('语言包拷贝失败')

    ok, msg = copy_font(theme, devtree)
    print('  [字体]   %s' % msg)
    if not ok:
        sys.exit('字体拷贝失败')

    changed = strip_language_vars(theme)
    if changed:
        print('  [ui.xml] 已删除 tw_language 变量: %s' % ', '.join(changed))
    else:
        print('  [ui.xml] 没有 tw_language 变量（上游本来就没有，正常）')

    # ---- 最终校验 ----
    problems = []
    if not os.path.isfile(os.path.join(theme, 'common', 'languages', 'zh_CN.xml')):
        problems.append('common/languages/zh_CN.xml 缺失')
    if not os.path.isfile(os.path.join(theme, 'common', 'fonts',
                                       'DroidSansFallback.ttf')):
        problems.append('common/fonts/DroidSansFallback.ttf 缺失')
    for root, _d, files in os.walk(theme):
        for fn in files:
            if fn == 'ui.xml':
                p = os.path.join(root, fn)
                txt = open(p, encoding='utf-8', errors='surrogateescape').read()
                if re.search(r'<variable\s+name="tw_language', txt, re.I):
                    problems.append('%s 仍含 tw_language 变量' % p)

    if problems:
        for x in problems:
            print('  [错误] ' + x)
        sys.exit('i18n 补丁校验失败')

    # 顺带列出 common/languages 里现在有多少语言
    langs = sorted(f for f in os.listdir(os.path.join(theme, 'common', 'languages'))
                   if f.endswith('.xml'))
    print('  [校验通过] common/languages 共 %d 个: %s'
          % (len(langs), ', '.join(langs)))


if __name__ == '__main__':
    main()
