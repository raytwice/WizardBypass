ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ExtendedGuidelines

ExtendedGuidelines_FILES = Tweak.x
ExtendedGuidelines_CFLAGS = -fobjc-arc
ExtendedGuidelines_FRAMEWORKS = UIKit CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
