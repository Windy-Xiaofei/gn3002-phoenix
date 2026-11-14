#
# Copyright (C) 2026 The gn3002-phoenix Project
#

LOCAL_PATH := $(call my-dir)

ifneq ($(filter gbl7356,$(TARGET_DEVICE)),)
include $(call all-makefiles-under,$(LOCAL_PATH))
endif
