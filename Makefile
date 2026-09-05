export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64e

INSTALL_TARGET_PROCESSES = SpringBoard
export _THEOS_PLATFORM_DPKG_DEB_COMPRESSION = gzip
# scheme 由 CI/环境变量决定（rootless 默认，roothide 构建时 CI 传 roothide）；
# 必须用 ?= 条件赋值——make 里普通赋值会覆盖环境变量，roothide job 会被打回 rootless
THEOS_PACKAGE_SCHEME ?= rootless
export THEOS_PACKAGE_SCHEME

TWEAK_NAME = AppHider

AppHider_FILES = Tweak.xm
AppHider_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
