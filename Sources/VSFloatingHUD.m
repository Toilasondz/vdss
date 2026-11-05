//
//  VSFloatingHUD.m
//  VideoStarAutoLayerTweak
//
//  Dark Mode Glassmorphism Floating Window HUD Implementation.
//

#import "VSFloatingHUD.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#define NEON_CYAN   [UIColor colorWithRed:0.00 green:0.94 blue:1.00 alpha:1.00]
#define NEON_PURPLE [UIColor colorWithRed:0.66 green:0.33 blue:0.97 alpha:1.00]
#define NEON_GREEN  [UIColor colorWithRed:0.06 green:0.80 blue:0.55 alpha:1.00]
#define NEON_AMBER  [UIColor colorWithRed:0.96 green:0.62 blue:0.04 alpha:1.00]
#define NEON_ROSE   [UIColor colorWithRed:0.96 green:0.25 blue:0.37 alpha:1.00]

#pragma mark - 1. Floating Bubble View (Nút Toggle Trôi Nổi)

@interface VSFloatingBubbleView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, assign) CGPoint initialPanCenter;
@end

@implementation VSFloatingBubbleView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.layer.cornerRadius = self.bounds.size.width / 2.0;
    self.layer.masksToBounds = NO;
    self.backgroundColor = [UIColor clearColor];

    // Neon Glow & Shadow
    self.layer.shadowColor = NEON_CYAN.CGColor;
    self.layer.shadowRadius = 10.0;
    self.layer.shadowOpacity = 0.75;
    self.layer.shadowOffset = CGSizeZero;

    // Glassmorphism Blur Effect
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.frame = self.bounds;
    self.blurView.layer.cornerRadius = self.bounds.size.width / 2.0;
    self.blurView.layer.masksToBounds = YES;
    self.blurView.layer.borderWidth = 1.5;
    self.blurView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    self.blurView.userInteractionEnabled = NO;
    [self addSubview:self.blurView];

    // Icon "VS" Neon
    self.iconLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.iconLabel.text = @"VS✦";
    self.iconLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightBlack];
    self.iconLabel.textColor = NEON_CYAN;
    self.iconLabel.textAlignment = NSTextAlignmentCenter;
    self.iconLabel.userInteractionEnabled = NO;
    [self addSubview:self.iconLabel];

    // Tap Gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self addGestureRecognizer:tap];

    // Pan Gesture (Kéo thả bám mép màn hình)
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
}

- (void)handleTap {
    // Hiệu ứng nảy nhẹ khi bấm
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];

    if (self.onTapHandler) {
        self.onTapHandler();
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *superview = self.superview;
    if (!superview) return;

    CGPoint translation = [pan translationInView:superview];

    if (pan.state == UIGestureRecognizerStateBegan) {
        self.initialPanCenter = self.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(self.initialPanCenter.x + translation.x,
                                  self.initialPanCenter.y + translation.y);
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // Hít về mép trái hoặc mép phải màn hình
        CGFloat screenWidth = superview.bounds.size.width;
        CGFloat screenHeight = superview.bounds.size.height;
        CGFloat halfWidth = self.bounds.size.width / 2.0;

        CGFloat targetX = (self.center.x < screenWidth / 2.0) ? (halfWidth + 12.0) : (screenWidth - halfWidth - 12.0);
        CGFloat targetY = MIN(MAX(self.center.y, 80.0), screenHeight - 90.0);

        [UIView animateWithDuration:0.4
                              delay:0.0
             usingSpringWithDamping:0.75
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.center = CGPointMake(targetX, targetY);
        } completion:nil];
    }
}

- (void)resetPosition {
    UIView *superview = self.superview;
    if (!superview) return;
    self.center = CGPointMake(superview.bounds.size.width - 40.0, 160.0);
}

@end

#pragma mark - 2. Main HUD Panel (Bảng Điều Khiển Glassmorphism)

@interface VSMainHUDPanel () <UIScrollViewDelegate>

@property (nonatomic, strong) UIVisualEffectView *blurContainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusBadge;
@property (nonatomic, strong) UILabel *mediaCountLabel;

