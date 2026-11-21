#
# Copyright (C) 2026 The gn3002-phoenix Project
#
# 两个产品都登记，两条查找路径都能命中：
#
#   路径 A（CM_BUILD 生效时）
#     14.1 的 build/core/product_config.mk:183 是
#         ifneq ($(CM_BUILD),)
#           all_product_configs := $(shell find device -path "*/$(CM_BUILD)/lineage.mk")
#           # 找不到再退回 cm.mk
#         endif
#     这时只认 device/gionee/gbl7356/lineage.mk，本文件根本不看。
#
#   路径 B（CM_BUILD 为空时）
#     走 get-all-product-makefiles，读的就是本文件的 PRODUCT_MAKEFILES。
#
# 第一轮构建挂在 product_config.mk:245
#   Can not locate config makefile for product "lineage_gbl7356"
# 而文件明明在 device/gionee/gbl7356/lineage.mk —— 说明路径 A 没走通
# （CM_BUILD 没传进 make），于是落到路径 B，而当时本文件只登记了 omni，
# 自然找不到 lineage_gbl7356。
# 两条都登记上，哪条路断了都不至于直接报错。
#
# 注意 product_config.mk:207-219 的解析规则：
#   "<product_name>:<path>"  显式映射产品名
#   只有 "<path>"            产品名取文件名（不含 .mk）
#
# 我们的文件叫 lineage.mk，但产品名是 lineage_gbl7356，
# 两者不一致，所以必须写成 lineage_gbl7356:$(LOCAL_DIR)/lineage.mk，
# 否则会被当成产品名 "lineage"。
#
# 注意：登记的文件必须真实存在，否则编另一个产品时会因为 include 不到而报错。
#

PRODUCT_MAKEFILES := \
    lineage_gbl7356:$(LOCAL_DIR)/lineage.mk \
    $(LOCAL_DIR)/omni_gbl7356.mk
