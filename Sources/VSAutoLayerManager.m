//
//  VSAutoLayerManager.m
//  VideoStarAutoLayerTweak
//
//  Core Automation Engine implementation.
//

#import "VSAutoLayerManager.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString *const VSAutoLayerLogNotification = @"VSAutoLayerLogNotification";
NSString *const VSAutoLayerStatusChangeNotification = @"VSAutoLayerStatusChangeNotification";

@interface VSAutoLayerManager ()

@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign, readwrite) NSInteger totalProcessedCount;
@property (nonatomic, assign, readwrite) NSInteger successCount;
@property (nonatomic, assign, readwrite) NSInteger skippedCount;

@property (nonatomic, strong, readwrite) NSMutableArray *mediaQueue;
@property (nonatomic, strong, readwrite) NSMutableArray<NSDictionary *> *logEntries;

@property (nonatomic, assign) NSInteger currentStepIndex;
@property (nonatomic, assign) NSInteger mediaQueueReadPointer;

@end

@implementation VSAutoLayerManager

+ (instancetype)sharedManager {
    static VSAutoLayerManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[VSAutoLayerManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _filter = [VSLayerFilter sharedFilter];
        _mediaQueue = [NSMutableArray array];
        _logEntries = [NSMutableArray array];
        _stepInterval = 0.35; // 350ms giữa các lớp để đảm bảo render an toàn
        _isRunning = NO;
        _currentStepIndex = 0;
        _mediaQueueReadPointer = 0;
    }
    return self;
}

#pragma mark - Media Queue Operations

- (void)enqueueMediaURL:(NSURL *)url {
    if (!url) return;
    @synchronized (self.mediaQueue) {
        [self.mediaQueue addObject:url];
    }
    [self logMessage:[NSString stringWithFormat:@"[Hàng Đợi] Đã thêm Media: %@", url.lastPathComponent] type:VSLogTypeInfo];
}

- (void)enqueueImage:(UIImage *)image {
    if (!image) return;
    @synchronized (self.mediaQueue) {
        [self.mediaQueue addObject:image];
    }
    [self logMessage:[NSString stringWithFormat:@"[Hàng Đợi] Đã thêm Hình Ảnh (%dx%d)", (int)image.size.width, (int)image.size.height] type:VSLogTypeInfo];
}

- (void)enqueueMediaBatch:(NSArray *)mediaItems {
    if (!mediaItems || mediaItems.count == 0) return;
    @synchronized (self.mediaQueue) {
        [self.mediaQueue addObjectsFromArray:mediaItems];
    }
    [self logMessage:[NSString stringWithFormat:@"[Hàng Đợi] Đã nạp thành công %lu media items.", (unsigned long)mediaItems.count] type:VSLogTypeInfo];
}

- (void)clearMediaQueue {
    @synchronized (self.mediaQueue) {
        [self.mediaQueue removeAllObjects];
        self.mediaQueueReadPointer = 0;
    }
    [self logMessage:@"[Hàng Đợi] Đã làm trống danh sách media." type:VSLogTypeWarning];
}

#pragma mark - Logging System

- (void)logMessage:(NSString *)message type:(VSLogType)type {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    NSString *timeStr = [formatter stringFromDate:[NSDate date]];

    NSDictionary *entry = @{
        @"time": timeStr,
        @"message": message ?: @"",
        @"type": @(type),
        @"date": [NSDate date]
    };

    @synchronized (self.logEntries) {
        [self.logEntries addObject:entry];
        // Giữ tối đa 500 dòng log gần nhất để tối ưu RAM
        if (self.logEntries.count > 500) {
            [self.logEntries removeObjectAtIndex:0];
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(autoLayerDidLogMessage:type:)]) {
            [self.delegate autoLayerDidLogMessage:message type:type];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:VSAutoLayerLogNotification
                                                            object:self
                                                          userInfo:entry];
    });

    // In ra Syslog (os_log / NSLog) phục vụ debug qua Theos / SSH / idevicesyslog
    NSString *typeTag = @"INFO";
    switch (type) {
        case VSLogTypeSuccess: typeTag = @"SUCCESS"; break;
        case VSLogTypeSkip:    typeTag = @"SKIP";    break;
        case VSLogTypeWarning: typeTag = @"WARN";    break;
        case VSLogTypeError:   typeTag = @"ERROR";   break;
        default: break;
    }
    NSLog(@"[VideoStarAutoLayer][%@] %@", typeTag, message);
}

