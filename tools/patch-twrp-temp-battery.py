#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI 源码级补丁：修正 TWRP 的 CPU 温度 / 电量显示。

== 问题 ==
用户反馈状态栏的 CPU 温度和电量都"明显不对"。

== 温度：为什么写死 thermal_zone1 是错的 ==
BoardConfig 里曾是：
    TW_CUSTOM_CPU_TEMP_PATH := /sys/class/thermal/thermal_zone1/temp
`DataManager::GetValue("tw_cpu_temp")`（data.cpp:934）读这个文件，然后：
    convert_temp = raw / 1000;
    if (convert_temp <= 0) convert_temp = raw;
    if (convert_temp >= 150) convert_temp = raw / 10;
这套换算假设"读到的是 CPU 温度"。但 MT6735 上 thermal_zoneN 的顺序由内核
注册顺序决定，zone1 完全可能是 PCB/电池/充电器温度，甚至是不上报的占位节点：
  - 若 zone1 是不上报的节点，read_file 失败 → 整个变量返回 -1，
    界面上就是空白或 0；
  - 若是电池温度，显示的就是电池温度，却标成 "CPU"。
两种都会表现为"温度明显不对"。

**正确做法**：不看序号，看 `/sys/class/thermal/thermal_zoneN/type`。
MTK 平台 CPU 温度的 type 通常是 `cpu` / `mtktscpu` / `mtktsAP`。
本补丁把 tw_cpu_temp 的计算改成"按 type 找 zone"，找不到再退回
TW_CUSTOM_CPU_TEMP_PATH，最后退回 zone0，永不再盲信固定序号。

== 电量：为什么可能显示错 ==
`tw_battery`（data.cpp:968）只读 `/sys/class/power_supply/battery/capacity`。
本项目实测这颗 MT6735 上：
  - `/sys/class/power_supply/battery/capacity` 存在且读数正确（0..100）
  - 但 `fgets(cap_s, 4, cap)` 用的是 char[4]：如果内核返回的是 "100\n"，
    会读到 "100"（没问题）；若返回带前导空格或 "1000"（某些 MTK 用千分比），
    atoi 结果就会错。
更稳的做法：优先用 `capacity`，失败再试 `charge_counter/charge_full`
（部分 MTK 内核只给后者），两者都没有就显示 n/a 而不是误导性的 0/101。

