#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define kTitle    @"VideoStar Tool"
#define kAuthor   @"by mhoang"
#define kFooter   @"VIDEOSTAR  ·  MHOANG"
#define kVersion  @"V1.0"
#define kDefaults @"mhoang.vstool"

@class VSTPanel;
@class VSTFloatButton;
@class VSTWindow;

static VSTWindow      *gWindow = nil;
static VSTPanel       *gPanel  = nil;
static VSTFloatButton *gFloat  = nil;
static BOOL            gPanelVisible = NO;

static UIColor *kCyan(void)    { return [UIColor colorWithRed:0.20 green:0.85 blue:1.00 alpha:1.0]; }
static UIColor *kPanelBg(void) { return [UIColor colorWithRed:0.04 green:0.07 blue:0.10 alpha:1.0]; }

#pragma mark - 1. Custom Window (Fix Lỗi Không Ấn Được App)

@interface VSTWindow : UIWindow
@end

@implementation VSTWindow

// Không cho phép cướp quyền Key Window của Video Star
- (BOOL)canBecomeKeyWindow {
    return NO;
}

// Cho phép cảm ứng xuyên thấu xuống Video Star
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // 1. Nếu ngón tay chạm vào Nút tròn nổi -> Nhận cảm ứng
    if (gFloat && !gFloat.hidden && gFloat.alpha > 0.01) {
        CGPoint pFloat = [self convertPoint:point toView:gFloat];
        if ([gFloat pointInside:pFloat withEvent:event]) {
            return YES;
        }
    }

    // 2. Nếu bảng menu đang mở và ngón tay chạm vào Menu -> Nhận cảm ứng
    if (gPanel && !gPanel.hidden && gPanel.alpha > 0.01) {
        CGPoint pPanel = [self convertPoint:point toView:gPanel];
        if ([gPanel pointInside:pPanel withEvent:event]) {
            return YES;
        }
    }

    // 3. Ngoài 2 vùng trên: BỎ QUA HOÀN TOÀN -> Chuyển cảm ứng xuống Video Star bên dưới
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) {
        return nil;
    }
    return hit;
}

@end

#pragma mark - 2. Toggle Cell

@interface VSTToggleCell : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, copy)   NSString *key;
- (instancetype)initWithTitle:(NSString *)title key:(NSString *)key;
@end

@implementation VSTToggleCell

- (instancetype)initWithTitle:(NSString *)title key:(NSString *)key {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _key = [key copy];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = title;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];

    self.toggle = [[UISwitch alloc] init];
    self.toggle.onTintColor = kCyan();
    self.toggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@.%@", kDefaults, key]];
    [self.toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.toggle];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.toggle.leadingAnchor constant:-12],
        [self.toggle.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.toggle.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.heightAnchor constraintEqualToConstant:64]
    ]];

    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:sep];
    [NSLayoutConstraint activateConstraints:@[
        [sep.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [sep.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
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

@end

#pragma mark - 3. Panel Giao Diện Chính

@interface VSTPanel : UIView
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UIView *tabBar;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UIButton *btnHome;
@property (nonatomic, strong) UIButton *btnFunc;
@property (nonatomic, strong) UIButton *btnDev;
- (void)switchToTab:(NSInteger)idx;
@end

@implementation VSTPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = kPanelBg();
    self.layer.cornerRadius = 18;
    self.layer.borderWidth = 1.5;
    self.layer.borderColor = kCyan().CGColor;
    self.layer.masksToBounds = YES;
    [self buildHeader];
    [self buildTabBar];
    [self buildContent];
    [self switchToTab:0];
    return self;
}

- (void)buildHeader {
    self.header = [[UIView alloc] init];
    self.header.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.header];

    UIImageView *star = [[UIImageView alloc] init];
    star.image = [UIImage systemImageNamed:@"star.fill"];
    star.tintColor = kCyan();
    star.contentMode = UIViewContentModeScaleAspectFit;
    star.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:star];

    UILabel *title = [[UILabel alloc] init];
    title.text = kTitle;
    title.textColor = kCyan();
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:title];

    UILabel *author = [[UILabel alloc] init];
    author.text = kAuthor;
    author.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    author.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    author.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:author];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    close.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10];
    close.layer.cornerRadius = 16;
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];

    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:sep];

    [NSLayoutConstraint activateConstraints:@[
        [self.header.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.header.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.header.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.header.heightAnchor constraintEqualToConstant:72],
        [star.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:18],
        [star.centerYAnchor constraintEqualToAnchor:self.header.centerYAnchor],
        [star.widthAnchor constraintEqualToConstant:24],
        [star.heightAnchor constraintEqualToConstant:24],
        [title.leadingAnchor constraintEqualToAnchor:star.trailingAnchor constant:10],
        [title.topAnchor constraintEqualToAnchor:self.header.topAnchor constant:16],
        [author.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [author.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [close.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-16],
        [close.centerYAnchor constraintEqualToAnchor:self.header.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:32],
        [close.heightAnchor constraintEqualToConstant:32],
        [sep.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:16],
        [sep.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-16],
        [sep.bottomAnchor constraintEqualToAnchor:self.header.bottomAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5]
    ]];
}

- (void)buildTabBar {
    self.tabBar = [[UIView alloc] init];
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.tabBar];

    self.btnHome = [self makeTabButton:@"Home" icon:@"house.fill" tag:0];
    self.btnFunc = [self makeTabButton:@"Function" icon:@"gearshape" tag:1];
    self.btnDev  = [self makeTabButton:@"Dev" icon:@"chevron.left.forwardslash.chevron.right" tag:2];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.btnHome, self.btnFunc, self.btnDev]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tabBar addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.tabBar.topAnchor constraintEqualToAnchor:self.header.bottomAnchor],
        [self.tabBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.tabBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.tabBar.heightAnchor constraintEqualToConstant:64],
        [stack.leadingAnchor constraintEqualToAnchor:self.tabBar.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:self.tabBar.trailingAnchor constant:-14],
        [stack.topAnchor constraintEqualToAnchor:self.tabBar.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor constant:-10]
    ]];
}