- (void)clearLogs {
    @synchronized (self.logEntries) {
        [self.logEntries removeAllObjects];
    }
    [self logMessage:@"[Console] Đã làm sạch nhật ký." type:VSLogTypeInfo];
}

#pragma mark - Controller & Layer Discovery

- (UIViewController *)findCurrentMultiLayerController {
    if (self.activeMultiLayerVC && self.activeMultiLayerVC.view.window) {
        return self.activeMultiLayerVC;
    }

    // Duyệt cây UIViewController của Key Window
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) {
            keyWindow = w;
            break;
        }
    }
    if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }

    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }

    // Kiểm tra xem topVC hoặc childVC có chứa tên MultiLayer không
    UIViewController *found = [self searchViewControllerHierarchy:topVC];
    if (found) {
        self.activeMultiLayerVC = found;
        return found;
    }

    return topVC;
}

- (UIViewController *)searchViewControllerHierarchy:(UIViewController *)vc {
    if (!vc) return nil;
    NSString *name = NSStringFromClass([vc class]);
    if ([name containsString:@"MultiLayer"] || [name containsString:@"MultiClip"] ||
        [name containsString:@"LayerEditor"] || [name containsString:@"FDXMultiLayer"]) {
        return vc;
    }

    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *match = [self searchViewControllerHierarchy:child];
        if (match) return match;
    }
    return nil;
}

- (NSArray *)extractLayersFromController:(UIViewController *)controller {
    if (!controller) return nil;

    // 1. Thử các thuộc tính phổ biến trong Video Star
    NSArray *candidates = @[@"layers", @"layerItems", @"timelineLayers", @"clipLayers", @"items", @"layerList"];
    for (NSString *key in candidates) {
        @try {
            id val = [controller valueForKey:key];
            if ([val isKindOfClass:[NSArray class]] && [val count] > 0) {
                return (NSArray *)val;
            }
        } @catch (NSException *e) {
            // Tiếp tục thử key khác
        }
    }

    // 2. Thử truy cập thông qua subviews hoặc containerView nếu có
    @try {
        id container = [controller valueForKey:@"multiLayerContainerView"];
        if (container) {
            id subLayers = [container valueForKey:@"layers"];
            if ([subLayers isKindOfClass:[NSArray class]] && [subLayers count] > 0) {
                return (NSArray *)subLayers;
            }
        }
    } @catch (NSException *e) {}

    return nil;
}

#pragma mark - Automation Process Execution

- (void)startAutoImport {
    if (self.isRunning) {
        [self logMessage:@"[Cảnh Báo] Tiến trình Automation đang chạy, vui lòng đợi!" type:VSLogTypeWarning];
        return;
    }

    UIViewController *controller = [self findCurrentMultiLayerController];
    if (!controller) {
        [self logMessage:@"[Lỗi] Không tìm thấy màn hình Multi-Layer Editor của Video Star!" type:VSLogTypeError];
        return;
    }

    NSArray *layers = [self extractLayersFromController:controller];
    if (!layers || layers.count == 0) {
        [self logMessage:[NSString stringWithFormat:@"[Lỗi] Không phát hiện Layer nào trong %@!", NSStringFromClass([controller class])] type:VSLogTypeError];
        return;
    }

    if (self.mediaQueue.count == 0) {
        [self logMessage:@"[Cảnh Báo] Chưa chọn ảnh/video nguồn. Vui lòng bấm 'Chọn Media' trước!" type:VSLogTypeWarning];
        return;
    }

    self.isRunning = YES;
    self.successCount = 0;
    self.skippedCount = 0;
    self.totalProcessedCount = 0;
    self.currentStepIndex = 0;
    self.mediaQueueReadPointer = 0;

    [self notifyStateChanged];
    [self logMessage:[NSString stringWithFormat:@"🚀 [BẮT ĐẦU] Tìm thấy %lu Lớp. Đang chạy bộ lọc và tự động nhập...", (unsigned long)layers.count] type:VSLogTypeInfo];

    [self processNextLayerInLayers:layers controller:controller];
}

