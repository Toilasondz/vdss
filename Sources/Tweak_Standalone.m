//
//  Tweak_Standalone.m
//  VideoStarAutoLayerTweak
//
//  Pure Objective-C Runtime Hook (Không phụ thuộc vào Theos Logos preprocessor).
//  Dùng khi biên dịch trực tiếp bằng clang / clang++ trên macOS hoặc iOS SDK toolchain.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "VideoStarHeaders.h"
#import "VSAutoLayerManager.h"
#import "VSFloatingHUD.h"
#import "VSLayerFilter.h"

static void VSSwizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);

    BOOL didAddMethod = class_addMethod(cls,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod(cls,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

#pragma mark - UIWindow Swizzling

@interface UIWindow (VSSwizzle)
- (void)vs_makeKeyAndVisible;
@end

@implementation UIWindow (VSSwizzle)

- (void)vs_makeKeyAndVisible {
    [self vs_makeKeyAndVisible]; // Call original

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[VSFloatingHUDController sharedController] attachToWindow:self];
            [[VSAutoLayerManager sharedManager] logMessage:@"⭐ Video Star Auto-Layer Tweak (Standalone) đã tải!" type:VSLogTypeSuccess];
        });
    });
}

@end

#pragma mark - UIViewController Swizzling

@interface UIViewController (VSSwizzle)
- (void)vs_viewDidAppear:(BOOL)animated;
- (void)vs_viewWillDisappear:(BOOL)animated;
@end

@implementation UIViewController (VSSwizzle)

- (void)vs_viewDidAppear:(BOOL)animated {
    [self vs_viewDidAppear:animated]; // Call original

    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"MultiLayer"] ||
        [className containsString:@"MultiClip"] ||
        [className containsString:@"LayerEditor"] ||
        [className containsString:@"FDXMultiLayer"]) {

        [VSAutoLayerManager sharedManager].activeMultiLayerVC = self;

        NSString *readyMsg = [NSString stringWithFormat:@"Đã kết nối Editor: %@", className];
        [[VSAutoLayerManager sharedManager] logMessage:readyMsg type:VSLogTypeInfo];
    }
}

- (void)vs_viewWillDisappear:(BOOL)animated {
    [self vs_viewWillDisappear:animated]; // Call original

    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"MultiLayer"] || [className containsString:@"MultiClip"]) {
        if ([VSAutoLayerManager sharedManager].activeMultiLayerVC == self) {
            [VSAutoLayerManager sharedManager].activeMultiLayerVC = nil;
            [[VSAutoLayerManager sharedManager] logMessage:@"Đã rời khỏi Multi-Layer." type:VSLogTypeWarning];
        }
    }
}

@end

#pragma mark - Dynamic Library Entry Constructor

__attribute__((constructor))
static void VSAutoLayerInitialize(void) {
    @autoreleasepool {
        NSLog(@"[VideoStarAutoLayer] Initializing Standalone Hooks via Obj-C Runtime...");

        // Swizzle UIWindow
        VSSwizzleMethod([UIWindow class],
                        @selector(makeKeyAndVisible),
                        @selector(vs_makeKeyAndVisible));

        // Swizzle UIViewController
        VSSwizzleMethod([UIViewController class],
                        @selector(viewDidAppear:),
                        @selector(vs_viewDidAppear:));

        VSSwizzleMethod([UIViewController class],
                        @selector(viewWillDisappear:),
                        @selector(vs_viewWillDisappear:));

        // Thiết lập bộ lọc mặc định
        VSLayerFilterConfig *config = [VSLayerFilter sharedFilter].config;
        config.allowImageLayers   = YES;
        config.allowVideoLayers   = YES;
        config.skipColorLayers    = YES;
        config.skipEmptyLayers    = YES;
        config.skipOverlayLayers  = YES;
        config.skipZapLayers      = YES;
        config.skipParticleLayers = YES;
        config.skip3DLayers       = YES;

        NSLog(@"[VideoStarAutoLayer] Hooks installed successfully!");
    }
}
