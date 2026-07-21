#import "EDRBrightnessManager.h"
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString *const VBBEDRBoostKey = @"edrSelectedBoost";

@interface VBBEDRView : MTKView <MTKViewDelegate>
@property(nonatomic) id<MTLCommandQueue> commandQueue;
@property(nonatomic) double multiplier;
@property(nonatomic) NSUInteger frameCount;
- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device multiplier:(double)multiplier;
@end

@implementation VBBEDRView

- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device multiplier:(double)multiplier {
    self = [super initWithFrame:frame device:device];
    if (self) {
        _commandQueue = [device newCommandQueue];
        _multiplier = multiplier;
        self.delegate = self;
        self.framebufferOnly = YES;
        self.colorPixelFormat = MTLPixelFormatRGBA16Float;
        self.preferredFramesPerSecond = 5;
        self.paused = NO;
        self.enableSetNeedsDisplay = NO;

        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearDisplayP3);
        self.colorspace = colorSpace;
        CGColorSpaceRelease(colorSpace);

        CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
        metalLayer.wantsExtendedDynamicRangeContent = YES;
        metalLayer.pixelFormat = MTLPixelFormatRGBA16Float;
        metalLayer.opaque = NO;
        [self updateClearColor];
    }
    return self;
}

- (void)setMultiplier:(double)multiplier {
    _multiplier = multiplier;
    [self updateClearColor];
    [self draw];
}

- (void)updateClearColor {
    self.clearColor = MTLClearColorMake(self.multiplier, self.multiplier, self.multiplier, 1.0);
}

- (void)drawInMTKView:(MTKView *)view {
    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    if (descriptor == nil || drawable == nil || commandBuffer == nil) return;
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    self.frameCount++;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    (void)view; (void)size;
}

@end

@interface EDRBrightnessManager ()
@property(nonatomic, readwrite) double selectedBoost;
@property(nonatomic, readwrite, getter=isEnabled) BOOL enabled;
@property(nonatomic, readwrite) NSUInteger displayCount;
@property(nonatomic, readwrite) double currentEDRHeadroom;
@property(nonatomic, readwrite) NSUInteger renderedFrameCount;
@property(nonatomic, copy, readwrite, nullable) NSString *statusMessage;
@property(nonatomic) id<MTLDevice> metalDevice;
@property(nonatomic) NSMutableDictionary<NSNumber *, NSWindow *> *overlayWindows;
@property(nonatomic) NSMutableDictionary<NSNumber *, VBBEDRView *> *overlayViews;
@property(nonatomic, nullable) NSTimer *watchdogTimer;
@property(nonatomic) NSUInteger watchdogTicks;
@end

@implementation EDRBrightnessManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _metalDevice = MTLCreateSystemDefaultDevice();
        _overlayWindows = [NSMutableDictionary dictionary];
        _overlayViews = [NSMutableDictionary dictionary];
        double saved = [[NSUserDefaults standardUserDefaults] doubleForKey:VBBEDRBoostKey];
        _selectedBoost = [self clampedBoost:(saved >= 1.0 ? saved : 1.5)];
        [self refreshDisplays];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenParametersChanged:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.watchdogTimer invalidate];
}

- (double)clampedBoost:(double)boost {
    return fmin(fmax(boost, 1.0), 2.0);
}

- (NSArray<NSScreen *> *)supportedScreens {
    NSMutableArray<NSScreen *> *screens = [NSMutableArray array];
    for (NSScreen *screen in NSScreen.screens) {
        if (screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.05) {
            [screens addObject:screen];
        }
    }
    return screens;
}

- (NSNumber *)displayNumberForScreen:(NSScreen *)screen {
    return screen.deviceDescription[@"NSScreenNumber"];
}

- (void)notifyChange {
    if (self.onChange) self.onChange();
}

- (void)refreshDisplays {
    NSArray<NSScreen *> *screens = [self supportedScreens];
    self.displayCount = screens.count;
    self.currentEDRHeadroom = 1.0;
    for (NSScreen *screen in screens) {
        self.currentEDRHeadroom = fmax(self.currentEDRHeadroom,
                                      screen.maximumExtendedDynamicRangeColorComponentValue);
    }

    if (self.metalDevice == nil) {
        self.statusMessage = @"当前 Mac 不支持 Metal";
        self.enabled = NO;
    } else if (screens.count == 0) {
        self.statusMessage = @"未检测到 XDR/EDR 显示器";
        self.enabled = NO;
    } else if (!self.isEnabled) {
        self.statusMessage = nil;
    }
    [self notifyChange];
}

- (void)selectBoost:(double)boost applyImmediately:(BOOL)applyImmediately {
    self.selectedBoost = [self clampedBoost:boost];
    [[NSUserDefaults standardUserDefaults] setDouble:self.selectedBoost forKey:VBBEDRBoostKey];
    if (self.isEnabled || applyImmediately) {
        [self applySelectedBoost];
    } else {
        [self notifyChange];
    }
}

