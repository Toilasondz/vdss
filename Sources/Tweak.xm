//
//  Tweak.xm
//  VideoStarAutoLayerTweak
//
//  Logos Hook File for Video Star iOS.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "VideoStarHeaders.h"
#import "VSAutoLayerManager.h"
#import "VSFloatingHUD.h"
#import "VSLayerFilter.h"

#pragma mark - Hook UIWindow

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[VSFloatingHUDController sharedController] attachToWindow:self];
            [[VSAutoLayerManager sharedManager] logMessage:@"⭐ Video Star Auto-Layer Tweak đã tải thành công!" type:VSLogTypeSuccess];
        });
    });
}

%end

#pragma mark - Hook UIViewController (Tự động nhận diện Multi-Layer Editor)

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    NSString *className = NSStringFromClass([self class]);

    // Nhận diện khi người dùng bước vào màn hình Multi-Layer Clip
    if ([className containsString:@"MultiLayer"] ||
        [className containsString:@"MultiClip"] ||
        [className containsString:@"LayerEditor"] ||
        [className containsString:@"FDXMultiLayer"]) {

        [VSAutoLayerManager sharedManager].activeMultiLayerVC = self;

        NSString *readyMsg = [NSString stringWithFormat:@"Đã kết nối Editor: %@", className];
        [[VSAutoLayerManager sharedManager] logMessage:readyMsg type:VSLogTypeInfo];

        // Tự động kiểm tra số lượng Layer hiện có
        NSArray *layers = [[VSAutoLayerManager sharedManager] extractLayersFromController:self];
        if (layers) {
            NSString *layerMsg = [NSString stringWithFormat:@"Phát hiện %lu Lớp trong Multi-Layer.", (unsigned long)layers.count];
            [[VSAutoLayerManager sharedManager] logMessage:layerMsg type:VSLogTypeInfo];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);

    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"MultiLayer"] || [className containsString:@"MultiClip"]) {
        if ([VSAutoLayerManager sharedManager].activeMultiLayerVC == self) {
            [VSAutoLayerManager sharedManager].activeMultiLayerVC = nil;
            [[VSAutoLayerManager sharedManager] logMessage:@"Đã rời khỏi màn hình Multi-Layer." type:VSLogTypeWarning];
        }
    }
}

%end

#pragma mark - Constructor Initializer

%ctor {
    @autoreleasepool {
        NSLog(@"[VideoStarAutoLayer] === Injecting Tweak Dynamic Library ===");

        // Đảm bảo Filter mặc định đã được khởi tạo theo đúng yêu cầu
        VSLayerFilterConfig *config = [VSLayerFilter sharedFilter].config;
        config.allowImageLayers   = YES;
        config.allowVideoLayers   = YES;
        config.skipColorLayers    = YES;
        config.skipEmptyLayers    = YES;
        config.skipOverlayLayers  = YES;
        config.skipZapLayers      = YES;
        config.skipParticleLayers = YES;
        config.skip3DLayers       = YES;

        NSLog(@"[VideoStarAutoLayer] Filter configured: Only Image & Video permitted. 6 layer types skipped.");
    }
}