@property (nonatomic, strong) UIButton *pickMediaButton;
@property (nonatomic, strong) UIButton *startAutoButton;
@property (nonatomic, strong) UIButton *clearLogButton;
@property (nonatomic, strong) UIButton *closeButton;

// Switches cho bộ lọc
@property (nonatomic, strong) UISwitch *switchSkipColor;
@property (nonatomic, strong) UISwitch *switchSkipEmpty;
@property (nonatomic, strong) UISwitch *switchSkipOverlay;
@property (nonatomic, strong) UISwitch *switchSkipZaps;
@property (nonatomic, strong) UISwitch *switchSkipParticle;
@property (nonatomic, strong) UISwitch *switchSkip3D;

// Console Log View
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) NSMutableAttributedString *logAttributedString;

@end

@implementation VSMainHUDPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _logAttributedString = [[NSMutableAttributedString alloc] init];
        [self setupGlassPanel];
    }
    return self;
}

- (void)setupGlassPanel {
    self.layer.cornerRadius = 24.0;
    self.layer.masksToBounds = NO;
    self.backgroundColor = [UIColor clearColor];

    // Shadow đa tầng sang trọng
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowRadius = 24.0;
    self.layer.shadowOpacity = 0.65;
    self.layer.shadowOffset = CGSizeMake(0, 12);

    // Glassmorphism Blur Effect
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurContainer = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurContainer.frame = self.bounds;
    self.blurContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blurContainer.layer.cornerRadius = 24.0;
    self.blurContainer.layer.masksToBounds = YES;
    self.blurContainer.layer.borderWidth = 1.2;
    self.blurContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    [self addSubview:self.blurContainer];

    UIView *content = self.blurContainer.contentView;

    // --- Header ---
    UIView *dragHandle = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - 40) / 2.0, 8, 40, 4)];
    dragHandle.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
    dragHandle.layer.cornerRadius = 2.0;
    [content addSubview:dragHandle];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 18, 220, 24)];
    self.titleLabel.text = @"⭐ VS AUTO-LAYER PRO";
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy];
    self.titleLabel.textColor = NEON_CYAN;
    [content addSubview:self.titleLabel];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(self.bounds.size.width - 44, 14, 30, 30);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.7] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [self.closeButton addTarget:self action:@selector(handleClose) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.closeButton];

    // --- Media Status & Buttons ---
    self.mediaCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 48, self.bounds.size.width - 36, 18)];
    self.mediaCountLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.mediaCountLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    self.mediaCountLabel.text = @"📁 Hàng đợi: 0 media đã chọn";
    [content addSubview:self.mediaCountLabel];

    CGFloat btnWidth = (self.bounds.size.width - 46) / 2.0;

    // Nút "Chọn Media"
    self.pickMediaButton = [self createStyledButtonWithTitle:@"📁 Chọn Media"
                                                    bgColor:[UIColor colorWithWhite:1.0 alpha:0.12]
                                                 titleColor:[UIColor whiteColor]
                                                      frame:CGRectMake(18, 74, btnWidth, 38)];
    [self.pickMediaButton addTarget:self action:@selector(handlePickMedia) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.pickMediaButton];

    // Nút "Bắt Đầu Auto Import"
    self.startAutoButton = [self createStyledButtonWithTitle:@"⚡ Auto Import"
                                                    bgColor:[NEON_GREEN colorWithAlphaComponent:0.35]
                                                 titleColor:NEON_GREEN
                                                      frame:CGRectMake(28 + btnWidth, 74, btnWidth, 38)];
    self.startAutoButton.layer.borderColor = NEON_GREEN.CGColor;
    self.startAutoButton.layer.borderWidth = 1.0;
    [self.startAutoButton addTarget:self action:@selector(handleToggleAutoImport) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.startAutoButton];

    // --- Bộ Lọc (Filter Switches) Grid 2 Cột ---
    UILabel *filterSectionTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, 122, 200, 16)];
    filterSectionTitle.text = @"⚙️ BỘ LỌC TỰ ĐỘNG BỎ QUA (SKIP RULES)";
    filterSectionTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    filterSectionTitle.textColor = NEON_PURPLE;
    [content addSubview:filterSectionTitle];

    VSLayerFilterConfig *cfg = [VSLayerFilter sharedFilter].config;
    CGFloat switchY = 142.0;
    CGFloat colW = (self.bounds.size.width - 36) / 2.0;

    // Hàng 1: Color & Empty
    self.switchSkipColor   = [self addFilterItem:@"Bỏ qua Color" on:cfg.skipColorLayers frame:CGRectMake(18, switchY, colW, 28) action:@selector(filterChanged:)];
    self.switchSkipEmpty   = [self addFilterItem:@"Bỏ qua Empty" on:cfg.skipEmptyLayers frame:CGRectMake(18 + colW, switchY, colW, 28) action:@selector(filterChanged:)];

    // Hàng 2: Overlay & Zaps
    self.switchSkipOverlay = [self addFilterItem:@"Bỏ qua Overlay" on:cfg.skipOverlayLayers frame:CGRectMake(18, switchY + 32, colW, 28) action:@selector(filterChanged:)];
    self.switchSkipZaps    = [self addFilterItem:@"Bỏ qua Zaps" on:cfg.skipZapLayers frame:CGRectMake(18 + colW, switchY + 32, colW, 28) action:@selector(filterChanged:)];

    // Hàng 3: Particle & 3D
    self.switchSkipParticle= [self addFilterItem:@"Bỏ qua Particle" on:cfg.skipParticleLayers frame:CGRectMake(18, switchY + 64, colW, 28) action:@selector(filterChanged:)];
    self.switchSkip3D      = [self addFilterItem:@"Bỏ qua 3D" on:cfg.skip3DLayers frame:CGRectMake(18 + colW, switchY + 64, colW, 28) action:@selector(filterChanged:)];

    // --- Real-time Console Log Header & Clear Button ---
    CGFloat logTop = switchY + 102.0;

    UILabel *consoleTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, logTop, 160, 18)];
    consoleTitle.text = @"📟 NHẬT KÝ THỜI GIAN THỰC";
    consoleTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    consoleTitle.textColor = NEON_CYAN;
    [content addSubview:consoleTitle];

    self.clearLogButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearLogButton.frame = CGRectMake(self.bounds.size.width - 80, logTop - 4, 62, 22);
    [self.clearLogButton setTitle:@"Xoá Log" forState:UIControlStateNormal];
    [self.clearLogButton setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.6] forState:UIControlStateNormal];
    self.clearLogButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [self.clearLogButton addTarget:self action:@selector(handleClearLog) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.clearLogButton];

    // --- Terminal Log Console (UITextView) ---
    CGFloat logHeight = self.bounds.size.height - logTop - 32.0;
    UIView *terminalBox = [[UIView alloc] initWithFrame:CGRectMake(18, logTop + 22, self.bounds.size.width - 36, logHeight)];
    terminalBox.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:0.85];
    terminalBox.layer.cornerRadius = 14.0;
    terminalBox.layer.borderWidth = 1.0;
    terminalBox.layer.borderColor = [NEON_CYAN colorWithAlphaComponent:0.35].CGColor;
    terminalBox.layer.masksToBounds = YES;
    [content addSubview:terminalBox];

    self.logTextView = [[UITextView alloc] initWithFrame:CGRectInset(terminalBox.bounds, 6, 6)];
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.editable = NO;
    self.logTextView.selectable = YES;
    self.logTextView.font = [UIFont fontWithName:@"Menlo-Regular" size:10.5] ?: [UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightRegular];
    self.logTextView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [terminalBox addSubview:self.logTextView];

    [self appendLogEntry:@"[SẴN SÀNG] VS Auto-Layer Pro đã kích hoạt." type:VSLogTypeInfo];
    [self refreshStatus];
}