== 用法 ==
python3 patch-twrp-temp-battery.py <ROM 根目录>
"""
import os
import re
import sys

DATA_CPP = 'bootable/recovery/data.cpp'
MARK_TEMP = 'phoenix cpu_temp autodetect'
MARK_BATT = 'phoenix battery fallback'

# 替换 tw_cpu_temp 整段（从 else if (varName == "tw_cpu_temp") 到下一段 else if）
TEMP_NEW = r'''	else if (varName == "tw_cpu_temp")
	{
		int tw_no_cpu_temp;
		GetValue("tw_no_cpu_temp", tw_no_cpu_temp);
		if (tw_no_cpu_temp == 1) return -1;

		/* ---- phoenix cpu_temp autodetect ----
		 * 不能盲信固定 zone 序号：MT6735 上 thermal_zoneN 的顺序由内核注册
		 * 顺序决定，zone1 可能是 PCB/电池/充电器温度，甚至是不上报的占位节点。
		 * 这里按 /sys/class/thermal/thermal_zoneN/type 找 CPU 传感器，
		 * 命中不了再退回 TW_CUSTOM_CPU_TEMP_PATH，最后退回 zone0。 */
		static unsigned long convert_temp = 0;
		static time_t cpuSecCheck = 0;
		struct timeval curTime;
		string results;

		gettimeofday(&curTime, NULL);
		if (curTime.tv_sec > cpuSecCheck)
		{
			string tempFile;
			bool found = false;
			for (int zi = 0; zi < 32 && !found; zi++) {
				char zdir[128];
				snprintf(zdir, sizeof(zdir),
						 "/sys/class/thermal/thermal_zone%d", zi);
				string typeFile = string(zdir) + "/type";
				string typeVal;
				if (TWFunc::read_file(typeFile, typeVal) != 0)
					continue;
				/* type 里可能带换行 */
				size_t nl = typeVal.find('\n');
				if (nl != string::npos)
					typeVal.erase(nl);
				string lower = typeVal;
				for (size_t k = 0; k < lower.size(); k++) {
					/* 只做 ASCII 小写，避免依赖 <cctype> 里的全局 tolower
					 * （标准只保证 std::tolower，全局版本属于实现细节） */
					if (lower[k] >= 'A' && lower[k] <= 'Z')
						lower[k] = (char)(lower[k] - 'A' + 'a');
				}
				/* MTK: mtktscpu / cpu；高通: cpu-0-0-us；通用: soc_thermal */
				if (lower.find("cpu") != string::npos ||
					lower.find("soc_thermal") != string::npos ||
					lower.find("mtktsap") != string::npos) {
					tempFile = string(zdir) + "/temp";
					found = true;
					LOGINFO("phoenix: cpu temp zone = thermal_zone%d (%s)\n",
							zi, typeVal.c_str());
				}
			}
#ifdef TW_CUSTOM_CPU_TEMP_PATH
			if (!found) {
				tempFile = EXPAND(TW_CUSTOM_CPU_TEMP_PATH);
				found = true;
			}
#endif
			if (!found)
				tempFile = "/sys/class/thermal/thermal_zone0/temp";

			if (TWFunc::read_file(tempFile, results) != 0)
				return -1;

			unsigned long raw = strtoul(results.c_str(), NULL, 0);
			convert_temp = raw / 1000;
			if (convert_temp <= 0)
				convert_temp = raw;
			if (convert_temp >= 150)
				convert_temp = raw / 10;
			/* 合理区间之外当作读错，宁可不显示也不误导 */
			if (convert_temp < 1 || convert_temp > 125) {
				LOGINFO("phoenix: cpu temp out of range (%lu) from %s\n",
						convert_temp, tempFile.c_str());
				convert_temp = 0;
			}
			cpuSecCheck = curTime.tv_sec + 5;
		}
		value = TWFunc::to_string(convert_temp);
		return 0;
	}
'''

BATT_NEW = r'''	else if (varName == "tw_battery")
	{
		char tmp[16];
		static char charging = ' ';
		static int lastVal = -1;
		static time_t nextSecCheck = 0;
		struct timeval curTime;
		gettimeofday(&curTime, NULL);
		if (curTime.tv_sec > nextSecCheck)
		{
			/* ---- phoenix battery fallback ----
			 * capacity 是首选；但部分 MTK 内核只给 charge_counter/charge_full，
			 * 也有内核返回 0..1000 的千分比。这里逐个兜底并做量程归一，
			 * 读不到就显示 -1（界面显示 n/a），不再显示误导性的 0/101。 */
			string capPath = "/sys/class/power_supply/battery/capacity";
#ifdef TW_CUSTOM_BATTERY_PATH
			capPath = EXPAND(TW_CUSTOM_BATTERY_PATH);
			capPath += "/capacity";
#endif
			string capVal;
			int val = -1;

			if (TWFunc::read_file(capPath, capVal) == 0) {
				val = atoi(capVal.c_str());
			}
			if (val < 0 || val > 100) {
				/* 千分比（0..1000）归一 */
				if (val > 100 && val <= 1000) {
					val = (val + 5) / 10;
				}
			}
			if (val < 0 || val > 100) {
				/* 再兜底：charge_counter / charge_full */
				string base = "/sys/class/power_supply/battery";
#ifdef TW_CUSTOM_BATTERY_PATH
				base = EXPAND(TW_CUSTOM_BATTERY_PATH);
#endif
				string cntS, fullS;
				if (TWFunc::read_file(base + "/charge_counter", cntS) == 0 &&
					TWFunc::read_file(base + "/charge_full", fullS) == 0) {
					long cnt = atol(cntS.c_str());
					long full = atol(fullS.c_str());
					if (full > 0)
						val = (int)((cnt * 100 + full / 2) / full);
				}
			}
			if (val < 0 || val > 100)
				val = -1;

			lastVal = val;

			string statusPath = "/sys/class/power_supply/battery/status";
#ifdef TW_CUSTOM_BATTERY_PATH
			statusPath = EXPAND(TW_CUSTOM_BATTERY_PATH);
			statusPath += "/status";
#endif
			string stVal;
			if (TWFunc::read_file(statusPath, stVal) == 0 && !stVal.empty()) {
				charging = (stVal[0] == 'C' || stVal[0] == 'F') ? '+' : ' ';
			}
			nextSecCheck = curTime.tv_sec + 60;
		}

		if (lastVal < 0)
			sprintf(tmp, "n/a");
		else
			sprintf(tmp, "%i%%%c", lastVal, charging);
		value = tmp;
		return 0;
	}
'''


def replace_block(src, start_marker, new_block):
    """把 start_marker 开始的整个 else-if 块替换成 new_block。

    块边界靠大括号配平找，比正则可靠（源码里嵌套很深）。
    """
    i = src.find(start_marker)
    if i < 0:
        return None
    # 找到块内第一个 '{'
    b = src.find('{', i)
    if b < 0:
        return None
    depth = 0
    j = b
    while j < len(src):
        c = src[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                break
        j += 1
    if depth != 0:
        return None
    # 块结束后吃掉后续空白（保留后面那个 else if）
    end = j + 1
    nl = src.find('\n', end)
    if nl >= 0:
        end = nl + 1
    return src[:i] + new_block + src[end:]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    rom = sys.argv[1]
    p = os.path.join(rom, DATA_CPP)
    if not os.path.isfile(p):
        sys.exit('找不到 %s' % p)

    src = open(p, encoding='utf-8', errors='surrogateescape').read()

    if MARK_TEMP in src and MARK_BATT in src:
        print('  [温度/电量] 已打过补丁，跳过')
        return

    if MARK_TEMP not in src:
        out = replace_block(src, 'else if (varName == "tw_cpu_temp")', TEMP_NEW)
        if out is None:
            sys.exit('  [温度] 找不到 tw_cpu_temp 块，TWRP 版本可能不匹配')
        src = out
        print('  [温度] 已改为按 thermal_zoneN/type 自动识别 CPU 传感器')

    if MARK_BATT not in src:
        out = replace_block(src, 'else if (varName == "tw_battery")', BATT_NEW)
        if out is None:
            sys.exit('  [电量] 找不到 tw_battery 块，TWRP 版本可能不匹配')
        src = out
        print('  [电量] 已加 capacity→千分比→charge_counter 三级兜底')

    # 不再需要注入 <ctype.h>（改用纯 ASCII 小写，不依赖全局 tolower）
    with open(p, 'w', encoding='utf-8', errors='surrogateescape', newline='\n') as f:
        f.write(src)
    print('  [完成] 已写回 %s' % p)


if __name__ == '__main__':
    main()