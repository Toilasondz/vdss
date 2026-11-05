//
//  VSLayerFilter.m
//  VideoStarAutoLayerTweak
//
//  Filter engine implementation for Video Star layers.
//

#import "VSLayerFilter.h"
#import <objc/runtime.h>

@implementation VSLayerFilterConfig

+ (instancetype)defaultConfig {
    VSLayerFilterConfig *cfg = [[VSLayerFilterConfig alloc] init];
    // Bộ lọc bắt buộc theo yêu cầu:
    // CHỈ CHO PHÉP: Image và Video
    cfg.allowImageLayers   = YES;
    cfg.allowVideoLayers   = YES;

    // BẮT BUỘC BỎ QUA (SKIP/IGNORE):
    cfg.skipColorLayers    = YES;  // 1. Lớp màu (Color/Solid)
    cfg.skipEmptyLayers    = YES;  // 2. Lớp rỗng (Empty)
    cfg.skipOverlayLayers  = YES;  // 3. Lớp phụ / Lớp đệm (Overlay / Sub)
    cfg.skipZapLayers      = YES;  // 4. Lớp Zaps (Zaps/Flash)
    cfg.skipParticleLayers = YES;  // 5. Lớp hạt (Particle/Dust/Sparkle)
    cfg.skip3DLayers       = YES;  // 6. Lớp 3D (3D Objects/Shapes/Mesh)
    return cfg;
}

@end

@implementation VSLayerFilter

+ (instancetype)sharedFilter {
    static VSLayerFilter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VSLayerFilter alloc] init];
        instance.config = [VSLayerFilterConfig defaultConfig];
    });
    return instance;
}

#pragma mark - Runtime Inspection Engine

