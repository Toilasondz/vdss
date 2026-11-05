// ============================================================
//  Tweak_Standalone.m  –  VideoStar Tool by hson
//  Single-file standalone dylib – NO Theos required
//  Build: clang -fobjc-arc -shared -framework UIKit
//         -framework Foundation -framework Photos
//         -framework PhotosUI -o VideoStarTool.dylib
//         Tweak_Standalone.m
// ============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

// ─── Constants ───────────────────────────────────────────────
#define kTitle    @"VideoStar Tool"
#define kAuthor   @"by hson"
#define kFooter   @"VIDEOSTAR  ·  HSON"
#define kVersion  @"V2.0"
#define kDefaults @"hson.vstool"

// ─── Color helpers (White/Light theme) ───────────────────────
static UIColor *kAccent(void)   { return [UIColor colorWithRed:0.00 green:0.48 blue:1.00 alpha:1.0]; }
static UIColor *kPanelBg(void)  { return [UIColor colorWithRed:0.97 green:0.97 blue:0.98 alpha:1.0]; }
static UIColor *kCardBg(void)   { return [UIColor whiteColor]; }
static UIColor *kTextMain(void) { return [UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:1.0]; }
static UIColor *kTextSub(void)  { return [UIColor colorWithRed:0.45 green:0.45 blue:0.50 alpha:1.0]; }
static UIColor *kSep(void)      { return [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:1.0]; }

// ─── Globals ─────────────────────────────────────────────────
static UIWindow       *gWindow     = nil;
static BOOL            gVisible    = NO;

// ─── Layer type classification ────────────────────────────────
// Video Star layer types we detect from class name / description
// ALLOW: image (Ảnh chụp), GIF (Ảnh GIF)
// SKIP : empty(Lớp Rỗng), color(Màu), draw(Vẽ), text(Văn bản),
//        animtext(Chữ động), zaps(Zaps!), particle(Hạt), 3d(Vật 3D), overlay(Lớp Phủ)

typedef NS_ENUM(NSInteger, VSLayerKind) {
    VSLayerKindUnknown   = 0,
    VSLayerKindImage     = 1,  // Ảnh chụp
    VSLayerKindGIF       = 2,  // Ảnh GIF
    VSLayerKindEmpty     = 3,  // Lớp Rỗng  → skip
    VSLayerKindColor     = 4,  // Màu        → skip
    VSLayerKindDraw      = 5,  // Vẽ         → skip
    VSLayerKindText      = 6,  // Văn bản    → skip
    VSLayerKindAnimText  = 7,  // Chữ động   → skip
    VSLayerKindZaps      = 8,  // Zaps!      → skip
    VSLayerKindParticle  = 9,  // Hạt        → skip
    VSLayerKind3D        = 10, // Vật 3D     → skip
    VSLayerKindOverlay   = 11, // Lớp Phủ    → skip
};

static VSLayerKind classifyLayer(id layer) {
    if (!layer) return VSLayerKindUnknown;
    NSString *cn = NSStringFromClass([layer class]);
    // Check numeric type property first
    for (NSString *kp in @[@"layerType", @"type", @"clipType", @"mediaType", @"kind"]) {
        if ([layer respondsToSelector:NSSelectorFromString(kp)]) {
            id val = [layer valueForKey:kp];
            if ([val isKindOfClass:[NSNumber class]]) {
                NSInteger t = [val integerValue];
                // Video Star common type integers (from reverse engineering):
                // 0 = empty, 1 = image/photo, 2 = video, 3 = color, 4 = draw
                // 5 = text, 6 = animtext, 7 = zaps, 8 = particle, 9 = 3d, 10 = overlay
                // 11 = GIF
                if (t == 1 || t == 2) return VSLayerKindImage;
                if (t == 11)         return VSLayerKindGIF;
                if (t == 0)          return VSLayerKindEmpty;
                if (t == 3)          return VSLayerKindColor;
                if (t == 4)          return VSLayerKindDraw;
                if (t == 5 || t == 6)return VSLayerKindText;
                if (t == 7)          return VSLayerKindZaps;
                if (t == 8)          return VSLayerKindParticle;
                if (t == 9)          return VSLayerKind3D;
                if (t == 10)         return VSLayerKindOverlay;
            }
        }
    }
    // Fallback: classify by class name keywords
    NSString *lc = [cn lowercaseString];
    if ([lc containsString:@"photo"] || [lc containsString:@"image"] || [lc containsString:@"picture"])
        return VSLayerKindImage;
    if ([lc containsString:@"gif"])   return VSLayerKindGIF;
    if ([lc containsString:@"empty"]) return VSLayerKindEmpty;
    if ([lc containsString:@"color"]) return VSLayerKindColor;
    if ([lc containsString:@"draw"])  return VSLayerKindDraw;
    if ([lc containsString:@"text"])  return VSLayerKindText;
    if ([lc containsString:@"zap"])   return VSLayerKindZaps;
    if ([lc containsString:@"particle"] || [lc containsString:@"hat"]) return VSLayerKindParticle;
    if ([lc containsString:@"3d"] || [lc containsString:@"vat3d"] || [lc containsString:@"object3d"]) return VSLayerKind3D;
    if ([lc containsString:@"overlay"] || [lc containsString:@"phủ"]) return VSLayerKindOverlay;
    return VSLayerKindUnknown;
}

