ARCHS = arm64
TARGET = iphone:clang:16.5:14.0

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidMorphDiag

LiquidMorphDiag_FILES = Tweak.xm
LiquidMorphDiag_CFLAGS = -fobjc-arc
LiquidMorphDiag_FRAMEWORKS = UIKit QuartzCore Foundation
LiquidMorphDiag_PRIVATE_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
