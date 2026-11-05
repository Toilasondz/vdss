// ============================================================
//  VS40Layers.m  –  Video Star 14 Unlock 40 Layers Patch
//  Author: hson
//  Target: Video Star 14.x (iOS 14.0+)
//  Architecture: arm64
//
//  Mo khoa toi da 40 lop trong Multi-Layer Video Star 14.
//  Hook dong qua Objective-C Runtime + Auto Scanner
// ============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define TARGET_LAYERS_COUNT 40

#pragma mark - Hook Implementations

// Return integer 40
static NSInteger vs40_return_integer(id self, SEL _cmd) {
    return TARGET_LAYERS_COUNT;
}

static NSUInteger vs40_return_uinteger(id self, SEL _cmd) {
    return (NSUInteger)TARGET_LAYERS_COUNT;
}

static int vs40_return_int(id self, SEL _cmd) {
    return (int)TARGET_LAYERS_COUNT;
}

// Return YES (cho phep them lop, mo khoa tinh nang)
static BOOL vs40_return_YES(id self, SEL _cmd) {
    return YES;
}

static BOOL vs40_return_YES_withArg(id self, SEL _cmd, id arg) {
    return YES;
}

static BOOL vs40_return_YES_withInt(id self, SEL _cmd, NSInteger idx) {
    return YES;
}

// Return NO (chua dat gioi han lop)
static BOOL vs40_return_NO(id self, SEL _cmd) {
    return NO;
}

#pragma mark - Helper Hook Functions

static BOOL HookMethod(Class cls, const char *selName, IMP newIMP, const char *types) {
    if (!cls) return NO;
    SEL sel = sel_registerName(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, newIMP);
        NSLog(@"[VS40] ✅ Swizzled: -[%s %s]", class_getName(cls), selName);
        return YES;
    } else {
        if (class_addMethod(cls, sel, newIMP, types ? types : "q@:")) {
            NSLog(@"[VS40] ➕ Added: -[%s %s]", class_getName(cls), selName);
            return YES;
        }
    }
    return NO;
}

static BOOL HookClassMethod(Class cls, const char *selName, IMP newIMP, const char *types) {
    if (!cls) return NO;
    Class metaCls = object_getClass((id)cls);
    return HookMethod(metaCls, selName, newIMP, types);
}

#pragma mark - Toast Notification

static void ShowToast40Layers(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
                break;
            }
        }
        if (!window) {
            window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }

        window.windowLevel = UIWindowLevelAlert + 100;
        window.backgroundColor = [UIColor clearColor];
        window.userInteractionEnabled = NO;

        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat bannerWidth = MIN(screenBounds.size.width - 32, 380);
        CGFloat bannerHeight = 68;
        CGFloat bannerX = (screenBounds.size.width - bannerWidth) / 2;

        UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(bannerX, -100, bannerWidth, bannerHeight)];
        banner.backgroundColor = [UIColor colorWithRed:0.06 green:0.09 blue:0.14 alpha:0.96];
        banner.layer.cornerRadius = 16;
        banner.layer.borderColor = [UIColor colorWithRed:0.00 green:0.80 blue:1.00 alpha:0.9].CGColor;
        banner.layer.borderWidth = 1.8;
        banner.layer.shadowColor = [UIColor blackColor].CGColor;
        banner.layer.shadowRadius = 12;
        banner.layer.shadowOpacity = 0.6;
        banner.layer.shadowOffset = CGSizeMake(0, 4);

        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(16, 18, 32, 32)];
        icon.image = [UIImage systemImageNamed:@"star.fill"];
        icon.tintColor = [UIColor colorWithRed:0.00 green:0.85 blue:1.00 alpha:1.0];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [banner addSubview:icon];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(58, 12, bannerWidth - 70, 22)];
        title.text = @"⚡ Video Star 14: ĐÃ MỞ KHÓA 40 LỚP";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
        [banner addSubview:title];

        UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(58, 34, bannerWidth - 70, 20)];
        sub.text = @"Multi-Layer Limit: 40 Lớp  ·  Tác giả: hson";
        sub.textColor = [UIColor colorWithRed:0.00 green:0.80 blue:1.00 alpha:0.95];
        sub.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
        [banner addSubview:sub];

        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        [rootVC.view addSubview:banner];
        window.rootViewController = rootVC;
        window.hidden = NO;

        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.6 options:0 animations:^{
            banner.frame = CGRectMake(bannerX, 55, bannerWidth, bannerHeight);
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.4 animations:^{
                    banner.alpha = 0.0;
                    banner.transform = CGAffineTransformMakeTranslation(0, -60);
                } completion:^(BOOL f) {
                    window.hidden = YES;
                }];
            });
        }];
    });
}