static BOOL isAllowedLayer(id layer) {
    VSLayerKind k = classifyLayer(layer);
    return (k == VSLayerKindImage || k == VSLayerKindGIF || k == VSLayerKindUnknown);
}

// ─── Runtime helpers ──────────────────────────────────────────
static id safeValue(id obj, NSString *key) {
    @try { return [obj valueForKey:key]; } @catch(...) { return nil; }
}
static BOOL safeSet(id obj, NSString *key, id val) {
    @try { [obj setValue:val forKey:key]; return YES; } @catch(...) { return NO; }
}
static id safePerform(id obj, NSString *selStr) {
    SEL sel = NSSelectorFromString(selStr);
    if ([obj respondsToSelector:sel]) {
        return ((id(*)(id,SEL))objc_msgSend)(obj, sel);
    }
    return nil;
}
static id safePerformWith(id obj, NSString *selStr, id arg) {
    SEL sel = NSSelectorFromString(selStr);
    if ([obj respondsToSelector:sel]) {
        return ((id(*)(id,SEL,id))objc_msgSend)(obj, sel, arg);
    }
    return nil;
}

// ─── Find topmost VC ──────────────────────────────────────────
static UIViewController *topVC(void) {
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    // Skip our own overlay window's VC
    if ([NSStringFromClass([vc class]) containsString:@"VST"]) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w == gWindow) continue;
            UIViewController *root = w.rootViewController;
            while (root.presentedViewController) root = root.presentedViewController;
            if (root) { vc = root; break; }
        }
    }
    return vc;
}

// ─── Find array of layers from VC ────────────────────────────
static NSArray *findLayers(UIViewController *vc) {
    if (!vc) return nil;
    NSArray *keys = @[@"layers", @"layerItems", @"clipItems", @"clips",
                      @"timelineLayers", @"multiLayers", @"items",
                      @"layerArray", @"clipArray", @"model.layers",
                      @"viewModel.layers", @"project.layers", @"document.layers",
                      @"editor.layers", @"composition.layers"];
    for (NSString *key in keys) {
        @try {
            id val = [vc valueForKeyPath:key];
            if ([val isKindOfClass:[NSArray class]] && [(NSArray*)val count] > 0)
                return (NSArray *)val;
        } @catch(...) {}
    }
    // Try subviews: find UITableView or UICollectionView, get data source items
    NSMutableArray *found = [NSMutableArray array];
    NSArray *subviews = vc.view.subviews;
    NSMutableArray *queue = [subviews mutableCopy];
    while (queue.count > 0) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        [queue addObjectsFromArray:v.subviews];
        if ([v isKindOfClass:[UICollectionView class]]) {
            UICollectionView *cv = (UICollectionView *)v;
            id ds = cv.dataSource;
            if (!ds) continue;
            for (NSString *k in keys) {
                @try {
                    id val = [ds valueForKeyPath:k];
                    if ([val isKindOfClass:[NSArray class]]) { [found addObjectsFromArray:val]; break; }
                } @catch(...) {}
            }
        }
        if ([v isKindOfClass:[UITableView class]]) {
            UITableView *tv = (UITableView *)v;
            id ds = tv.dataSource;
            if (!ds) continue;
            for (NSString *k in keys) {
                @try {
                    id val = [ds valueForKeyPath:k];
                    if ([val isKindOfClass:[NSArray class]]) { [found addObjectsFromArray:val]; break; }
                } @catch(...) {}
            }
        }
    }
    return found.count > 0 ? found : nil;
}

// ─── Set image on a layer object ─────────────────────────────
static BOOL applyImageToLayer(id layer, UIImage *image) {
    // Try various known setters
    NSArray *selectors = @[
        @"setImage:", @"setPhoto:", @"setPicture:", @"setMediaImage:",
        @"setSourceImage:", @"setLayerImage:", @"setContent:",
        @"setBackgroundImage:", @"loadImage:", @"importImage:"
    ];
    for (NSString *sel in selectors) {
        SEL s = NSSelectorFromString(sel);
        if ([layer respondsToSelector:s]) {
            ((void(*)(id,SEL,id))objc_msgSend)(layer, s, image);
            NSLog(@"[VST] ✅ Applied image via %@", sel);
            return YES;
        }
    }
    // Try KVC
    for (NSString *key in @[@"image", @"photo", @"picture", @"sourceImage", @"content"]) {
        if (safeSet(layer, key, image)) {
            NSLog(@"[VST] ✅ Applied image via KVC key: %@", key);
            return YES;
        }
    }
    NSLog(@"[VST] ⚠️ Could not apply image to layer: %@", NSStringFromClass([layer class]));
    return NO;
}

