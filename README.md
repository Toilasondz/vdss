# 🌟 VIDEO STAR AUTO-LAYER PRO (iOS TWEAK / DYLIB)

Dự án mã nguồn hoàn chỉnh cho Tweak tự động hóa trên ứng dụng **Video Star (iOS)**. Tweak cung cấp giao diện nổi phong cách Dark Mode Glassmorphism, tự động lọc các lớp theo quy tắc nghiêm ngặt và nhập hình ảnh/video vào Multi-Layer Editor một cách thông minh.

---

## 📁 CẤU TRÚC THƯ MỤC DỰ ÁN

```text
VideoStarAutoLayerTweak/
├── Headers/
│   ├── VideoStarHeaders.h       # Khai báo enum lớp, interface Video Star đảo ngược & helper
│   ├── VSLayerFilter.h          # Bộ lọc nhận diện & kiểm tra điều kiện lớp
│   ├── VSAutoLayerManager.h     # Động cơ quản lý automation, hàng đợi media, dispatch log
│   └── VSFloatingHUD.h          # Giao diện Floating Window & Glassmorphism Panel
├── Sources/
│   ├── VSLayerFilter.m          # Thuật toán quét runtime KVC & phân tích phân loại lớp
│   ├── VSAutoLayerManager.m     # Thực thi vòng lặp nhập media, điều phối delay render
│   ├── VSFloatingHUD.m          # Triển khai HUD mờ, nút kéo bám mép, terminal log console
│   ├── Tweak.xm                 # Hook chuẩn Theos Logos (%hook UIWindow, UIViewController)
│   └── Tweak_Standalone.m      # Hook độc lập bằng Objective-C Swizzling (dành cho clang thuần)
├── Makefile                     # File cấu hình Theos chuẩn
├── control                      # Thông tin gói Debian (.deb)
├── VideoStarAutoLayerTweak.plist# Bundle Filter định tuyến hook vào Video Star
├── compile_dylib.sh             # Script Bash tự động biên dịch .dylib bằng clang
└── README.md                    # Tài liệu hướng dẫn chi tiết
```

---

## 🛡️ BỘ LỌC BẮT BUỘC (FILTER RULES)

Tweak được thiết lập thuật toán kiểm tra đa tầng (Runtime Introspection):
1. **Kiểm tra Selector nội bộ** (`isColorLayer`, `is3DLayer`, `isZapLayer`,...).
2. **Kiểm tra KVC an toàn** (`layerType`, `kind`, `assetModel`, `mediaURL`).
3. **Phân tích chuỗi nhận diện đặc trưng** trong Class Name & Description.

| Loại Lớp | Hành Động | Ghi Chú |
| :--- | :---: | :--- |
| **Image Layers** (Hình ảnh) | ✅ **CHO PHÉP** | Nhập hình ảnh từ hàng đợi vào layer |
| **Video Layers** (Video clip) | ✅ **CHO PHÉP** | Nhập video file/URL vào layer |
| **Color/Solid Layers** (Lớp màu) | ⛔ **BỎ QUA** | Tránh làm hỏng nền màu hoặc background fill |
| **Empty Layers** (Lớp rỗng) | ⛔ **BỎ QUA** | Bỏ qua các slot chưa kích hoạt |
| **Overlay / Sub-Layers** (Lớp đệm) | ⛔ **BỎ QUA** | Tránh ghi đè layer mặt nạ, blend, matte |
| **Zaps / Flash Layers** (Hiệu ứng chớp)| ⛔ **BỎ QUA** | Bỏ qua layer chớp sáng/transition effect |
| **Particle Layers** (Lớp hạt/sparkle)| ⛔ **BỎ QUA** | Giữ nguyên hiệu ứng bụi, tuyết, lấp lánh |
| **3D Layers** (Vật thể 3D / Mesh) | ⛔ **BỎ QUA** | Giữ nguyên mô hình 3D, shapes, camera |

---

## 🎨 GIAO DIỆN NỔI (DARK MODE GLASSMORPHISM HUD)

- **Floating Bubble (Nút Trôi Nổi):**
  - Hiệu ứng kính mờ (`UIBlurEffectStyleDark`), viền Neon Cyan phát sáng.
  - Kéo thả tự do trên màn hình; tự động hít về mép trái hoặc phải khi thả tay.
  - Bấm vào để ẩn/hiện bảng điều khiển trung tâm.
- **Bảng Điều Khiển Chính (Main Panel):**
  - Nút **"📁 Chọn Media"**: Hỗ trợ mở `PHPickerViewController` (chọn cùng lúc nhiều ảnh/video từ Photos Album) hoặc chọn file từ ứng dụng Files.
  - Nút **"⚡ Auto Import" / "🛑 Dừng Lại"**: Kích hoạt quy trình quét và nhập tự động.
  - **Toggle Switches**: Cho phép bật/tắt từng quy tắc bỏ qua một cách linh hoạt.
  - **Real-time Terminal Log Console**: Khung chữ nhật phong cách lập trình viên, màu nền đen sâu, viền Neon Cyan, chữ Monospace đổi màu theo trạng thái (`[OK]` Xanh lá, `[SKIP]` Vàng cam, `[INFO]` Xanh lơ, `[ERR]` Đỏ). Tự động cuộn theo dòng log mới nhất.