- (void)applySelectedBoost {
    NSArray<NSScreen *> *screens = [self supportedScreens];
    if (screens.count == 0 || self.metalDevice == nil) {
        [self refreshDisplays];
        return;
    }

    NSMutableSet<NSNumber *> *activeDisplayNumbers = [NSMutableSet set];
    for (NSScreen *screen in screens) {
        NSNumber *displayNumber = [self displayNumberForScreen:screen];
        if (displayNumber == nil) continue;
        [activeDisplayNumbers addObject:displayNumber];

        VBBEDRView *view = self.overlayViews[displayNumber];
        NSWindow *window = self.overlayWindows[displayNumber];
        if (view == nil || window == nil) {
            window = [self createOverlayWindowForScreen:screen];
            view = [[VBBEDRView alloc] initWithFrame:window.contentView.bounds
                                             device:self.metalDevice
                                         multiplier:self.selectedBoost];
            view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            [window.contentView addSubview:view];
            self.overlayWindows[displayNumber] = window;
            self.overlayViews[displayNumber] = view;
        } else {
            [window setFrame:screen.frame display:YES];
            view.multiplier = self.selectedBoost;
        }
        [window orderFrontRegardless];
        [view draw];
    }

    for (NSNumber *displayNumber in self.overlayWindows.allKeys) {
        if (![activeDisplayNumbers containsObject:displayNumber]) {
            [self.overlayWindows[displayNumber] orderOut:nil];
            [self.overlayWindows removeObjectForKey:displayNumber];
            [self.overlayViews removeObjectForKey:displayNumber];
        }
    }

    self.enabled = self.overlayWindows.count > 0;
    self.displayCount = screens.count;
    self.statusMessage = self.isEnabled ? @"正在激活 XDR 亮度…" : @"无法创建 XDR 覆盖层";
    [self startWatchdog];
    [self notifyChange];
    [self performSelector:@selector(refreshEDRStatus) withObject:nil afterDelay:0.5];
}

- (NSWindow *)createOverlayWindowForScreen:(NSScreen *)screen {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:screen.frame
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO
                                                      screen:screen];
    window.level = NSScreenSaverWindowLevel;
    window.backgroundColor = NSColor.clearColor;
    window.opaque = NO;
    window.hasShadow = NO;
    window.ignoresMouseEvents = YES;
    window.hidesOnDeactivate = NO;
    window.releasedWhenClosed = NO;
    window.sharingType = NSWindowSharingNone;
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                NSWindowCollectionBehaviorFullScreenAuxiliary |
                                NSWindowCollectionBehaviorStationary |
                                NSWindowCollectionBehaviorIgnoresCycle;
    window.contentView.wantsLayer = YES;
    window.contentView.layer.compositingFilter = @"multiplyBlendMode";
    [window setFrame:screen.frame display:YES];
    return window;
}

- (void)refreshEDRStatus {
    if (!self.isEnabled) return;
    self.currentEDRHeadroom = 1.0;
    for (NSScreen *screen in [self supportedScreens]) {
        self.currentEDRHeadroom = fmax(self.currentEDRHeadroom,
                                      screen.maximumExtendedDynamicRangeColorComponentValue);
    }
    NSUInteger frameCount = 0;
    for (VBBEDRView *view in self.overlayViews.allValues) frameCount += view.frameCount;
    self.renderedFrameCount = frameCount;
    self.statusMessage = self.currentEDRHeadroom > 1.05
        ? [NSString stringWithFormat:@"XDR 已激活 · 当前增强 +%.0f%%", (self.selectedBoost - 1.0) * 100.0]
        : @"正在等待 macOS 开放 XDR 亮度…";
    [self notifyChange];
}

- (void)startWatchdog {
    if (self.watchdogTimer != nil) return;
    self.watchdogTicks = 0;
    self.watchdogTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                          target:self
                                                        selector:@selector(watchdogTick:)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)watchdogTick:(NSTimer *)timer {
    (void)timer;
    if (!self.isEnabled) return;
    if (self.overlayWindows.count == 0) [self applySelectedBoost];
    for (VBBEDRView *view in self.overlayViews.allValues) [view draw];
    self.watchdogTicks++;
    if (self.watchdogTicks % 10 == 0) [self refreshEDRStatus];
}

- (void)toggle {
    self.isEnabled ? [self resetBrightness] : [self applySelectedBoost];
}

- (void)increaseBoost {
    double next = fmin(round(self.selectedBoost * 10.0) / 10.0 + 0.1, 2.0);
    [self selectBoost:next applyImmediately:YES];
}

- (void)reapplyAfterWake {
    if (self.isEnabled) {
        [self rebuildOverlays];
    } else {
        [self refreshDisplays];
    }
}

- (void)rebuildOverlays {
    BOOL shouldEnable = self.isEnabled;
    [self closeOverlays];
    self.enabled = shouldEnable;
    if (shouldEnable) [self applySelectedBoost];
}

- (void)resetBrightness {
    [self closeOverlays];
    self.enabled = NO;
    self.currentEDRHeadroom = 1.0;
    self.statusMessage = nil;
    [self.watchdogTimer invalidate];
    self.watchdogTimer = nil;
    [self notifyChange];
}

- (void)closeOverlays {
    for (NSWindow *window in self.overlayWindows.allValues) {
        [window orderOut:nil];
        [window close];
    }
    [self.overlayWindows removeAllObjects];
    [self.overlayViews removeAllObjects];
}

- (void)screenParametersChanged:(NSNotification *)notification {
    (void)notification;
    if (self.isEnabled) {
        [self refreshEDRStatus];
    } else {
        [self refreshDisplays];
    }
}

@end