// ============================================================
#pragma mark - VSTToggleCell
// ============================================================
@interface VSTToggleCell : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, copy)   NSString *key;
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key;
@end

@implementation VSTToggleCell

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)sub key:(NSString *)key {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _key = [key copy];
    self.backgroundColor = kCardBg();
    self.translatesAutoresizingMaskIntoConstraints = NO;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = title;
    self.titleLabel.textColor = kTextMain();
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text = sub;
    self.subtitleLabel.textColor = kTextSub();
    self.subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.subtitleLabel];

    self.toggle = [[UISwitch alloc] init];
    self.toggle.onTintColor = kAccent();
    self.toggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@.%@", kDefaults, key]];
    [self.toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.toggle];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.toggle.leadingAnchor constant:-8],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.toggle.leadingAnchor constant:-8],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
        [self.toggle.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.toggle.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:60]
    ]];

    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = kSep();
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:sep];
    [NSLayoutConstraint activateConstraints:@[
        [sep.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [sep.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [sep.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5]
    ]];
    return self;
}

- (void)switchChanged:(UISwitch *)s {
    NSString *fullKey = [NSString stringWithFormat:@"%@.%@", kDefaults, self.key];
    [[NSUserDefaults standardUserDefaults] setBool:s.isOn forKey:fullKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isOn { return self.toggle.isOn; }
@end

// ============================================================
#pragma mark - VSTActionButton
// ============================================================
@interface VSTActionButton : UIButton
@end
@implementation VSTActionButton
- (instancetype)initWithTitle:(NSString *)t icon:(NSString *)icon {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = kAccent();
    self.layer.cornerRadius = 12;
    self.layer.masksToBounds = YES;

    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon]];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:iv];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = t;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:lbl];

    [NSLayoutConstraint activateConstraints:@[
        [iv.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
        [iv.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [iv.widthAnchor constraintEqualToConstant:20],
        [iv.heightAnchor constraintEqualToConstant:20],
        [lbl.leadingAnchor constraintEqualToAnchor:iv.trailingAnchor constant:8],
        [lbl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.heightAnchor constraintEqualToConstant:48]
    ]];
    return self;
}
@end

// ============================================================
#pragma mark - VSTStatusView  (log line)
// ============================================================
@interface VSTStatusView : UIView
@property (nonatomic, strong) UILabel *label;
- (void)setMessage:(NSString *)msg isError:(BOOL)err;
@end
@implementation VSTStatusView
- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.06];
    self.layer.cornerRadius = 8;
    self.label = [[UILabel alloc] init];
    self.label.text = @"Sẵn sàng";
    self.label.textColor = kTextSub();
    self.label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.label.numberOfLines = 2;
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.label];
    [NSLayoutConstraint activateConstraints:@[
        [self.label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [self.label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [self.label.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
        [self.label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6],
    ]];
    return self;
}
- (void)setMessage:(NSString *)msg isError:(BOOL)err {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.label.text = msg;
        self.label.textColor = err ? [UIColor systemRedColor] : kTextSub();
    });
}
@end

// ============================================================
#pragma mark - VSTCoreEngine  (business logic)
// ============================================================
@interface VSTCoreEngine : NSObject <PHPickerViewControllerDelegate>
+ (instancetype)shared;
@property (nonatomic, weak) VSTStatusView *statusView;
@property (nonatomic, strong) NSMutableArray *pendingLayers; // layers awaiting image
- (void)runAutoImportPhoto;
- (void)runAutoSplitBeat;
- (void)dumpLayerInfo;
@end

@implementation VSTCoreEngine

+ (instancetype)shared {
    static VSTCoreEngine *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [self new]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    _pendingLayers = [NSMutableArray array];
    return self;
}

- (void)log:(NSString *)msg error:(BOOL)err {
    NSLog(@"[VST] %@", msg);
    [self.statusView setMessage:msg isError:err];
}

