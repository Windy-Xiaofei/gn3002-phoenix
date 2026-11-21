#
# Copyright (C) 2026 The gn3002-phoenix Project
#
# 这里只登记 omni（TWRP）产品。
#
# lineage 产品不能写进来：
#   14.1 的 build/core/product_config.mk 走的是
#       ifneq ($(CM_BUILD),)
#         all_product_configs := $(shell find device -path "*/$(CM_BUILD)/lineage.mk")
#         all_product_configs := $(shell find device -path "*/$(CM_BUILD)/cm.mk")
#       endif
#   也就是 lunch lineage_* 时只认 device/gionee/gbl7356/lineage.mk（或 cm.mk），
#   根本不看本文件。
#   （15.1 的写法一样，只是变量从 CM_BUILD 变成 LINEAGE_BUILD。）
#
# 反过来，如果这里写了已经不存在的 $(LOCAL_DIR)/lineage_gbl7356.mk，
# 编 omni 时会因为 include 不到而报错。
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/omni_gbl7356.mk