- (UIButton *)makeTabButton:(NSString *)title icon:(NSString *)icon tag:(NSInteger)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.tag = tag;
    b.layer.cornerRadius = 10;
    b.layer.borderWidth = 1;
    b.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25].CGColor;
    [b setTitle:title forState:UIControlStateNormal];
    [b setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.tintColor = [UIColor whiteColor];
    b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    b.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
    [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)buildContent {
    self.content = [[UIView alloc] init];
    self.content.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.content];

    UIView *footer = [[UIView alloc] init];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:footer];

    UIView *lineL = [[UIView alloc] init];
    lineL.backgroundColor = kCyan();
    lineL.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:lineL];

    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.text = kFooter;
    footerLabel.textColor = kCyan();
    footerLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:footerLabel];

    UIView *lineR = [[UIView alloc] init];
    lineR.backgroundColor = kCyan();
    lineR.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:lineR];

    [NSLayoutConstraint activateConstraints:@[
        [self.content.topAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor],
        [self.content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.content.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [footer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [footer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
        [footer.heightAnchor constraintEqualToConstant:20],
        [footerLabel.centerXAnchor constraintEqualToAnchor:footer.centerXAnchor],
        [footerLabel.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [lineL.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor],
        [lineL.trailingAnchor constraintEqualToAnchor:footerLabel.leadingAnchor constant:-10],
        [lineL.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [lineL.heightAnchor constraintEqualToConstant:1],
        [lineR.leadingAnchor constraintEqualToAnchor:footerLabel.trailingAnchor constant:10],
        [lineR.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor],
        [lineR.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [lineR.heightAnchor constraintEqualToConstant:1]
    ]];
}

- (void)tabTapped:(UIButton *)sender {
    [self switchToTab:sender.tag];
}

- (void)switchToTab:(NSInteger)idx {
    for (UIButton *b in @[self.btnHome, self.btnFunc, self.btnDev]) {
        BOOL active = (b.tag == idx);
        b.layer.borderColor = (active ? kCyan() : [[UIColor whiteColor] colorWithAlphaComponent:0.25]).CGColor;
        b.backgroundColor = active ? [kCyan() colorWithAlphaComponent:0.12] : [UIColor clearColor];
        [b setTitleColor:(active ? kCyan() : [UIColor whiteColor]) forState:UIControlStateNormal];
        b.tintColor = active ? kCyan() : [UIColor whiteColor];
    }
    for (UIView *v in self.content.subviews) [v removeFromSuperview];
    if (idx == 0) [self buildHomeTab];
    else if (idx == 1) [self buildFunctionTab];
    else [self buildDevTab];
}

- (void)buildHomeTab {
    UILabel *greet = [[UILabel alloc] init];
    greet.text = @"Xin chào!";
    greet.textColor = [UIColor whiteColor];
    greet.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    greet.translatesAutoresizingMaskIntoConstraints = NO;
    [self.content addSubview:greet];

    UILabel *desc = [[UILabel alloc] init];
    desc.text = @"Đây là VideoStar Tool, 1 công cụ giúp bạn sử dụng VideoStar thuận tiện, nhanh chóng và dễ dàng hơn.";
    desc.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75];
    desc.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    desc.numberOfLines = 0;
    desc.translatesAutoresizingMaskIntoConstraints = NO;
    [self.content addSubview:desc];

    UILabel *ver = [[UILabel alloc] init];
    ver.text = [NSString stringWithFormat:@"Phiên bản đang sử dụng: %@", kVersion];
    ver.textColor = kCyan();
    ver.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    ver.translatesAutoresizingMaskIntoConstraints = NO;
    [self.content addSubview:ver];

    [NSLayoutConstraint activateConstraints:@[
        [greet.topAnchor constraintEqualToAnchor:self.content.topAnchor constant:24],
        [greet.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:22],
        [desc.topAnchor constraintEqualToAnchor:greet.bottomAnchor constant:14],
        [desc.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:22],
        [desc.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-22],
        [ver.bottomAnchor constraintEqualToAnchor:self.content.bottomAnchor constant:-14],
        [ver.centerXAnchor constraintEqualToAnchor:self.content.centerXAnchor]
    ]];
}

- (void)buildFunctionTab {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [self.content addSubview:scroll];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.content.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.content.bottomAnchor]
    ]];

    NSArray *items = @[
        @[@"Hiển thị code gần nhất từng nhập", @"show_last_code"],
        @[@"Auto chia beat", @"auto_split_beat"],
        @[@"Auto nhập code và ảnh vào các phần cảnh", @"auto_fill_scene"],
        @[@"Auto nhập ảnh vào các lớp hình ảnh", @"auto_fill_layer"]
    ];

    UIView *prev = nil;
    for (NSArray *item in items) {
        VSTToggleCell *cell = [[VSTToggleCell alloc] initWithTitle:item[0] key:item[1]];
        cell.translatesAutoresizingMaskIntoConstraints = NO;
        [scroll addSubview:cell];
        [NSLayoutConstraint activateConstraints:@[
            [cell.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
            [cell.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
            [cell.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]
        ]];
        if (prev) [cell.topAnchor constraintEqualToAnchor:prev.bottomAnchor].active = YES;
        else [cell.topAnchor constraintEqualToAnchor:scroll.topAnchor].active = YES;
        prev = cell;
    }
    if (prev) [prev.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor].active = YES;
}

- (void)buildDevTab {
    UILabel *name = [[UILabel alloc] init];
    name.text = @"Người tạo ra sản phẩm này là mhoang";
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    name.numberOfLines = 0;
    name.translatesAutoresizingMaskIntoConstraints = NO;
    [self.content addSubview:name];

    UILabel *tele = [[UILabel alloc] init];
    tele.text = @"Telegram: @mhoang";
    tele.textColor = kCyan();
    tele.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    tele.translatesAutoresizingMaskIntoConstraints = NO;
    [self.content addSubview:tele];

    [NSLayoutConstraint activateConstraints:@[
        [name.topAnchor constraintEqualToAnchor:self.content.topAnchor constant:28],
        [name.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor constant:22],
        [name.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor constant:-22],
        [tele.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:12],
        [tele.leadingAnchor constraintEqualToAnchor:name.leadingAnchor]
    ]];
}

- (void)closeTapped {
    gPanelVisible = NO;
    self.hidden = YES;
}

@end

#pragma mark - 4. Nút Bấm Trôi Nổi (Float Button)

@interface VSTFloatButton : UIView
@property (nonatomic, strong) UILabel *sub;
@end

@implementation VSTFloatButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor colorWithRed:0.06 green:0.10 blue:0.14 alpha:1.0];
    self.layer.cornerRadius = frame.size.width / 2.0;
    self.layer.borderWidth = 2.0;
    self.layer.borderColor = kCyan().CGColor;
    self.layer.shadowColor = kCyan().CGColor;
    self.layer.shadowOpacity = 0.6;
    self.layer.shadowRadius = 8;
    self.layer.shadowOffset = CGSizeZero;

    UIImageView *star = [[UIImageView alloc] init];
    star.image = [UIImage systemImageNamed:@"star.fill"];
    star.tintColor = kCyan();
    star.contentMode = UIViewContentModeScaleAspectFit;
    star.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:star];

    UILabel *sub = [[UILabel alloc] init];
    sub.text = @"VS";
    sub.textColor = kCyan();
    sub.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:sub];
    self.sub = sub;

    [NSLayoutConstraint activateConstraints:@[
        [star.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [star.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-4],
        [star.widthAnchor constraintEqualToConstant:22],
        [star.heightAnchor constraintEqualToConstant:22],
        [sub.topAnchor constraintEqualToAnchor:star.bottomAnchor constant:0],
        [sub.centerXAnchor constraintEqualToAnchor:self.centerXAnchor]
    ]];
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    UIView *sup = self.superview;
    CGPoint t = [g translationInView:sup];
    CGPoint c = self.center;
    c.x += t.x;
    c.y += t.y;
    CGFloat half = self.bounds.size.width / 2.0;
    c.x = MAX(half, MIN(sup.bounds.size.width - half, c.x));
    c.y = MAX(half, MIN(sup.bounds.size.height - half, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:sup];
}

- (void)handleTap:(UITapGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateEnded) return;
    if (!gPanel) return;
    gPanelVisible = !gPanelVisible;
    gPanel.hidden = !gPanelVisible;
    [gPanel.superview bringSubviewToFront:gPanel];
    [gPanel.superview bringSubviewToFront:self];
}