// ─── Auto Import Photo ───────────────────────────────────────
- (void)runAutoImportPhoto {
    UIViewController *vc = topVC();
    NSArray *layers = findLayers(vc);

    if (!layers || layers.count == 0) {
        // Fallback: check all VCs in hierarchy
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            UIViewController *root = w.rootViewController;
            while (root) {
                layers = findLayers(root);
                if (layers.count > 0) break;
                root = root.presentedViewController;
            }
            if (layers.count > 0) break;
        }
    }

    // Filter to only allowed layers
    NSMutableArray *eligible = [NSMutableArray array];
    for (id layer in layers) {
        if (isAllowedLayer(layer)) [eligible addObject:layer];
    }

    NSInteger totalLayers = layers.count;
    NSInteger eligibleCount = eligible.count;

    if (eligibleCount == 0) {
        // Still show picker – we'll apply to all visible image layer cells via UI
        [self log:[NSString stringWithFormat:@"⚠️ Tìm thấy %ld lớp nhưng không detect được loại. Thử cách UI...", (long)totalLayers] error:NO];
        self.pendingLayers = nil;
    } else {
        [self log:[NSString stringWithFormat:@"✅ Tìm thấy %ld/%ld lớp hợp lệ → Đang mở picker...", (long)eligibleCount, (long)totalLayers] error:NO];
        self.pendingLayers = eligible;
    }

    // Open PHPicker
    dispatch_async(dispatch_get_main_queue(), ^{
        PHPickerConfiguration *cfg = [[PHPickerConfiguration alloc] init];
        cfg.selectionLimit = 1;
        cfg.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:cfg];
        picker.delegate = self;

        // Present on the app's real VC (not our overlay VC)
        UIViewController *presentVC = topVC();
        [presentVC presentViewController:picker animated:YES completion:nil];
    });
}

// ─── PHPickerViewControllerDelegate ──────────────────────────
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) {
        [self log:@"❌ Không có ảnh nào được chọn." error:YES];
        return;
    }

    [self log:@"⏳ Đang tải ảnh..." error:NO];

    PHPickerResult *result = results.firstObject;
    [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError *error) {
        if (!image || error) {
            [self log:@"❌ Lỗi tải ảnh." error:YES];
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyImage:image toLayers:self.pendingLayers];
        });
    }];
}

// ─── Apply image to layers ───────────────────────────────────
- (void)applyImage:(UIImage *)image toLayers:(NSArray *)layers {
    if (layers == nil) {
        // Fallback: try applying via UI cell traversal
        [self applyImageViaCellTraversal:image];
        return;
    }

    __block NSInteger successCount = 0;
    __block NSInteger skipCount = 0;

    for (id layer in layers) {
        VSLayerKind kind = classifyLayer(layer);
        if (kind == VSLayerKindEmpty || kind == VSLayerKindColor ||
            kind == VSLayerKindDraw  || kind == VSLayerKindText  ||
            kind == VSLayerKindAnimText || kind == VSLayerKindZaps ||
            kind == VSLayerKindParticle || kind == VSLayerKind3D  ||
            kind == VSLayerKindOverlay) {
            skipCount++;
            NSLog(@"[VST] ⏭ Bỏ qua lớp: %@ (kind=%ld)", NSStringFromClass([layer class]), (long)kind);
            continue;
        }
        BOOL ok = applyImageToLayer(layer, image);
        if (ok) successCount++;
    }

    // Trigger re-render / refresh
    UIViewController *vc = topVC();
    safePerform(vc, @"reloadData");
    safePerform(vc, @"refresh");
    safePerform(vc, @"setNeedsDisplay");
    id model = safeValue(vc, @"model") ?: safeValue(vc, @"viewModel");
    if (model) {
        safePerform(model, @"notifyChanged");
        safePerform(model, @"reloadLayers");
    }
    for (UIView *sub in vc.view.subviews) {
        if ([sub isKindOfClass:[UICollectionView class]] || [sub isKindOfClass:[UITableView class]]) {
            [sub performSelector:@selector(reloadData)];
        }
    }

    NSString *msg = [NSString stringWithFormat:@"✅ Nhập ảnh: %ld lớp thành công, %ld lớp bỏ qua",
                     (long)successCount, (long)skipCount];
    [self log:msg error:NO];

    if (successCount == 0) {
        // Show alert for manual instruction
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Hướng dẫn thủ công"
            message:@"Không thể tự động nhập ảnh vào các lớp.\n\nHãy mở từng lớp Ảnh chụp rồi chọn ảnh thủ công.\n\n(Tool đang phân tích class Video Star để cập nhật trong phiên bản sau)"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [topVC() presentViewController:alert animated:YES completion:nil];
    }
}