#pragma mark - Apply Specific Video Star Known Hooks

static void ApplyKnownHooks(void) {
    static const char *layerCountSelectors[] = {
        "maxLayers", "maximumLayers", "maxNumberOfLayers",
        "maximumNumberOfLayers", "maxAllowedLayers", "allowedLayersCount",
        "allowedLayerCount", "maximumLayerCount", "maxLayerCount",
        "layerLimit", "maxLayerLimit", "maxLayersAllowed",
        "deviceMaxLayers", "maxMultiLayers", "maxMultiLayerCount",
        "maxTracks", "maxClips", "layerCountMax", "maxSupportedLayers",
        "maxLayersForCurrentDevice", "availableLayersCount", "maxLayerIndex",
        NULL
    };

    static const char *returnYESSelectors[] = {
        "canAddLayer", "canAddMoreLayers", "canAddAnotherLayer",
        "allowExtraLayers", "supports40Layers", "isMultiLayerPackPurchased",
        "isMultiLayerPurchased", "hasMultiLayerPass", "hasAllAccessPass",
        "isAllAccessActive", "isAllAccessSubscribed", "isPro", "isProUser",
        "canUseMultiLayer", NULL
    };

    static const char *returnNOSelectors[] = {
        "isAtMaxLayers", "isLayerLimitReached", "hasReachedMaxLayers",
        "isMaxLayersExceeded", "isLayerCountCapped", NULL
    };

    const char *classPrefixes[] = {
        "FDXMultiLayer", "FDXMultiClip", "FDXLayer", "FDXProject",
        "FDXComposition", "FDXTimeline", "FDXEditor", "VSMultiLayer",
        "MultiLayer", "MultiClip", "LayerEditor", "Timeline", NULL
    };

    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return;

    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);

    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        const char *className = class_getName(cls);

        if (strncmp(className, "NS", 2) == 0 ||
            strncmp(className, "UI", 2) == 0 ||
            strncmp(className, "_", 1)  == 0 ||
            strncmp(className, "CA", 2) == 0 ||
            strncmp(className, "AV", 2) == 0) {
            continue;
        }

        BOOL isRelevantClass = NO;
        for (int p = 0; classPrefixes[p] != NULL; p++) {
            if (strstr(className, classPrefixes[p]) != NULL) {
                isRelevantClass = YES;
                break;
            }
        }

        if (isRelevantClass) {
            for (int s = 0; layerCountSelectors[s] != NULL; s++) {
                SEL sel = sel_registerName(layerCountSelectors[s]);
                if (class_getInstanceMethod(cls, sel)) {
                    HookMethod(cls, layerCountSelectors[s], (IMP)vs40_return_integer, "q@:");
                }
                if (class_getClassMethod(cls, sel)) {
                    HookClassMethod(cls, layerCountSelectors[s], (IMP)vs40_return_integer, "q@:");
                }
            }

            for (int s = 0; returnYESSelectors[s] != NULL; s++) {
                SEL sel = sel_registerName(returnYESSelectors[s]);
                if (class_getInstanceMethod(cls, sel)) {
                    HookMethod(cls, returnYESSelectors[s], (IMP)vs40_return_YES, "B@:");
                }
            }

            for (int s = 0; returnNOSelectors[s] != NULL; s++) {
                SEL sel = sel_registerName(returnNOSelectors[s]);
                if (class_getInstanceMethod(cls, sel)) {
                    HookMethod(cls, returnNOSelectors[s], (IMP)vs40_return_NO, "B@:");
                }
            }
        }
    }

    free(classes);
}

