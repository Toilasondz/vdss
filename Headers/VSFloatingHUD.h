//
//  VSFloatingHUD.h
//  VideoStarAutoLayerTweak
//
//  Dark Mode Glassmorphism Floating Window HUD for Video Star.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import "VSAutoLayerManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface VSFloatingBubbleView : UIView

@property (nonatomic, copy, nullable) void (^onTapHandler)(void);

- (void)resetPosition;

@end

@interface VSMainHUDPanel : UIView

@property (nonatomic, copy, nullable) void (^onCloseHandler)(void);

- (void)refreshStatus;
- (void)appendLogEntry:(NSString *)message type:(VSLogType)type;
- (void)clearLogView;

@end

@interface VSFloatingHUDController : NSObject <VSAutoLayerManagerDelegate, PHPickerViewControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong, readonly) UIWindow *hudWindow;
@property (nonatomic, strong, readonly) VSFloatingBubbleView *bubbleView;
@property (nonatomic, strong, readonly) VSMainHUDPanel *mainPanel;
@property (nonatomic, assign, readonly) BOOL isPanelVisible;

+ (instancetype)sharedController;

- (void)attachToWindow:(UIWindow *)window;
- (void)showPanel;
- (void)hidePanel;
- (void)togglePanel;

- (void)presentMediaPicker;

@end

NS_ASSUME_NONNULL_END