- (void)stopAutoImport {
    if (!self.isRunning) return;
    self.isRunning = NO;
    [self notifyStateChanged];
    [self logMessage:@"🛑 [DỪNG] Người dùng đã dừng tiến trình tự động." type:VSLogTypeWarning];
}

- (void)processNextLayerInLayers:(NSArray *)layers controller:(UIViewController *)controller {
    if (!self.isRunning) {
        return;
    }

    if (self.currentStepIndex >= (NSInteger)layers.count) {
        // Đã quét hết tất cả các Layer
        self.isRunning = NO;
        [self notifyStateChanged];
        [self logMessage:[NSString stringWithFormat:@"✨ [HOÀN TẤT] Quét xong %ld lớp! Thành công: %ld, Bỏ qua: %ld",
                          (long)layers.count, (long)self.successCount, (long)self.skippedCount]
                    type:VSLogTypeSuccess];

        // Kích hoạt render lại preview của Video Star
        [self triggerRenderUpdateOnController:controller];

        if ([self.delegate respondsToSelector:@selector(autoLayerDidFinishWithSuccessCount:skippedCount:)]) {
            [self.delegate autoLayerDidFinishWithSuccessCount:self.successCount skippedCount:self.skippedCount];
        }
        return;
    }

    id layer = layers[self.currentStepIndex];
    NSInteger humanIndex = self.currentStepIndex + 1;

    VSLayerType detectedType = VSLayerTypeUnknown;
    NSString *reason = nil;
    BOOL shouldProcess = [self.filter shouldProcessLayer:layer
                                                   index:humanIndex
                                            detectedType:&detectedType
                                                  reason:&reason];

    if (!shouldProcess) {
        // BẮT BUỘC BỎ QUA THEO BỘ LỌC
        self.skippedCount++;
        self.totalProcessedCount++;
        [self logMessage:[NSString stringWithFormat:@"⏩ [BỎ QUA] %@", reason] type:VSLogTypeSkip];

        [self notifyProgressCurrent:self.currentStepIndex + 1 total:layers.count];

        // Chuyển sang lớp tiếp theo sau khoảng delay nhỏ
        self.currentStepIndex++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.stepInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self processNextLayerInLayers:layers controller:controller];
        });
        return;
    }

    // LỚP HỢP LỆ (Image hoặc Video) -> THỰC HIỆN NHẬP / REPLACE ASSET
    if (self.mediaQueueReadPointer >= (NSInteger)self.mediaQueue.count) {
        [self logMessage:[NSString stringWithFormat:@"⚠️ [HẾT MEDIA] Lớp %ld [%@] cần media nhưng hàng đợi đã hết!", (long)humanIndex, VSStringFromLayerType(detectedType)] type:VSLogTypeWarning];
        self.currentStepIndex++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.stepInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self processNextLayerInLayers:layers controller:controller];
        });
        return;
    }

    id mediaItem = self.mediaQueue[self.mediaQueueReadPointer];
    self.mediaQueueReadPointer++;

    BOOL success = [self applyMediaItem:mediaItem toLayer:layer index:humanIndex controller:controller];
    if (success) {
        self.successCount++;
        NSString *mediaDesc = [mediaItem isKindOfClass:[NSURL class]] ? [((NSURL *)mediaItem) lastPathComponent] : @"Ảnh từ Album";
        [self logMessage:[NSString stringWithFormat:@"✅ [THÀNH CÔNG] Đã nhập Lớp %ld [%@] -> Asset: %@", (long)humanIndex, VSStringFromLayerType(detectedType), mediaDesc] type:VSLogTypeSuccess];
    } else {
        [self logMessage:[NSString stringWithFormat:@"❌ [THẤT BẠI] Không thể áp dụng media vào Lớp %ld", (long)humanIndex] type:VSLogTypeError];
    }

    self.totalProcessedCount++;
    [self notifyProgressCurrent:self.currentStepIndex + 1 total:layers.count];

    self.currentStepIndex++;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.stepInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processNextLayerInLayers:layers controller:controller];
    });
}

#pragma mark - Media Injection / Replacement Execution

