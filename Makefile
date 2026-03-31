TARGET = iphone:clang:16.5:14.0

APP_NAME = XXTEPatcher
APP_BUNDLE_ID = com.quyios.xxte-patcher
APP_DISPLAY_NAME = XXTE Patcher

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = $(APP_NAME)

$(APP_NAME)_FILES = main.m
$(APP_NAME)_CFLAGS = -fobjc-arc
$(APP_NAME)_FRAMEWORKS = UIKit Foundation Security
$(APP_NAME)_CODESIGN_FLAGS = -Sentitlements.plist
$(APP_NAME)_ENTITLEMENTS = Entitlements.plist

include $(THEOS)/makefiles/application.mk