// ─── Fallback: traverse UICollectionView cells ───────────────
- (void)applyImageViaCellTraversal:(UIImage *)image {
    // Try to find UICollectionView cells representing layers
    NSMutableArray *queue = [NSMutableArray array];
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        [queue addObject:w];
    }
    __block NSInteger count = 0;
    NSMutableArray *viewQueue = [NSMutableArray array];
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        [viewQueue addObject:w];
    }
    while (viewQueue.count > 0) {
        UIView *v = viewQueue.firstObject;
        [viewQueue removeObjectAtIndex:0];
        [viewQueue addObjectsFromArray:v.subviews];
        // Look for UIImageView inside cells
        if ([v isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)v;
            // Only set if inside a collection/table cell
            UIView *parent = v.superview;
            while (parent) {
                if ([parent isKindOfClass:NSClassFromString(@"UICollectionViewCell")] ||
                    [parent isKindOfClass:NSClassFromString(@"UITableViewCell")]) {
                    iv.image = image;
                    count++;
                    break;
                }
                parent = parent.superview;
            }
        }
    }
    if (count > 0) {
        [self log:[NSString stringWithFormat:@"✅ (Fallback) Đã set ảnh cho %ld UIImageView trong cells", (long)count] error:NO];
    } else {
        [self log:@"⚠️ Không tìm thấy cell nào. Cần class dump Video Star để hỗ trợ đầy đủ." error:YES];
    }
}

// ─── Auto Split Beat ─────────────────────────────────────────
- (void)runAutoSplitBeat {
    UIViewController *vc = topVC();
    NSString *vcClass = NSStringFromClass([vc class]);
    [self log:[NSString stringWithFormat:@"⏳ Đang tìm timeline... VC: %@", vcClass] error:NO];

    // Try known selectors for splitting/adding cuts at beats
    NSArray *splitSelectors = @[
        @"splitAtBeatMarkers", @"splitClipAtBeatMarkers",
        @"autoSplitByBeat", @"splitByRedMarkers",
        @"addCutAtBeatMarkers", @"cutAtBeats",
        @"splitAllAtMarkers", @"applyBeatSplit"
    ];

    for (NSString *sel in splitSelectors) {
        if ([vc respondsToSelector:NSSelectorFromString(sel)]) {
            ((void(*)(id,SEL))objc_msgSend)(vc, NSSelectorFromString(sel));
            [self log:[NSString stringWithFormat:@"✅ Đã gọi: %@", sel] error:NO];
            return;
        }
        // Try on model
        id model = safeValue(vc, @"model") ?: safeValue(vc, @"viewModel") ?: safeValue(vc, @"document");
        if (model && [model respondsToSelector:NSSelectorFromString(sel)]) {
            ((void(*)(id,SEL))objc_msgSend)(model, NSSelectorFromString(sel));
            [self log:[NSString stringWithFormat:@"✅ Đã gọi trên model: %@", sel] error:NO];
            return;
        }
    }

    // Fallback: find beat/marker positions and simulate split
    [self trySplitViaMarkers:vc];
}

- (void)trySplitViaMarkers:(UIViewController *)vc {
    // Try to find the timeline/scrubber view and read beat positions
    id timeline = nil;
    for (NSString *key in @[@"timeline", @"timelineView", @"scrubber", @"beatView", @"waveformView"]) {
        @try { timeline = [vc valueForKey:key]; } @catch(...) {}
        if (timeline) break;
    }

    if (!timeline) {
        // Show alert with instructions
        [self log:@"⚠️ Không tìm thấy timeline. Thử ở màn hình Timeline/Editor." error:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Auto Chia Beat"
                message:@"Chức năng này cần được thực hiện trong màn hình Timeline của Video Star.\n\nHướng dẫn:\n1. Vào màn hình Timeline\n2. Thêm vạch đỏ (beat markers)\n3. Bấm 'Auto Chia Beat' lại\n\n(Đang phân tích cấu trúc Video Star...)"
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [topVC() presentViewController:alert animated:YES completion:nil];
        });
        return;
    }

    // Get marker positions
    NSArray *markers = nil;
    for (NSString *k in @[@"beatMarkers", @"markers", @"cuts", @"beatPositions"]) {
        @try { markers = [timeline valueForKey:k]; } @catch(...) {}
        if ([markers isKindOfClass:[NSArray class]]) break;
    }

    if (markers.count == 0) {
        [self log:@"⚠️ Không có vạch đỏ nào trên timeline." error:YES];
        return;
    }

    NSInteger splitCount = 0;
    for (id marker in markers) {
        // Try to split at each marker position
        CGFloat time = 0;
        @try { time = [[marker valueForKey:@"time"] floatValue]; } @catch(...) {}
        if (time <= 0) @try { time = [[marker valueForKey:@"position"] floatValue]; } @catch(...) {}

        SEL splitSel = NSSelectorFromString(@"splitClipAtTime:");
        if ([vc respondsToSelector:splitSel]) {
            ((void(*)(id,SEL,CGFloat))objc_msgSend)(vc, splitSel, time);
            splitCount++;
        }
    }

    if (splitCount > 0) {
        [self log:[NSString stringWithFormat:@"✅ Đã chia %ld đoạn theo vạch đỏ", (long)splitCount] error:NO];
    } else {
        [self log:@"⚠️ Tìm thấy timeline nhưng không thể chia. Cần thêm thông tin class." error:YES];
    }
}