#pragma mark - UI Component Factories

- (UIButton *)createStyledButtonWithTitle:(NSString *)title
                                  bgColor:(UIColor *)bgColor
                               titleColor:(UIColor *)textColor
                                    frame:(CGRect)frame {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.backgroundColor = bgColor;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:textColor forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    btn.layer.cornerRadius = 12.0;
    btn.layer.masksToBounds = YES;
    return btn;
}

- (UISwitch *)addFilterItem:(NSString *)label on:(BOOL)isOn frame:(CGRect)frame action:(SEL)action {
    UIView *container = [[UIView alloc] initWithFrame:frame];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 4, frame.size.width - 54, 20)];
    lbl.text = label;
    lbl.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    [container addSubview:lbl];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.transform = CGAffineTransformMakeScale(0.72, 0.72);
    sw.frame = CGRectMake(frame.size.width - 50, -2, 40, 24);
    sw.on = isOn;
    sw.onTintColor = NEON_PURPLE;
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [container addSubview:sw];

    [self.blurContainer.contentView addSubview:container];
    return sw;
}

#pragma mark - Filter & Button Actions

- (void)filterChanged:(id)sender {
    VSLayerFilterConfig *cfg = [VSLayerFilter sharedFilter].config;
    cfg.skipColorLayers    = self.switchSkipColor.isOn;
    cfg.skipEmptyLayers    = self.switchSkipEmpty.isOn;
    cfg.skipOverlayLayers  = self.switchSkipOverlay.isOn;
    cfg.skipZapLayers      = self.switchSkipZaps.isOn;
    cfg.skipParticleLayers = self.switchSkipParticle.isOn;
    cfg.skip3DLayers       = self.switchSkip3D.isOn;

    [[VSAutoLayerManager sharedManager] logMessage:@"[Bộ Lọc] Đã cập nhật trạng thái các quy tắc lọc!" type:VSLogTypeInfo];
}

