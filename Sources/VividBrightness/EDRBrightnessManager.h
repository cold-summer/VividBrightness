#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface EDRBrightnessManager : NSObject

@property(nonatomic, readonly) double selectedBoost;
@property(nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property(nonatomic, readonly) NSUInteger displayCount;
@property(nonatomic, readonly) double currentEDRHeadroom;
@property(nonatomic, readonly) NSUInteger renderedFrameCount;
@property(nonatomic, copy, readonly, nullable) NSString *statusMessage;
@property(nonatomic, copy, nullable) void (^onChange)(void);

- (void)refreshDisplays;
- (void)selectBoost:(double)boost applyImmediately:(BOOL)applyImmediately;
- (void)applySelectedBoost;
- (void)toggle;
- (void)increaseBoost;
- (void)reapplyAfterWake;
- (void)resetBrightness;

@end

NS_ASSUME_NONNULL_END