// ─── Layer Info Dump (debug) ──────────────────────────────────
- (void)dumpLayerInfo {
    UIViewController *vc = topVC();
    NSMutableString *info = [NSMutableString string];
    [info appendFormat:@"VC: %@\n", NSStringFromClass([vc class])];

    NSArray *layers = findLayers(vc);
    if (layers.count == 0) {
        [info appendString:@"❌ Không tìm thấy layer nào.\n"];
        [info appendString:@"Các VC đang active:\n"];
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            UIViewController *root = w.rootViewController;
            while (root) {
                [info appendFormat:@"  - %@\n", NSStringFromClass([root class])];
                root = root.presentedViewController;
            }
        }
    } else {
        [info appendFormat:@"✅ Tìm thấy %ld layers:\n", (long)layers.count];
        for (id layer in layers) {
            [info appendFormat:@"  - %@ (kind=%ld)\n", NSStringFromClass([layer class]), (long)classifyLayer(layer)];
        }
    }

    NSLog(@"[VST DUMP]\n%@", info);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Layer Info"
            message:info
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [UIPasteboard generalPasteboard].string = info;
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [topVC() presentViewController:alert animated:YES completion:nil];
    });
}

@end

// ============================================================
#pragma mark - VSTPanel
// ============================================================
@interface VSTPanel : UIView
@property (nonatomic, strong) VSTStatusView *statusView;
@property (nonatomic, strong) VSTToggleCell *cellAutoImport;
@property (nonatomic, strong) VSTToggleCell *cellAutoBeat;
- (void)handleAutoImport;
- (void)handleAutoBeat;
- (void)handleDump;
@end

@implementation VSTPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = kPanelBg();
    self.layer.cornerRadius = 20;
    self.layer.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.18].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 8);
    self.layer.shadowRadius = 20;
    self.layer.shadowOpacity = 1.0;
    self.layer.masksToBounds = NO;
    [self build];
    return self;
}