- (void)handlePickMedia {
    [[VSFloatingHUDController sharedController] presentMediaPicker];
}

- (void)handleToggleAutoImport {
    VSAutoLayerManager *mgr = [VSAutoLayerManager sharedManager];
    if (mgr.isRunning) {
        [mgr stopAutoImport];
    } else {
        [mgr startAutoImport];
    }
}

- (void)handleClose {
    if (self.onCloseHandler) {
        self.onCloseHandler();
    }
}

- (void)handleClearLog {
    [[VSAutoLayerManager sharedManager] clearLogs];
    [self clearLogView];
}

#pragma mark - Dynamic Log & Status Updates

- (void)refreshStatus {
    VSAutoLayerManager *mgr = [VSAutoLayerManager sharedManager];
    self.mediaCountLabel.text = [NSString stringWithFormat:@"📁 Hàng đợi: %lu media đã chọn", (unsigned long)mgr.mediaQueue.count];

    if (mgr.isRunning) {
        [self.startAutoButton setTitle:@"🛑 Dừng Lại" forState:UIControlStateNormal];
        self.startAutoButton.backgroundColor = [NEON_ROSE colorWithAlphaComponent:0.35];
        self.startAutoButton.layer.borderColor = NEON_ROSE.CGColor;
        [self.startAutoButton setTitleColor:NEON_ROSE forState:UIControlStateNormal];
    } else {
        [self.startAutoButton setTitle:@"⚡ Auto Import" forState:UIControlStateNormal];
        self.startAutoButton.backgroundColor = [NEON_GREEN colorWithAlphaComponent:0.35];
        self.startAutoButton.layer.borderColor = NEON_GREEN.CGColor;
        [self.startAutoButton setTitleColor:NEON_GREEN forState:UIControlStateNormal];
    }
}

