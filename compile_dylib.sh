#!/bin/bash
# ==============================================================================
# Script Biên Dịch Trực Tiếp .dylib Cho Video Star Auto-Layer Tweak
# Hỗ trợ macOS (Xcode Toolchain) hoặc Linux (Theos / LLVM Toolchain)
# ==============================================================================

set -e

# Màu sắc thông báo Terminal
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${CYAN}====================================================${RESET}"
echo -e "${CYAN}    VIDEO STAR AUTO-LAYER TWEAK - COMPILATION SCRIPT ${RESET}"
echo -e "${CYAN}====================================================${RESET}"

# 1. Cấu hình Target Kiến trúc và Phiên bản iOS
TARGET_ARCH="arm64"
TARGET_TRIPLE="arm64-apple-ios14.0"
DYLIB_NAME="VideoStarAutoLayerTweak.dylib"
BUILD_DIR="./build"

# 2. Định vị iOS SDK (Tự động phát hiện trên Xcode hoặc Theos)
if [ -n "$ISYSROOT" ] && [ -d "$ISYSROOT" ]; then
    SDK_PATH="$ISYSROOT"
elif command -v xcrun &> /dev/null && xcrun --sdk iphoneos --show-sdk-path &> /dev/null; then
    SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
elif [ -d "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" ]; then
    SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
elif [ -d "$THEOS/sdks/iPhoneOS14.5.sdk" ]; then
    SDK_PATH="$THEOS/sdks/iPhoneOS14.5.sdk"
elif [ -d "$THEOS/sdks/iPhoneOS16.5.sdk" ]; then
    SDK_PATH="$THEOS/sdks/iPhoneOS16.5.sdk"
else
    # Tìm kiếm SDK bất kỳ trong Theos sdks
    SDK_PATH=$(find "$THEOS/sdks" -name "iPhoneOS*.sdk" 2>/dev/null | head -n 1 || true)
fi

if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
    echo -e "${RED}[LỖI] Không tìm thấy iOS SDK!${RESET}"
    echo "Vui lòng chỉ định đường dẫn SDK qua biến ISYSROOT, ví dụ:"
    echo "export ISYSROOT=/path/to/iPhoneOS.sdk"
    exit 1
fi

echo -e "${YELLOW}[*] iOS SDK:${RESET} $SDK_PATH"
echo -e "${YELLOW}[*] Target:${RESET} $TARGET_TRIPLE"
echo -e "${YELLOW}[*] Output:${RESET} $BUILD_DIR/$DYLIB_NAME"

# 3. Tạo thư mục build tạm
mkdir -p "$BUILD_DIR"

# 4. Thiết lập cờ Compiler và Frameworks
CFLAGS="-target $TARGET_TRIPLE -isysroot $SDK_PATH -fobjc-arc -O2 -I./Headers -Wall -Wno-deprecated-declarations"
FRAMEWORKS="-framework Foundation -framework UIKit -framework Photos -framework PhotosUI -framework AVFoundation -framework QuartzCore -framework CoreGraphics -framework UniformTypeIdentifiers -framework MobileCoreServices"

echo -e "\n${CYAN}--- GIAI ĐOẠN 1: Biên dịch từng file .m thành file Object (.o) ---${RESET}"

# File 1: VSLayerFilter.m -> VSLayerFilter.o
echo -e "${YELLOW}[+] Biên dịch:${RESET} Sources/VSLayerFilter.m -> $BUILD_DIR/VSLayerFilter.o"
clang $CFLAGS -c Sources/VSLayerFilter.m -o "$BUILD_DIR/VSLayerFilter.o"

# File 2: VSAutoLayerManager.m -> VSAutoLayerManager.o
echo -e "${YELLOW}[+] Biên dịch:${RESET} Sources/VSAutoLayerManager.m -> $BUILD_DIR/VSAutoLayerManager.o"
clang $CFLAGS -c Sources/VSAutoLayerManager.m -o "$BUILD_DIR/VSAutoLayerManager.o"

# File 3: VSFloatingHUD.m -> VSFloatingHUD.o
echo -e "${YELLOW}[+] Biên dịch:${RESET} Sources/VSFloatingHUD.m -> $BUILD_DIR/VSFloatingHUD.o"
clang $CFLAGS -c Sources/VSFloatingHUD.m -o "$BUILD_DIR/VSFloatingHUD.o"

# File 4: Tweak_Standalone.m -> Tweak_Standalone.o
echo -e "${YELLOW}[+] Biên dịch:${RESET} Sources/Tweak_Standalone.m -> $BUILD_DIR/Tweak_Standalone.o"
clang $CFLAGS -c Sources/Tweak_Standalone.m -o "$BUILD_DIR/Tweak_Standalone.o"

echo -e "\n${CYAN}--- GIAI ĐOẠN 2: Link các file Object (.o) thành file .dylib ---${RESET}"
clang -dynamiclib \
    -target $TARGET_TRIPLE \
    -isysroot "$SDK_PATH" \
    -install_name "@rpath/$DYLIB_NAME" \
    $FRAMEWORKS \
    "$BUILD_DIR/VSLayerFilter.o" \
    "$BUILD_DIR/VSAutoLayerManager.o" \
    "$BUILD_DIR/VSFloatingHUD.o" \
    "$BUILD_DIR/Tweak_Standalone.o" \
    -o "$BUILD_DIR/$DYLIB_NAME"

echo -e "${GREEN}[V] Liên kết thành công:${RESET} $BUILD_DIR/$DYLIB_NAME"

echo -e "\n${CYAN}--- GIAI ĐOẠN 3: Ký mã (Code Signing với ldid) ---${RESET}"
if command -v ldid &> /dev/null; then
    ldid -S "$BUILD_DIR/$DYLIB_NAME"
    echo -e "${GREEN}[V] Đã ký giả lập (Pseudo-sign) bằng ldid.${RESET}"
elif [ -f "$THEOS/bin/ldid" ]; then
    "$THEOS/bin/ldid" -S "$BUILD_DIR/$DYLIB_NAME"
    echo -e "${GREEN}[V] Đã ký giả lập bằng Theos ldid.${RESET}"
else
    echo -e "${YELLOW}[!] Cảnh báo: Chưa tìm thấy 'ldid'. Vui lòng chạy 'ldid -S $BUILD_DIR/$DYLIB_NAME' trước khi inject vào IPA/thiết bị.${RESET}"
fi

echo -e "\n${GREEN}====================================================${RESET}"
echo -e "${GREEN}      HOÀN TẤT BIÊN DỊCH FILE THƯ VIỆN ĐỘNG!       ${RESET}"
echo -e "${GREEN}  File output: $BUILD_DIR/$DYLIB_NAME               ${RESET}"
echo -e "${GREEN}====================================================${RESET}"
