TARGET  := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := XXTExplorer

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := XXTExplorerAuthBypass

XXTExplorerAuthBypass_FILES := Tweak.x
XXTExplorerAuthBypass_CFLAGS := -fobjc-arc
XXTExplorerAuthBypass_LDFLAGS := -framework Foundation -framework UIKit

# Không cần rootstrap đặc biệt vì chỉ hook class thông qua Logos/runtime
XXTExplorerAuthBypass_FRAMEWORKS := Foundation UIKit

include $(THEOS)/makefiles/tweak.mk