- (void)appendLogEntry:(NSString *)message type:(VSLogType)type {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm:ss"];
    NSString *time = [df stringFromDate:[NSDate date]];

    UIColor *color = [UIColor whiteColor];
    NSString *prefix = @"[INFO]";

    switch (type) {
        case VSLogTypeSuccess:
            color = NEON_GREEN;
            prefix = @"[OK]";
            break;
        case VSLogTypeSkip:
            color = NEON_AMBER;
            prefix = @"[SKIP]";
            break;
        case VSLogTypeWarning:
            color = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
            prefix = @"[WARN]";
            break;
        case VSLogTypeError:
            color = NEON_ROSE;
            prefix = @"[ERR]";
            break;
        default:
            color = NEON_CYAN;
            prefix = @"[INFO]";
            break;
    }

    NSString *formatted = [NSString stringWithFormat:@"[%@] %@ %@\n", time, prefix, message];
    NSDictionary *attrs = @{
        NSForegroundColorAttributeName: color,
        NSFontAttributeName: self.logTextView.font ?: [UIFont systemFontOfSize:10.5]
    };

    NSAttributedString *attributedPart = [[NSAttributedString alloc] initWithString:formatted attributes:attrs];
    [self.logAttributedString appendAttributedString:attributedPart];
    self.logTextView.attributedText = self.logAttributedString;

    // Tự động cuộn xuống dòng mới nhất
    if (self.logTextView.text.length > 0) {
        NSRange bottom = NSMakeRange(self.logTextView.text.length - 1, 1);
        [self.logTextView scrollRangeToVisible:bottom];
    }
}

- (void)clearLogView {
    self.logAttributedString = [[NSMutableAttributedString alloc] init];
    self.logTextView.attributedText = self.logAttributedString;
}

@end

#pragma mark - 3. Floating HUD Controller

@interface VSFloatingHUDController ()
@property (nonatomic, strong, readwrite) UIWindow *hudWindow;
@property (nonatomic, strong, readwrite) VSFloatingBubbleView *bubbleView;
@property (nonatomic, strong, readwrite) VSMainHUDPanel *mainPanel;
@property (nonatomic, assign, readwrite) BOOL isPanelVisible;
@end

@implementation VSFloatingHUDController

+ (instancetype)sharedController {
    static VSFloatingHUDController *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[VSFloatingHUDController alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [VSAutoLayerManager sharedManager].delegate = self;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNotificationLog:)
                                                     name:VSAutoLayerLogNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleStatusChangeNotification:)
                                                     name:VSAutoLayerStatusChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)attachToWindow:(UIWindow *)window {
    if (self.hudWindow) return;

    // Tạo Overlay UIWindow riêng biệt đè lên trên mọi view của Video Star
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = window.windowScene;
        if (scene) {
            self.hudWindow = [[UIWindow alloc] initWithWindowScene:scene];
        } else {
            self.hudWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
    } else {
        self.hudWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }

    self.hudWindow.windowLevel = UIWindowLevelAlert + 100.0;
    self.hudWindow.backgroundColor = [UIColor clearColor];
    self.hudWindow.hidden = NO;

    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.userInteractionEnabled = YES;
    self.hudWindow.rootViewController = rootVC;

    // Khởi tạo Floating Bubble
    self.bubbleView = [[VSFloatingBubbleView alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 66, 140, 54, 54)];
    __weak typeof(self) weakSelf = self;
    self.bubbleView.onTapHandler = ^{
        [weakSelf togglePanel];
    };
    [rootVC.view addSubview:self.bubbleView];

    // Khởi tạo Main Panel
    CGFloat panelW = MIN(360.0, [UIScreen mainScreen].bounds.size.width - 24.0);
    CGFloat panelH = MIN(520.0, [UIScreen mainScreen].bounds.size.height - 100.0);
    CGRect panelFrame = CGRectMake(([UIScreen mainScreen].bounds.size.width - panelW) / 2.0,
                                   ([UIScreen mainScreen].bounds.size.height - panelH) / 2.0,
                                   panelW, panelH);

    self.mainPanel = [[VSMainHUDPanel alloc] initWithFrame:panelFrame];
    self.mainPanel.alpha = 0.0;
    self.mainPanel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    self.mainPanel.onCloseHandler = ^{
        [weakSelf hidePanel];
    };
    [rootVC.view addSubview:self.mainPanel];

    self.isPanelVisible = NO;
}

- (void)showPanel {
    if (self.isPanelVisible) return;
    self.isPanelVisible = YES;
    [self.mainPanel refreshStatus];

    [UIView animateWithDuration:0.35
                          delay:0.0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.mainPanel.alpha = 1.0;
        self.mainPanel.transform = CGAffineTransformIdentity;
        self.bubbleView.alpha = 0.3;
    } completion:nil];
}