---

## 🛠️ HƯỚNG DẪN BIÊN DỊCH CHI TIẾT

Bạn có thể lựa chọn 1 trong 3 cách biên dịch dưới đây:

### CÁCH 1: Biên dịch bằng Theos (Khuyên dùng khi đóng gói .deb)
Yêu cầu môi trường đã cài đặt Theos:
```bash
# Di chuyển vào thư mục dự án
cd VideoStarAutoLayerTweak

# Biên dịch ra file dylib & đóng gói .deb
make clean
make package FINALPACKAGE=1
```
File `.dylib` và gói cài đặt `.deb` sẽ nằm trong thư mục `.theos/obj/debug` hoặc `packages/`.

---

### CÁCH 2: Biên dịch tự động bằng Script `compile_dylib.sh`
Script này sử dụng trực tiếp Apple Clang trên macOS hoặc LLVM Clang trên Linux để compile mà không cần cài Theos:
```bash
# Cấp quyền thực thi cho script
chmod +x compile_dylib.sh

# Chạy script
./compile_dylib.sh
```
Kết quả file `VideoStarAutoLayerTweak.dylib` đã được ký ldid sẽ xuất hiện tại thư mục `./build/`.

---

### CÁCH 3: Biên dịch thủ công bằng các lệnh Terminal (`clang` & `ldid`)

Nếu bạn muốn tự chạy từng lệnh Terminal để nắm rõ quá trình biến đổi từ `.m` thành `.o` và `.dylib`:

#### Bước 3.1: Xác định đường dẫn iOS SDK
```bash
# Trên macOS:
export SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)

# Hoặc nếu bạn dùng SDK từ Theos trên Linux / Windows WSL:
# export SDK_PATH="$THEOS/sdks/iPhoneOS14.5.sdk"
```

#### Bước 3.2: Biên dịch các file `.m` thành file đối tượng Object (`.o`)
```bash
mkdir -p build

# 1. Biên dịch VSLayerFilter.m
clang -target arm64-apple-ios14.0 -isysroot "$SDK_PATH" -fobjc-arc -O2 \
      -IHeaders -c Sources/VSLayerFilter.m -o build/VSLayerFilter.o

# 2. Biên dịch VSAutoLayerManager.m
clang -target arm64-apple-ios14.0 -isysroot "$SDK_PATH" -fobjc-arc -O2 \
      -IHeaders -c Sources/VSAutoLayerManager.m -o build/VSAutoLayerManager.o

# 3. Biên dịch VSFloatingHUD.m
clang -target arm64-apple-ios14.0 -isysroot "$SDK_PATH" -fobjc-arc -O2 \
      -IHeaders -c Sources/VSFloatingHUD.m -o build/VSFloatingHUD.o

# 4. Biên dịch Tweak_Standalone.m (Hook Runtime)
clang -target arm64-apple-ios14.0 -isysroot "$SDK_PATH" -fobjc-arc -O2 \
      -IHeaders -c Sources/Tweak_Standalone.m -o build/Tweak_Standalone.o
```

#### Bước 3.3: Liên kết (Link) các file `.o` thành file Dynamic Library (`.dylib`)
```bash
clang -dynamiclib -target arm64-apple-ios14.0 -isysroot "$SDK_PATH" \
      -install_name @rpath/VideoStarAutoLayerTweak.dylib \
      -framework Foundation \
      -framework UIKit \
      -framework Photos \
      -framework PhotosUI \
      -framework AVFoundation \
      -framework QuartzCore \
      -framework CoreGraphics \
      -framework UniformTypeIdentifiers \
      build/VSLayerFilter.o \
      build/VSAutoLayerManager.o \
      build/VSFloatingHUD.o \
      build/Tweak_Standalone.o \
      -o build/VideoStarAutoLayerTweak.dylib
```

#### Bước 3.4: Ký giả lập (Pseudo-sign) bằng `ldid`
```bash
ldid -S build/VideoStarAutoLayerTweak.dylib
```

---

## 📲 CÁCH CÀI ĐẶT & SỬ DỤNG TRÊN THIẾT BỊ

### Cách 1: Thiết bị đã Jailbreak
1. Đặt file `VideoStarAutoLayerTweak.dylib` và `VideoStarAutoLayerTweak.plist` vào `/Library/MobileSubstrate/DynamicLibraries/`.
2. Khởi động lại ứng dụng Video Star.

### Cách 2: Thiết bị Chưa Jailbreak (Sideloading / TrollStore)
1. Sử dụng công cụ chèn thư viện động như **Azule**, **Sideloadly**, hoặc **ESign**:
   ```bash
   # Ví dụ dùng Azule:
   azule -i VideoStar.ipa -o VideoStar_Patched.ipa -f build/VideoStarAutoLayerTweak.dylib
   ```
2. Cài đặt file IPA đã patch qua TrollStore hoặc Sideloadly.
3. Mở Video Star -> Bạn sẽ thấy icon bong bóng neon `VS✦` trôi nổi trên màn hình.
4. Mở clip Multi-Layer -> Bấm vào bong bóng `VS✦` -> Chọn nguồn ảnh/video -> Bấm **"Auto Import"**.
