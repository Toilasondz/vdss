//
//  VideoStarHeaders.h
//  VideoStarAutoLayerTweak
//
//  Reverse engineered interfaces and runtime headers for Video Star app.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Layer Type Enumerations

typedef NS_ENUM(NSInteger, VSLayerType) {
    VSLayerTypeUnknown = 0,
    VSLayerTypeImage,       // Image / Photo Layers (ALLOWED)
    VSLayerTypeVideo,       // Video Clip / Movie Layers (ALLOWED)
    VSLayerTypeColor,       // Color / Solid Layers (FILTER: SKIP)
    VSLayerTypeEmpty,       // Empty / Unassigned Layers (FILTER: SKIP)
    VSLayerTypeOverlay,     // Overlay / Sub / Adjustment / Blend Layers (FILTER: SKIP)
    VSLayerTypeZaps,        // Zaps / Flash / Transition Effect Layers (FILTER: SKIP)
    VSLayerTypeParticle,    // Particle / Dust / Sparkle / Snow / Star Layers (FILTER: SKIP)
    VSLayerType3D           // 3D Objects / 3D Shapes / Mesh Layers (FILTER: SKIP)
};

typedef NS_ENUM(NSInteger, VSLogType) {
    VSLogTypeInfo = 0,
    VSLogTypeSuccess,
    VSLogTypeSkip,
    VSLogTypeWarning,
    VSLogTypeError
};

#pragma mark - Video Star Reverse Engineered Interfaces

/**
 * Mô phỏng đối tượng Layer Model bên trong Video Star.
 * Tại runtime, Video Star sử dụng các class như VSLayer, MultiLayerItem,
 * hoặc FDXLayer (tùy phiên bản). Quá trình xử lý sẽ dùng KVC và runtime inspection.
 */
@interface VSLayerItem : NSObject

@property (nonatomic, assign) NSInteger layerIndex;
@property (nonatomic, copy, nullable) NSString *layerTitle;
@property (nonatomic, copy, nullable) NSString *layerKindString;
@property (nonatomic, assign) NSInteger layerKind;
@property (nonatomic, strong, nullable) id assetModel;
@property (nonatomic, strong, nullable) NSURL *mediaURL;
@property (nonatomic, strong, nullable) UIImage *cachedImage;
@property (nonatomic, assign) BOOL isColorLayer;
@property (nonatomic, assign) BOOL isEmptyLayer;
@property (nonatomic, assign) BOOL isOverlayLayer;
@property (nonatomic, assign) BOOL isZapLayer;
@property (nonatomic, assign) BOOL isParticleLayer;
@property (nonatomic, assign) BOOL is3DLayer;

// Các phương thức thường gặp trong Video Star
- (void)replaceWithMediaURL:(NSURL *)url;
- (void)replaceWithImage:(UIImage *)image;
- (void)clearAsset;
- (BOOL)hasValidAsset;
- (NSString *)layerTypeDescription;

@end

/**
 * Mô phỏng Controller chính của Multi-Layer Editor trong Video Star.
 * Lớp này quản lý timeline các layer, preview player và inspector.
 */
@interface VSMultiLayerViewController : UIViewController

@property (nonatomic, strong, nullable) NSArray *layers;
@property (nonatomic, strong, nullable) NSMutableArray *layerItems;
@property (nonatomic, assign) NSInteger selectedLayerIndex;
@property (nonatomic, strong, nullable) UIView *multiLayerContainerView;

// Các hàm thao tác với Layer
- (void)selectLayerAtIndex:(NSInteger)index;
- (void)importMediaForLayer:(id)layer withURL:(NSURL *)mediaURL;
- (void)importImageForLayer:(id)layer image:(UIImage *)image;
- (void)replaceLayerMediaAtIndex:(NSInteger)index withURL:(NSURL *)url;
- (void)refreshAllLayers;
- (void)renderPreview;

@end

#pragma mark - Runtime Inspection Helper Macros

#define VS_SAFE_GET(obj, keyPath) ([obj respondsToSelector:NSSelectorFromString(keyPath)] ? [obj valueForKey:keyPath] : nil)

static inline NSString *VSStringFromLayerType(VSLayerType type) {
    switch (type) {
        case VSLayerTypeImage:    return @"Image (Hình Ảnh)";
        case VSLayerTypeVideo:    return @"Video (Clip Phim)";
        case VSLayerTypeColor:    return @"Color (Lớp Màu Solid)";
        case VSLayerTypeEmpty:    return @"Empty (Lớp Rỗng)";
        case VSLayerTypeOverlay:  return @"Overlay / Sub-Layer (Lớp Đệm)";
        case VSLayerTypeZaps:     return @"Zaps / Flash (Hiệu Ứng Chớp)";
        case VSLayerTypeParticle: return @"Particle (Lớp Hạt/Sparkle)";
        case VSLayerType3D:       return @"3D Object / Mesh (Vật Thể 3D)";
        default:                  return @"Unknown (Chưa Xác Định)";
    }
}

NS_ASSUME_NONNULL_END
