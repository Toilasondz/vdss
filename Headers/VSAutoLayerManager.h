//
//  VSAutoLayerManager.h
//  VideoStarAutoLayerTweak
//
//  Core Automation Engine for Video Star Multi-Layer asset replacement.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "VideoStarHeaders.h"
#import "VSLayerFilter.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const VSAutoLayerLogNotification;
extern NSString *const VSAutoLayerStatusChangeNotification;

@protocol VSAutoLayerManagerDelegate <NSObject>
@optional
- (void)autoLayerDidLogMessage:(NSString *)message type:(VSLogType)type;
- (void)autoLayerProgressUpdated:(NSInteger)current total:(NSInteger)total;
- (void)autoLayerDidFinishWithSuccessCount:(NSInteger)success skippedCount:(NSInteger)skipped;
- (void)autoLayerStateChanged:(BOOL)isRunning;
@end

@interface VSAutoLayerManager : NSObject

@property (nonatomic, weak, nullable) id<VSAutoLayerManagerDelegate> delegate;
@property (nonatomic, weak, nullable) UIViewController *activeMultiLayerVC;
@property (nonatomic, strong) VSLayerFilter *filter;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) NSInteger totalProcessedCount;
@property (nonatomic, assign, readonly) NSInteger successCount;
@property (nonatomic, assign, readonly) NSInteger skippedCount;

// Hàng đợi Media (chứa NSURL của video/ảnh hoặc UIImage)
@property (nonatomic, strong, readonly) NSMutableArray *mediaQueue;

// Nhật ký Log hiển thị ra giao diện
@property (nonatomic, strong, readonly) NSMutableArray<NSDictionary *> *logEntries;

// Thời gian chờ giữa mỗi lần import (giúp engine Video Star render kịp thời, mặc định 0.35s)
@property (nonatomic, assign) NSTimeInterval stepInterval;

+ (instancetype)sharedManager;

// Thao tác với Media Queue
- (void)enqueueMediaURL:(NSURL *)url;
- (void)enqueueImage:(UIImage *)image;
- (void)enqueueMediaBatch:(NSArray *)mediaItems;
- (void)clearMediaQueue;

// Thao tác Automation
- (void)startAutoImport;
- (void)stopAutoImport;

// Logging
- (void)logMessage:(NSString *)message type:(VSLogType)type;
- (void)clearLogs;

// Trình dò tìm Multi-Layer Controller trong Runtime
- (nullable UIViewController *)findCurrentMultiLayerController;
- (nullable NSArray *)extractLayersFromController:(UIViewController *)controller;

@end

NS_ASSUME_NONNULL_END
