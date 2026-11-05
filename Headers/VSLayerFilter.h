//
//  VSLayerFilter.h
//  VideoStarAutoLayerTweak
//
//  Filter engine to inspect and filter Multi-Layer types in Video Star.
//

#import <Foundation/Foundation.h>
#import "VideoStarHeaders.h"

NS_ASSUME_NONNULL_BEGIN

@interface VSLayerFilterConfig : NSObject

@property (nonatomic, assign) BOOL allowImageLayers;     // Default: YES
@property (nonatomic, assign) BOOL allowVideoLayers;     // Default: YES

@property (nonatomic, assign) BOOL skipColorLayers;      // Default: YES
@property (nonatomic, assign) BOOL skipEmptyLayers;      // Default: YES
@property (nonatomic, assign) BOOL skipOverlayLayers;    // Default: YES
@property (nonatomic, assign) BOOL skipZapLayers;        // Default: YES
@property (nonatomic, assign) BOOL skipParticleLayers;   // Default: YES
@property (nonatomic, assign) BOOL skip3DLayers;         // Default: YES

+ (instancetype)defaultConfig;

@end

@interface VSLayerFilter : NSObject

@property (nonatomic, strong) VSLayerFilterConfig *config;

+ (instancetype)sharedFilter;

/**
 * Phân tích và phát hiện loại Layer dựa trên Runtime Introspection.
 * Kiểm tra Class Name, KVC properties, Method Responding và Content Assets.
 */
+ (VSLayerType)detectLayerType:(id)layerObject;

/**
 * Đánh giá xem Layer tại vị trí `index` có đủ điều kiện để tự động Import/Replace hay không.
 * @param layerObject Đối tượng Layer thực tế lấy từ Video Star.
 * @param index Chỉ số của Layer (0-indexed hoặc 1-indexed tuỳ màn hình).
 * @param outType Con trỏ trả về loại Layer đã nhận diện.
 * @param outReason Chuỗi giải thích lý do xử lý hoặc bỏ qua để hiển thị ra Log.
 * @return YES nếu được phép Import (Image/Video), NO nếu bị loại bỏ theo Filter Rules.
 */
- (BOOL)shouldProcessLayer:(id)layerObject
                     index:(NSInteger)index
              detectedType:(VSLayerType * _Nullable)outType
                    reason:(NSString * _Nullable * _Nullable)outReason;

@end

NS_ASSUME_NONNULL_END