@end

#pragma mark - 5. Khởi Tạo & Hook

static void VSTSetup(void) {
    if (gWindow) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    }
    if (!scene) return;

    CGRect screen = scene.coordinateSpace.bounds;
    gWindow = [[VSTWindow alloc] initWithWindowScene:scene];
    gWindow.frame = screen;
    gWindow.windowLevel = UIWindowLevelAlert + 100;
    gWindow.backgroundColor = [UIColor clearColor];
    
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    root.view.userInteractionEnabled = YES;
    gWindow.rootViewController = root;
    gWindow.hidden = NO;

    CGFloat panelW = MIN(360, screen.size.width - 40);
    CGFloat panelH = 480;
    CGRect panelFrame = CGRectMake((screen.size.width - panelW) / 2.0, (screen.size.height - panelH) / 2.0, panelW, panelH);
    gPanel = [[VSTPanel alloc] initWithFrame:panelFrame];
    gPanel.hidden = YES;
    gPanelVisible = NO;
    [gWindow.rootViewController.view addSubview:gPanel];

    CGFloat fSize = 60;
    CGRect fFrame = CGRectMake(screen.size.width - fSize - 16, screen.size.height * 0.55, fSize, fSize);
    gFloat = [[VSTFloatButton alloc] initWithFrame:fFrame];
    [gWindow.rootViewController.view addSubview:gFloat];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:gFloat action:@selector(handlePan:)];
    [gFloat addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:gFloat action:@selector(handleTap:)];
    [gFloat addGestureRecognizer:tap];
}

static void VSTSwizzle(Class cls, SEL orig, SEL swizzled) {
    Method m1 = class_getInstanceMethod(cls, orig);
    Method m2 = class_getInstanceMethod(cls, swizzled);
    if (m1 && m2) method_exchangeImplementations(m1, m2);
}

@interface UIWindow (VSTHook)
@end
@implementation UIWindow (VSTHook)
- (void)vst_makeKeyAndVisible {
    [self vst_makeKeyAndVisible];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            VSTSetup();
        });
    });
}
@end

__attribute__((constructor))
static void VSTInit(void) {
    VSTSwizzle([UIWindow class], @selector(makeKeyAndVisible), @selector(vst_makeKeyAndVisible));
}