- (void)build {
    // ── Header ──────────────────────────────────────────
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = kAccent();
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:header];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"star.fill"]];
    icon.tintColor = [UIColor whiteColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:icon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = kTitle;
    titleLbl.textColor = [UIColor whiteColor];
    titleLbl.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:titleLbl];

    UILabel *authorLbl = [[UILabel alloc] init];
    authorLbl.text = kAuthor @"  " kVersion;
    authorLbl.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.80];
    authorLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    authorLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:authorLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *xImg = [UIImage systemImageNamed:@"xmark.circle.fill"];
    [closeBtn setImage:xImg forState:UIControlStateNormal];
    closeBtn.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.80];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // ── Scroll / content ─────────────────────────────────
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [self addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    // ── Section: Cài đặt ─────────────────────────────────
    UILabel *sec1 = [self sectionLabel:@"⚙️  CÀI ĐẶT"];
    [content addSubview:sec1];

    self.cellAutoImport = [[VSTToggleCell alloc] initWithTitle:@"Auto Nhập Ảnh"
        subtitle:@"Chọn 1 ảnh → nhập vào tất cả lớp hình ảnh"
        key:@"autoImport"];
    [content addSubview:self.cellAutoImport];

    self.cellAutoBeat = [[VSTToggleCell alloc] initWithTitle:@"Auto Chia Beat"
        subtitle:@"Tự động chia đoạn theo vạch đỏ trên timeline"
        key:@"autoBeat"];
    [content addSubview:self.cellAutoBeat];

    // ── Section: Hành động ───────────────────────────────
    UILabel *sec2 = [self sectionLabel:@"▶  HÀNH ĐỘNG"];
    [content addSubview:sec2];

    VSTActionButton *btnImport = [[VSTActionButton alloc] initWithTitle:@"Nhập Ảnh Vào Các Lớp" icon:@"photo.on.rectangle.angled"];
    [btnImport addTarget:self action:@selector(handleAutoImport) forControlEvents:UIControlEventTouchUpInside];
    btnImport.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:btnImport];

    VSTActionButton *btnBeat = [[VSTActionButton alloc] initWithTitle:@"Chia Đoạn Theo Vạch Đỏ" icon:@"waveform.path.ecg"];
    [btnBeat addTarget:self action:@selector(handleAutoBeat) forControlEvents:UIControlEventTouchUpInside];
    btnBeat.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:btnBeat];

    VSTActionButton *btnDump = [[VSTActionButton alloc] initWithTitle:@"Kiểm Tra Layer Info" icon:@"info.circle"];
    [btnDump addTarget:self action:@selector(handleDump) forControlEvents:UIControlEventTouchUpInside];
    btnDump.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    btnDump.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:btnDump];

    // ── Status view ───────────────────────────────────────
    self.statusView = [[VSTStatusView alloc] init];
    [content addSubview:self.statusView];
    [VSTCoreEngine shared].statusView = self.statusView;

    // ── Footer ───────────────────────────────────────────
    UILabel *footer = [[UILabel alloc] init];
    footer.text = kFooter;
    footer.textColor = kTextSub();
    footer.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    footer.textAlignment = NSTextAlignmentCenter;
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:footer];

    // ── Constraints ───────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        // Header
        [header.topAnchor constraintEqualToAnchor:self.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:60],

        [icon.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [icon.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22],

        [titleLbl.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:8],
        [titleLbl.topAnchor constraintEqualToAnchor:header.topAnchor constant:12],
        [authorLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [authorLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:1],

        [closeBtn.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-12],
        [closeBtn.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [closeBtn.widthAnchor constraintEqualToConstant:30],
        [closeBtn.heightAnchor constraintEqualToConstant:30],

        // Scroll
        [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        // Content in scroll
        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],

        // Section 1
        [sec1.topAnchor constraintEqualToAnchor:content.topAnchor constant:12],
        [sec1.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [sec1.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        // Toggle cells
        [self.cellAutoImport.topAnchor constraintEqualToAnchor:sec1.bottomAnchor constant:4],
        [self.cellAutoImport.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.cellAutoImport.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],

        [self.cellAutoBeat.topAnchor constraintEqualToAnchor:self.cellAutoImport.bottomAnchor],
        [self.cellAutoBeat.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.cellAutoBeat.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],

        // Section 2
        [sec2.topAnchor constraintEqualToAnchor:self.cellAutoBeat.bottomAnchor constant:16],
        [sec2.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [sec2.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        // Action buttons
        [btnImport.topAnchor constraintEqualToAnchor:sec2.bottomAnchor constant:8],
        [btnImport.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [btnImport.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [btnBeat.topAnchor constraintEqualToAnchor:btnImport.bottomAnchor constant:10],
        [btnBeat.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [btnBeat.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [btnDump.topAnchor constraintEqualToAnchor:btnBeat.bottomAnchor constant:10],
        [btnDump.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [btnDump.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        // Status
        [self.statusView.topAnchor constraintEqualToAnchor:btnDump.bottomAnchor constant:12],
        [self.statusView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.statusView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        // Footer
        [footer.topAnchor constraintEqualToAnchor:self.statusView.bottomAnchor constant:12],
        [footer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],
    ]];

    // Rounded top corners for header
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,0,400,60)
        byRoundingCorners:(UIRectCornerTopLeft|UIRectCornerTopRight)
        cornerRadii:CGSizeMake(20,20)];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    header.layer.mask = mask;
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = text;
    lbl.textColor = kAccent();
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    return lbl;
}

- (void)closePanel {
    gVisible = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL f) {
        self.hidden = YES;
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    }];
}

- (void)handleAutoImport {
    [[VSTCoreEngine shared] runAutoImportPhoto];
}

- (void)handleAutoBeat {
    [[VSTCoreEngine shared] runAutoSplitBeat];
}

- (void)handleDump {
    [[VSTCoreEngine shared] dumpLayerInfo];
}

@end

// ============================================================
#pragma mark - VSTFloatButton
// ============================================================
@interface VSTFloatButton : UIView
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, assign) CGPoint lastLocation;
@end

@implementation VSTFloatButton

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0, 0, 54, 54)];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *bv = [[UIVisualEffectView alloc] initWithEffect:blur];
    bv.frame = self.bounds;
    bv.layer.cornerRadius = 27;
    bv.layer.masksToBounds = YES;
    [self addSubview:bv];

    self.button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *img = [UIImage systemImageNamed:@"star.fill"];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    img = [img imageByApplyingSymbolConfiguration:cfg];
    [self.button setImage:img forState:UIControlStateNormal];
    self.button.tintColor = kAccent();
    self.button.frame = self.bounds;
    [self.button addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.button];

    // Shadow
    self.layer.shadowColor = [kAccent() CGColor];
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 8;
    self.layer.shadowOpacity = 0.4;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    [self addGestureRecognizer:pan];
    return self;
}

- (void)tapped {
    UIView *panel = nil;
    for (UIView *sub in self.superview.subviews) {
        if ([sub isKindOfClass:[VSTPanel class]]) { panel = sub; break; }
    }
    if (!panel) return;

    gVisible = !gVisible;
    if (gVisible) {
        panel.hidden = NO;
        panel.alpha = 0;
        panel.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:0 animations:^{
            panel.alpha = 1;
            panel.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.22 animations:^{
            panel.alpha = 0;
            panel.transform = CGAffineTransformMakeScale(0.95, 0.95);
        } completion:^(BOOL f) {
            panel.hidden = YES;
            panel.alpha = 1;
            panel.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)panned:(UIPanGestureRecognizer *)g {
    CGPoint delta = [g translationInView:self.superview];
    CGPoint center = self.center;
    center.x += delta.x;
    center.y += delta.y;
    // Keep in bounds
    CGRect bounds = self.superview.bounds;
    center.x = MAX(32, MIN(center.x, bounds.size.width - 32));
    center.y = MAX(60, MIN(center.y, bounds.size.height - 60));
    self.center = center;
    [g setTranslation:CGPointZero inView:self.superview];
}

@end

// ============================================================
#pragma mark - VSTWindow
// ============================================================
@interface VSTWindow : UIWindow
@end
@implementation VSTWindow

- (BOOL)canBecomeKeyWindow { return NO; }

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];

    // If a modal/picker is being presented, let events through to it
    UIViewController *root = self.rootViewController;
    if (root.presentedViewController) return hit;

    // Allow hits on float button and panel
    if (hit && hit != self && ![hit isKindOfClass:[UIWindow class]]) return hit;
    return nil; // passthrough to Video Star
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // If presenting a modal, intercept all touches so user can interact with picker
    UIViewController *root = self.rootViewController;
    if (root.presentedViewController) return YES;

    // Check float button
    for (UIView *sub in self.rootViewController.view.subviews) {
        if ([sub isKindOfClass:[VSTFloatButton class]] && !sub.hidden) {
            CGPoint p = [self convertPoint:point toView:sub];
            if ([sub pointInside:p withEvent:event]) return YES;
        }
        if ([sub isKindOfClass:[VSTPanel class]] && !sub.hidden) {
            CGPoint p = [self convertPoint:point toView:sub];
            if ([sub pointInside:p withEvent:event]) return YES;
        }
    }
    return NO;
}

@end

// ============================================================
#pragma mark - Setup
// ============================================================
static void VSTSetupOverlay(void) {
    if (gWindow) return;

    // Create overlay window
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    }

    if (@available(iOS 13.0, *)) {
        gWindow = [[VSTWindow alloc] initWithWindowScene:scene];
    } else {
        gWindow = [[VSTWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    gWindow.windowLevel = UIWindowLevelStatusBar + 1;
    gWindow.backgroundColor = [UIColor clearColor];
    gWindow.userInteractionEnabled = YES;

    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    gWindow.rootViewController = rootVC;
    [gWindow makeKeyAndVisible];

    UIView *container = rootVC.view;

    // Panel
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat panelW = MIN(300, screenBounds.size.width - 40);
    CGFloat panelH = MIN(480, screenBounds.size.height - 100);
    CGFloat panelX = (screenBounds.size.width - panelW) / 2;
    CGFloat panelY = 80;
    VSTPanel *panel = [[VSTPanel alloc] initWithFrame:CGRectMake(panelX, panelY, panelW, panelH)];
    panel.hidden = YES;
    [container addSubview:panel];

    // Float button
    VSTFloatButton *floatBtn = [[VSTFloatButton alloc] init];
    floatBtn.center = CGPointMake(screenBounds.size.width - 42, 120);
    [container addSubview:floatBtn];

    NSLog(@"[VST] ✅ Overlay initialized. Tool: %@ %@", kTitle, kVersion);
}

// ============================================================
#pragma mark - Runtime Hooks via Swizzling
// ============================================================
static void swizzle(Class cls, SEL orig, SEL swiz) {
    Method om = class_getInstanceMethod(cls, orig);
    Method sm = class_getInstanceMethod(cls, swiz);
    if (!om || !sm) return;
    if (class_addMethod(cls, orig, method_getImplementation(sm), method_getTypeEncoding(sm)))
        class_replaceMethod(cls, swiz, method_getImplementation(om), method_getTypeEncoding(om));
    else
        method_exchangeImplementations(om, sm);
}

@interface UIApplication (VSTHook)
- (void)vst_sendEvent:(UIEvent *)event;
@end
@implementation UIApplication (VSTHook)
- (void)vst_sendEvent:(UIEvent *)event {
    // Ensure overlay window stays on top
    if (gWindow && gWindow.windowLevel < UIWindowLevelStatusBar + 1) {
        gWindow.windowLevel = UIWindowLevelStatusBar + 1;
    }
    [self vst_sendEvent:event];
}
@end

// ============================================================
#pragma mark - Constructor (dylib entry point)
// ============================================================
__attribute__((constructor))
static void VSTInitialize(void) {
    @autoreleasepool {
        NSLog(@"[VST] 🚀 Loading VideoStar Tool %@ by hson...", kVersion);

        // Swizzle UIApplication.sendEvent to keep our window on top
        swizzle([UIApplication class],
                @selector(sendEvent:),
                @selector(vst_sendEvent:));

        // Delay setup to let app launch first
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            VSTSetupOverlay();
        });

        NSLog(@"[VST] ✅ Hooks installed.");
    }
}