#pragma mark - Smart Dynamic Runtime Scanner (Quet toan dien Video Star 14)

static void SmartScanAndHookAllClasses(void) {
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return;

    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);

    int hookedMethodsCount = 0;

    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        const char *className = class_getName(cls);

        if (strncmp(className, "NS", 2) == 0 ||
            strncmp(className, "UI", 2) == 0 ||
            strncmp(className, "_", 1)  == 0 ||
            strncmp(className, "CA", 2) == 0 ||
            strncmp(className, "CF", 2) == 0 ||
            strncmp(className, "AV", 2) == 0) {
            continue;
        }

        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        if (!methods) continue;

        for (unsigned int m = 0; m < methodCount; m++) {
            SEL sel = method_getName(methods[m]);
            const char *selName = sel_getName(sel);
            if (!selName) continue;

            NSString *selStr = [NSString stringWithCString:selName encoding:NSASCIIStringEncoding].lowercaseString;
            char *retType = method_copyReturnType(methods[m]);
            if (!retType) continue;

            BOOL isIntegerReturn = (retType[0] == 'i' || retType[0] == 'I' ||
                                    retType[0] == 'q' || retType[0] == 'Q' ||
                                    retType[0] == 'l' || retType[0] == 'L' ||
                                    retType[0] == 's' || retType[0] == 'S');

            BOOL isBoolReturn = (retType[0] == 'B' || retType[0] == 'c');

            if (isIntegerReturn) {
                if ([selStr containsString:@"maxlayer"] ||
                    [selStr containsString:@"layerlimit"] ||
                    [selStr containsString:@"maximumlayer"] ||
                    [selStr containsString:@"maxallowedlayer"] ||
                    [selStr containsString:@"allowedlayer"] ||
                    [selStr containsString:@"maxmultilayers"] ||
                    [selStr containsString:@"maxmulticlip"] ||
                    [selStr containsString:@"layercountmax"] ||
                    [selStr containsString:@"devicemaxlayer"] ||
                    [selStr containsString:@"maxtracks"]) {

                    method_setImplementation(methods[m], (IMP)vs40_return_integer);
                    hookedMethodsCount++;
                    NSLog(@"[VS40 Scanner] 🎯 Replaced (40): -[%s %s]", className, selName);
                }
            }

            if (isBoolReturn) {
                if ([selStr containsString:@"isatmaxlayer"] ||
                    [selStr containsString:@"layerlimitreached"] ||
                    [selStr containsString:@"reachedmaxlayer"] ||
                    [selStr containsString:@"islayercountcapped"]) {

                    method_setImplementation(methods[m], (IMP)vs40_return_NO);
                    hookedMethodsCount++;
                    NSLog(@"[VS40 Scanner] 🎯 Replaced (NO): -[%s %s]", className, selName);
                }
                else if ([selStr containsString:@"canaddlayer"] ||
                         [selStr containsString:@"canaddmorelayer"] ||
                         [selStr containsString:@"allowextralayer"] ||
                         [selStr containsString:@"hasmultilayer"] ||
                         [selStr containsString:@"hasallaccess"]) {

                    method_setImplementation(methods[m], (IMP)vs40_return_YES);
                    hookedMethodsCount++;
                    NSLog(@"[VS40 Scanner] 🎯 Replaced (YES): -[%s %s]", className, selName);
                }
            }

            free(retType);
        }
        free(methods);
    }

    free(classes);
    NSLog(@"[VS40] 🚀 Total methods automatically patched: %d", hookedMethodsCount);
}

#pragma mark - Constructor (Dylib entry point)

__attribute__((constructor))
static void VS40LayersInit(void) {
    @autoreleasepool {
        NSLog(@"====================================================");
        NSLog(@"⚡ Video Star 14 Unlock 40 Layers Patch by hson");
        NSLog(@"⚡ Setting Max Multi-Layers limit to %d...", TARGET_LAYERS_COUNT);
        NSLog(@"====================================================");

        ApplyKnownHooks();
        SmartScanAndHookAllClasses();
        ShowToast40Layers();

        NSLog(@"[VS40] ✅ 40 Layers Patch installed successfully!");
    }
}