- (void)hidePanel {
    if (!self.isPanelVisible) return;
    self.isPanelVisible = NO;

    [UIView animateWithDuration:0.25 animations:^{
        self.mainPanel.alpha = 0.0;
        self.mainPanel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.bubbleView.alpha = 1.0;
    }];
}

- (void)togglePanel {
    if (self.isPanelVisible) {
        [self hidePanel];
    } else {
        [self showPanel];
    }
}

#pragma mark - Media Picker (PHPicker & Document Picker)

- (void)presentMediaPicker {
    UIViewController *presenter = self.hudWindow.rootViewController;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CHỌN NGUỒN MEDIA"
                                                                   message:@"Chọn thư viện ảnh/video hoặc tệp trong máy"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"📸 Thư Viện Ảnh/Video (Chọn Nhiều)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        if (@available(iOS 14.0, *)) {
            PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
            config.selectionLimit = 0; // 0 = Không giới hạn số lượng
            config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
                [PHPickerFilter imagesFilter],
                [PHPickerFilter videosFilter]
            ]];

            PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
            picker.delegate = self;
            [presenter presentViewController:picker animated:YES completion:nil];
        } else {
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            picker.mediaTypes = @[@"public.image", @"public.movie"];
            picker.delegate = (id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)self;
            [presenter presentViewController:picker animated:YES completion:nil];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"📁 Tệp Tin / Thư Mục Files"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        UIDocumentPickerViewController *docPicker = nil;
        if (@available(iOS 14.0, *)) {
            NSArray *contentTypes = @[UTTypeImage, UTTypeMovie];
            docPicker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes];
        } else {
            docPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image", @"public.movie"]
                                                                               inMode:UIDocumentPickerModeImport];
        }
        docPicker.allowsMultipleSelection = YES;
        docPicker.delegate = self;
        [presenter presentViewController:docPicker animated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ Bỏ" style:UIAlertActionStyleCancel handler:nil]];

    [presenter presentViewController:alert animated:YES completion:nil];
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) return;

    [[VSAutoLayerManager sharedManager] logMessage:[NSString stringWithFormat:@"Đang chuẩn bị nạp %lu file từ Thư viện...", (unsigned long)results.count] type:VSLogTypeInfo];

    for (PHPickerResult *result in results) {
        NSItemProvider *provider = result.itemProvider;

        // Ưu tiên tải Video
        if ([provider hasItemConformingToTypeIdentifier:@"public.movie"]) {
            [provider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (url) {
                    // Sao chép tạm ra thư mục Temp để tránh file bị giải phóng
                    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:url.lastPathComponent];
                    NSURL *destURL = [NSURL fileURLWithPath:tempPath];
                    [[NSFileManager defaultCenter] removeItemAtURL:destURL error:nil];
                    [[NSFileManager defaultCenter] copyItemAtURL:url toURL:destURL error:nil];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[VSAutoLayerManager sharedManager] enqueueMediaURL:destURL];
                        [self.mainPanel refreshStatus];
                    });
                }
            }];
        }
        // Tiếp theo kiểm tra Ảnh
        else if ([provider canLoadObjectOfClass:[UIImage class]]) {
            [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
                if ([object isKindOfClass:[UIImage class]]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[VSAutoLayerManager sharedManager] enqueueImage:(UIImage *)object];
                        [self.mainPanel refreshStatus];
                    });
                }
            }];
        }
    }
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        [url startAccessingSecurityScopedResource];
        [[VSAutoLayerManager sharedManager] enqueueMediaURL:url];
    }
    [self.mainPanel refreshStatus];
}

#pragma mark - AutoLayerManager & Notification Observers

- (void)handleNotificationLog:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    NSString *msg = info[@"message"];
    VSLogType type = [info[@"type"] integerValue];
    [self.mainPanel appendLogEntry:msg type:type];
}

- (void)handleStatusChangeNotification:(NSNotification *)note {
    [self.mainPanel refreshStatus];
}

- (void)autoLayerDidLogMessage:(NSString *)message type:(VSLogType)type {
    // Handled via notification
}

- (void)autoLayerStateChanged:(BOOL)isRunning {
    [self.mainPanel refreshStatus];
}

@end