+ (VSLayerType)detectLayerType:(id)layerObject {
    if (!layerObject) {
        return VSLayerTypeEmpty;
    }

    NSString *className = NSStringFromClass([layerObject class]).lowercaseString;
    NSString *description = [layerObject description].lowercaseString;

    // 1. Kiểm tra qua selector nội bộ nếu đối tượng hỗ trợ
    if ([layerObject respondsToSelector:@selector(is3DLayer)] && [layerObject is3DLayer]) {
        return VSLayerType3D;
    }
    if ([layerObject respondsToSelector:@selector(isParticleLayer)] && [layerObject isParticleLayer]) {
        return VSLayerTypeParticle;
    }
    if ([layerObject respondsToSelector:@selector(isZapLayer)] && [layerObject isZapLayer]) {
        return VSLayerTypeZaps;
    }
    if ([layerObject respondsToSelector:@selector(isOverlayLayer)] && [layerObject isOverlayLayer]) {
        return VSLayerTypeOverlay;
    }
    if ([layerObject respondsToSelector:@selector(isColorLayer)] && [layerObject isColorLayer]) {
        return VSLayerTypeColor;
    }
    if ([layerObject respondsToSelector:@selector(isEmptyLayer)] && [layerObject isEmptyLayer]) {
        return VSLayerTypeEmpty;
    }

    // 2. Kiểm tra thông qua KVC an toàn (Key-Value Coding)
    id layerTypeVal = nil;
    @try {
        if ([layerObject respondsToSelector:NSSelectorFromString(@"layerType")]) {
            layerTypeVal = [layerObject valueForKey:@"layerType"];
        } else if ([layerObject respondsToSelector:NSSelectorFromString(@"type")]) {
            layerTypeVal = [layerObject valueForKey:@"type"];
        } else if ([layerObject respondsToSelector:NSSelectorFromString(@"kind")]) {
            layerTypeVal = [layerObject valueForKey:@"kind"];
        } else if ([layerObject respondsToSelector:NSSelectorFromString(@"layerKind")]) {
            layerTypeVal = [layerObject valueForKey:@"layerKind"];
        }
    } @catch (NSException *exception) {
        layerTypeVal = nil;
    }

    NSString *typeStr = @"";
    if ([layerTypeVal isKindOfClass:[NSString class]]) {
        typeStr = ((NSString *)layerTypeVal).lowercaseString;
    } else if ([layerTypeVal respondsToSelector:@selector(stringValue)]) {
        typeStr = [layerTypeVal stringValue].lowercaseString;
    }

    // 3. Phân tích chuỗi nhận diện đặc trưng (Class name, Type property, Description)

    // A. LỚP 3D (3D Objects / 3D Shapes / Mesh)
    if ([typeStr containsString:@"3d"] || [className containsString:@"3d"] ||
        [typeStr containsString:@"mesh"] || [className containsString:@"mesh"] ||
        [typeStr containsString:@"shape3d"] || [description containsString:@"3dlayer"]) {
        return VSLayerType3D;
    }

    // B. LỚP HẠT (Particle / Dust / Sparkle / Snow / Star Layers)
    if ([typeStr containsString:@"particle"] || [className containsString:@"particle"] ||
        [typeStr containsString:@"sparkle"] || [typeStr containsString:@"dust"] ||
        [typeStr containsString:@"emitter"] || [className containsString:@"emitter"]) {
        return VSLayerTypeParticle;
    }

    // C. LỚP ZAPS (Zaps / Flash / Strobe / Transition Effect Layers)
    if ([typeStr containsString:@"zap"] || [className containsString:@"zap"] ||
        [typeStr containsString:@"flash"] || [className containsString:@"flash"] ||
        [typeStr containsString:@"strobe"] || [typeStr containsString:@"lightning"]) {
        return VSLayerTypeZaps;
    }

    // D. LỚP PHỤ / ĐỆM (Overlay / Sub / Adjustment / Blend / Matte Layers)
    if ([typeStr containsString:@"overlay"] || [className containsString:@"overlay"] ||
        [typeStr containsString:@"sublayer"] || [className containsString:@"sublayer"] ||
        [typeStr containsString:@"adjustment"] || [typeStr containsString:@"matte"] ||
        [typeStr containsString:@"mask"] || [typeStr containsString:@"blend"]) {
        return VSLayerTypeOverlay;
    }

    // E. LỚP MÀU (Color / Solid Layers)
    if ([typeStr containsString:@"color"] || [className containsString:@"color"] ||
        [typeStr containsString:@"solid"] || [className containsString:@"solid"] ||
        [typeStr containsString:@"tint"] || [description containsString:@"solidcolor"]) {
        return VSLayerTypeColor;
    }

    // F. LỚP RỖNG (Empty / Unassigned Layers)
    if ([typeStr containsString:@"empty"] || [className containsString:@"empty"] ||
        [typeStr containsString:@"none"] || [typeStr isEqualToString:@"0"]) {
        return VSLayerTypeEmpty;
    }

    // Kiểm tra Asset nội tại
    id asset = nil;
    @try {
        if ([layerObject respondsToSelector:NSSelectorFromString(@"asset")]) {
            asset = [layerObject valueForKey:@"asset"];
        } else if ([layerObject respondsToSelector:NSSelectorFromString(@"assetModel")]) {
            asset = [layerObject valueForKey:@"assetModel"];
        } else if ([layerObject respondsToSelector:NSSelectorFromString(@"mediaURL")]) {
            asset = [layerObject valueForKey:@"mediaURL"];
        }
    } @catch (NSException *e) {
        asset = nil;
    }

    if (!asset && [typeStr length] == 0) {
        return VSLayerTypeEmpty;
    }

    // G. LỚP VIDEO (Video Clip / Movie Layers)
    if ([typeStr containsString:@"video"] || [className containsString:@"video"] ||
        [typeStr containsString:@"movie"] || [typeStr containsString:@"mp4"] ||
        [typeStr containsString:@"mov"] || [asset isKindOfClass:[AVAsset class]]) {
        return VSLayerTypeVideo;
    }

    // H. LỚP HÌNH ẢNH (Image / Photo Layers)
    if ([typeStr containsString:@"image"] || [className containsString:@"image"] ||
        [typeStr containsString:@"photo"] || [typeStr containsString:@"picture"] ||
        [asset isKindOfClass:[UIImage class]]) {
        return VSLayerTypeImage;
    }

    // Nếu không khớp từ khóa cụ thể nhưng có Media/Asset
    if (asset != nil) {
        if ([asset isKindOfClass:[NSURL class]]) {
            NSString *ext = [((NSURL *)asset).pathExtension lowercaseString];
            if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"m4v"]) {
                return VSLayerTypeVideo;
            } else {
                return VSLayerTypeImage;
            }
        }
        return VSLayerTypeImage; // Mặc định nếu có asset thông thường
    }

    return VSLayerTypeUnknown;
}

