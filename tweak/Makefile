TARGET  := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := XXTExplorerAuthBypass

# Đổi sang Tweak.m theo yêu cầu hoàn nguyên
XXTExplorerAuthBypass_FILES     := Tweak.m
XXTExplorerAuthBypass_CFLAGS    := -fobjc-arc
XXTExplorerAuthBypass_FRAMEWORKS := Foundation

include $(THEOS)/makefiles/tweak.mk
