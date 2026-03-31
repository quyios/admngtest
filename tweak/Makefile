TARGET  := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := XXTExplorerAuthBypass

# Đổi sang .m vì không dùng Logos syntax nữa
XXTExplorerAuthBypass_FILES     := Tweak.x
XXTExplorerAuthBypass_CFLAGS    := -fobjc-arc -x objective-c
XXTExplorerAuthBypass_LDFLAGS   := -framework Foundation -framework UIKit
XXTExplorerAuthBypass_FRAMEWORKS := Foundation UIKit

include $(THEOS)/makefiles/tweak.mk