#pragma mark - Filter Evaluation

- (BOOL)shouldProcessLayer:(id)layerObject
                     index:(NSInteger)index
              detectedType:(VSLayerType *)outType
                    reason:(NSString **)outReason {
    VSLayerType detected = [VSLayerFilter detectLayerType:layerObject];
    if (outType) {
        *outType = detected;
    }

    // 1. Kiểm tra Lớp Màu (Color / Solid Layers)
    if (detected == VSLayerTypeColor) {
        if (self.config.skipColorLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [Color/Solid] -> BỎ QUA (Bộ lọc Lớp Màu)", (long)index];
            return NO;
        }
    }

    // 2. Kiểm tra Lớp Rỗng (Empty Layers)
    if (detected == VSLayerTypeEmpty) {
        if (self.config.skipEmptyLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [Empty] -> BỎ QUA (Lớp rỗng/chưa gán media)", (long)index];
            return NO;
        }
    }

    // 3. Kiểm tra Lớp Phụ / Lớp Đệm (Overlay / Sub-Layers)
    if (detected == VSLayerTypeOverlay) {
        if (self.config.skipOverlayLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [Overlay/Sub] -> BỎ QUA (Bộ lọc Lớp Phụ/Đệm)", (long)index];
            return NO;
        }
    }

    // 4. Kiểm tra Lớp Zaps (Zaps / Flash Layers)
    if (detected == VSLayerTypeZaps) {
        if (self.config.skipZapLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [Zaps/Flash] -> BỎ QUA (Bộ lọc Lớp Zaps)", (long)index];
            return NO;
        }
    }

    // 5. Kiểm tra Lớp Hạt (Particle / Dust / Sparkle Layers)
    if (detected == VSLayerTypeParticle) {
        if (self.config.skipParticleLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [Particle/Sparkle] -> BỎ QUA (Bộ lọc Lớp Hạt)", (long)index];
            return NO;
        }
    }

    // 6. Kiểm tra Lớp 3D (3D Objects / 3D Shapes / Mesh Layers)
    if (detected == VSLayerType3D) {
        if (self.config.skip3DLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [3D Mesh/Shape] -> BỎ QUA (Bộ lọc Lớp 3D)", (long)index];
            return NO;
        }
    }

    // CHỈ CHO PHÉP NHẬP VÀO: Lớp Hình Ảnh (Image) và Lớp Video (Video)
    if (detected == VSLayerTypeImage) {
        if (self.config.allowImageLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [Image] -> HỢP LỆ, chuẩn bị nhập hình ảnh", (long)index];
            return YES;
        }
    }

    if (detected == VSLayerTypeVideo) {
        if (self.config.allowVideoLayers) {
            if (outReason) *outReason = [NSString stringWithFormat:@"Lớp %ld [Video] -> HỢP LỆ, chuẩn bị nhập video clip", (long)index];
            return YES;
        }
    }

    // Mọi loại khác hoặc Unknown
    if (outReason) {
        *outReason = [NSString stringWithFormat:@"Lớp %ld [%@] -> BỎ QUA (Không phải Image/Video)", (long)index, VSStringFromLayerType(detected)];
    }
    return NO;
}

@end