- (BOOL)applyMediaItem:(id)mediaItem
               toLayer:(id)layer
                 index:(NSInteger)index
            controller:(UIViewController *)controller {
    if (!layer) return NO;

    BOOL applied = NO;

    // 1. Nếu mediaItem là NSURL (Video hoặc File ảnh)
    if ([mediaItem isKindOfClass:[NSURL class]]) {
        NSURL *url = (NSURL *)mediaItem;

        // A. Thử gọi trực tiếp selector trên Layer
        if ([layer respondsToSelector:NSSelectorFromString(@"replaceWithMediaURL:")]) {
            void (*func)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
            func(layer, NSSelectorFromString(@"replaceWithMediaURL:"), url);
            applied = YES;
        } else if ([layer respondsToSelector:NSSelectorFromString(@"setMediaURL:")]) {
            [layer setValue:url forKey:@"mediaURL"];
            applied = YES;
        } else if ([layer respondsToSelector:NSSelectorFromString(@"setAssetURL:")]) {
            [layer setValue:url forKey:@"assetURL"];
            applied = YES;
        }

        // B. Nếu layer chưa nhận, thử gọi qua Controller
        if (!applied) {
            if ([controller respondsToSelector:NSSelectorFromString(@"importMediaForLayer:withURL:")]) {
                void (*func)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
                func(controller, NSSelectorFromString(@"importMediaForLayer:withURL:"), layer, url);
                applied = YES;
            } else if ([controller respondsToSelector:NSSelectorFromString(@"replaceLayerMediaAtIndex:withURL:")]) {
                void (*func)(id, SEL, NSInteger, id) = (void (*)(id, SEL, NSInteger, id))objc_msgSend;
                func(controller, NSSelectorFromString(@"replaceLayerMediaAtIndex:withURL:"), index - 1, url);
                applied = YES;
            }
        }

        // C. Nếu là file ảnh, đọc thành UIImage và set
        if (!applied) {
            UIImage *img = [UIImage imageWithContentsOfFile:url.path];
            if (img) {
                return [self applyMediaItem:img toLayer:layer index:index controller:controller];
            }
        }
    }
    // 2. Nếu mediaItem là UIImage
    else if ([mediaItem isKindOfClass:[UIImage class]]) {
        UIImage *img = (UIImage *)mediaItem;

        if ([layer respondsToSelector:NSSelectorFromString(@"replaceWithImage:")]) {
            void (*func)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
            func(layer, NSSelectorFromString(@"replaceWithImage:"), img);
            applied = YES;
        } else if ([layer respondsToSelector:NSSelectorFromString(@"setImage:")]) {
            [layer setValue:img forKey:@"image"];
            applied = YES;
        } else if ([layer respondsToSelector:NSSelectorFromString(@"setCachedImage:")]) {
            [layer setValue:img forKey:@"cachedImage"];
            applied = YES;
        }

        if (!applied) {
            if ([controller respondsToSelector:NSSelectorFromString(@"importImageForLayer:image:")]) {
                void (*func)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
                func(controller, NSSelectorFromString(@"importImageForLayer:image:"), layer, img);
                applied = YES;
            }
        }
    }

    return applied;
}

- (void)triggerRenderUpdateOnController:(UIViewController *)controller {
    if (!controller) return;

    NSArray *renderSelectors = @[@"renderPreview", @"updatePreview", @"refreshAllLayers", @"reloadLayers", @"redraw"];
    for (NSString *selName in renderSelectors) {
        SEL sel = NSSelectorFromString(selName);
        if ([controller respondsToSelector:sel]) {
            void (*func)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
            func(controller, sel);
            break;
        }
    }
    [controller.view setNeedsLayout];
    [controller.view setNeedsDisplay];
}

#pragma mark - Notification & Delegate Helpers

- (void)notifyStateChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(autoLayerStateChanged:)]) {
            [self.delegate autoLayerStateChanged:self.isRunning];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:VSAutoLayerStatusChangeNotification object:self];
    });
}

- (void)notifyProgressCurrent:(NSInteger)curr total:(NSInteger)tot {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(autoLayerProgressUpdated:total:)]) {
            [self.delegate autoLayerProgressUpdated:curr total:tot];
        }
    });
}

@end
