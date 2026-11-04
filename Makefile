TARGET := iphone:clang:latest:14.0
ARCHS := arm64
DEBUG ?= 0
FINALPACKAGE ?= 1

INSTALL_TARGET_PROCESSES = VideoStar

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VideoStarAutoLayerTweak

VideoStarAutoLayerTweak_FILES = \
    Sources/Tweak.xm \
    Sources/VSLayerFilter.m \
    Sources/VSAutoLayerManager.m \
    Sources/VSFloatingHUD.m

VideoStarAutoLayerTweak_CFLAGS = -fobjc-arc -IHeaders
VideoStarAutoLayerTweak_FRAMEWORKS = UIKit Photos PhotosUI AVFoundation QuartzCore CoreGraphics UniformTypeIdentifiers MobileCoreServices

include $(THEOS_MAKE_PATH)/tweak.mk
