#
# Copyright (C) 2026 The gn3002-phoenix Project
#
# 这里只登记 omni（TWRP）产品。
#
# lineage 产品不能写进来：lunch lineage_* 时 build/core/product_config.mk
# 会走 LINEAGE_BUILD 分支，只认 device/gionee/gbl7356/lineage.mk，
# 根本不看本文件；反过来，若这里还留着已经不存在的
# $(LOCAL_DIR)/lineage_gbl7356.mk，编 omni 时会因为 include 不到而报错。
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/omni_gbl7356.mk
