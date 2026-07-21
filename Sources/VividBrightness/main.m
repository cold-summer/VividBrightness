#import <Cocoa/Cocoa.h>
#import <math.h>
#import "EDRBrightnessManager.h"

@interface VBBGaugeView : NSView
@property(nonatomic) double boost;
@property(nonatomic, getter=isEnabled) BOOL enabled;
@end

@implementation VBBGaugeView
- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSPoint center = NSMakePoint(NSMidX(self.bounds), 56);
    CGFloat radius = 43;
    NSBezierPath *track = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - radius, center.y - radius,
                                                                           radius * 2, radius * 2)];
    track.lineWidth = 8;
    [[NSColor separatorColor] setStroke];
    [track stroke];

    double progress = fmin(fmax(self.boost - 1.0, 0.0), 1.0);
    NSBezierPath *arc = [NSBezierPath bezierPath];
    [arc appendBezierPathWithArcWithCenter:center
                                    radius:radius
                                startAngle:90
                                  endAngle:90 - progress * 360
                                 clockwise:YES];
    arc.lineWidth = 8;
    arc.lineCapStyle = NSLineCapStyleRound;
    [(self.isEnabled ? NSColor.systemOrangeColor : [NSColor secondaryLabelColor]) setStroke];
    [arc stroke];

    NSString *value = [NSString stringWithFormat:@"+%.0f%%", (self.boost - 1.0) * 100.0];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:21 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: self.isEnabled ? NSColor.labelColor : NSColor.secondaryLabelColor
    };
    NSSize size = [value sizeWithAttributes:attributes];
    [value drawAtPoint:NSMakePoint(center.x - size.width / 2, center.y - size.height / 2)
        withAttributes:attributes];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic) EDRBrightnessManager *manager;
@property(nonatomic) NSStatusItem *statusItem;
@property(nonatomic) NSPopover *popover;
@property(nonatomic, nullable) NSWindow *testWindow;
@property(nonatomic) NSTextField *stateLabel;
@property(nonatomic) NSView *stateDot;
@property(nonatomic) NSImageView *headerIcon;
@property(nonatomic) NSButton *powerButton;
@property(nonatomic) VBBGaugeView *gauge;
@property(nonatomic) NSSlider *slider;
@property(nonatomic) NSSegmentedControl *presets;
@property(nonatomic) NSTextField *statusLabel;
@property(nonatomic) NSTextField *displayLabel;
@property(nonatomic, nullable) id localMonitor;
@property(nonatomic, nullable) id globalMonitor;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.manager = [[EDRBrightnessManager alloc] init];
    [self buildStatusItem];
    [self buildPopover];
    [self installEventMonitors];

    __weak typeof(self) weakSelf = self;
    self.manager.onChange = ^{
        [weakSelf updateUI];
    };
    [self updateUI];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                            selector:@selector(handleWake:)
                                                                name:NSWorkspaceDidWakeNotification
                                                              object:nil];

    if (self.testWindow != nil) {
        [self.testWindow center];
        [self.testWindow makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.manager resetBrightness];
    if (self.localMonitor) [NSEvent removeMonitor:self.localMonitor];
    if (self.globalMonitor) [NSEvent removeMonitor:self.globalMonitor];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)buildStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(togglePopover:);
    [self.statusItem.button sendActionOn:NSEventMaskLeftMouseUp];
}

- (void)buildPopover {
    NSViewController *controller = [[NSViewController alloc] init];
    NSVisualEffectView *root = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 360, 430)];
    root.material = NSVisualEffectMaterialPopover;
    root.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    root.state = NSVisualEffectStateActive;
    controller.view = root;

    NSImage *sunImage = [NSImage imageWithSystemSymbolName:@"sun.max.fill" accessibilityDescription:@"亮度"];
    self.headerIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 374, 32, 32)];
    self.headerIcon.image = sunImage;
    self.headerIcon.contentTintColor = NSColor.systemOrangeColor;
    self.headerIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightSemibold];
    [root addSubview:self.headerIcon];

    NSTextField *title = [self label:@"VividBrightness" frame:NSMakeRect(64, 389, 190, 20)
                                 font:[NSFont systemFontOfSize:15 weight:NSFontWeightSemibold]
                                color:NSColor.labelColor];
    [root addSubview:title];

    self.stateDot = [[NSView alloc] initWithFrame:NSMakeRect(64, 376, 7, 7)];
    self.stateDot.wantsLayer = YES;
    self.stateDot.layer.cornerRadius = 3.5;
    [root addSubview:self.stateDot];

    self.stateLabel = [self label:@"增强已关闭" frame:NSMakeRect(77, 370, 150, 18)
                             font:[NSFont systemFontOfSize:11]
                            color:NSColor.secondaryLabelColor];
    [root addSubview:self.stateLabel];

    self.powerButton = [self iconButton:@"power" tooltip:@"开启或关闭亮度增强" frame:NSMakeRect(312, 378, 28, 28)
                                  action:@selector(togglePower:)];
    [root addSubview:self.powerButton];
    [root addSubview:[self separatorAtY:358]];

    self.gauge = [[VBBGaugeView alloc] initWithFrame:NSMakeRect(120, 226, 120, 112)];
    self.gauge.wantsLayer = YES;
    [root addSubview:self.gauge];

    self.slider = [NSSlider sliderWithValue:1.25 minValue:1.0 maxValue:2.0 target:self action:@selector(sliderChanged:)];
    self.slider.frame = NSMakeRect(24, 184, 312, 24);
    self.slider.continuous = YES;
    self.slider.numberOfTickMarks = 21;
    self.slider.allowsTickMarkValuesOnly = YES;
    self.slider.toolTip = @"亮度增强级别";
    [root addSubview:self.slider];
    [root addSubview:[self label:@"正常" frame:NSMakeRect(24, 162, 60, 16)
                              font:[NSFont systemFontOfSize:11] color:NSColor.secondaryLabelColor]];
    NSTextField *maximum = [self label:@"最高" frame:NSMakeRect(276, 162, 60, 16)
                                  font:[NSFont systemFontOfSize:11] color:NSColor.secondaryLabelColor];
    maximum.alignment = NSTextAlignmentRight;
    [root addSubview:maximum];

    self.presets = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(24, 118, 312, 28)];
    self.presets.segmentCount = 4;
    NSArray<NSString *> *labels = @[@"+25%", @"+50%", @"+75%", @"+100%"];
    for (NSInteger index = 0; index < 4; index++) {
        [self.presets setLabel:labels[index] forSegment:index];
        [self.presets setWidth:78 forSegment:index];
    }
    self.presets.segmentStyle = NSSegmentStyleAutomatic;
    self.presets.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.presets.target = self;
    self.presets.action = @selector(presetChanged:);
    [root addSubview:self.presets];

    self.statusLabel = [self label:@"" frame:NSMakeRect(24, 76, 312, 34)
                              font:[NSFont systemFontOfSize:11] color:NSColor.systemOrangeColor];
    self.statusLabel.maximumNumberOfLines = 2;
    self.statusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [root addSubview:self.statusLabel];

    [root addSubview:[self separatorAtY:48]];
    self.displayLabel = [self label:@"0 台显示器" frame:NSMakeRect(20, 15, 180, 18)
                               font:[NSFont systemFontOfSize:11] color:NSColor.secondaryLabelColor];
    [root addSubview:self.displayLabel];
    NSButton *quitButton = [self iconButton:@"xmark.circle" tooltip:@"退出 VividBrightness"
                                      frame:NSMakeRect(316, 10, 24, 24) action:@selector(quit:)];
    [root addSubview:quitButton];

    if ([[NSProcessInfo processInfo].arguments containsObject:@"--show"]) {
        self.testWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 360, 430)
                                                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
        self.testWindow.title = @"VividBrightness";
        self.testWindow.contentViewController = controller;
        self.testWindow.releasedWhenClosed = NO;
        return;
    }

    self.popover = [[NSPopover alloc] init];
    self.popover.contentSize = NSMakeSize(360, 430);
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.animates = YES;
    self.popover.contentViewController = controller;
}

- (NSTextField *)label:(NSString *)text frame:(NSRect)frame font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    label.font = font;
    label.textColor = color;
    return label;
}

- (NSButton *)iconButton:(NSString *)symbol tooltip:(NSString *)tooltip frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tooltip];
    button.imagePosition = NSImageOnly;
    button.bordered = NO;
    button.target = self;
    button.action = action;
    button.toolTip = tooltip;
    button.accessibilityLabel = tooltip;
    return button;
}

- (NSBox *)separatorAtY:(CGFloat)y {
    NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(20, y, 320, 1)];
    separator.boxType = NSBoxSeparator;
    return separator;
}

- (void)updateUI {
    BOOL enabled = self.manager.isEnabled;
    self.stateLabel.stringValue = enabled ? @"增强已开启" : @"增强已关闭";
    self.stateDot.layer.backgroundColor = (enabled ? NSColor.systemGreenColor : NSColor.secondaryLabelColor).CGColor;
    self.headerIcon.image = [NSImage imageWithSystemSymbolName:(enabled ? @"sun.max.fill" : @"sun.max")
                                      accessibilityDescription:@"亮度"];
    self.powerButton.contentTintColor = enabled ? NSColor.systemOrangeColor : NSColor.labelColor;
    self.slider.doubleValue = self.manager.selectedBoost;
    self.gauge.boost = self.manager.selectedBoost;
    self.gauge.enabled = enabled;
    [self.gauge setNeedsDisplay:YES];
    self.displayLabel.stringValue = [NSString stringWithFormat:@"▣  %lu 台 XDR 显示器", (unsigned long)self.manager.displayCount];
    self.statusLabel.stringValue = self.manager.statusMessage ?: @"";

    NSArray<NSNumber *> *presetValues = @[@1.25, @1.5, @1.75, @2.0];
    NSInteger selected = -1;
    for (NSInteger index = 0; index < (NSInteger)presetValues.count; index++) {
        if (fabs(self.manager.selectedBoost - presetValues[index].doubleValue) < 0.001) {
            selected = index;
            break;
        }
    }
    self.presets.selectedSegment = selected;

    NSString *statusSymbol = enabled ? @"sun.max.fill" : @"sun.max";
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:statusSymbol accessibilityDescription:@"VividBrightness"];
    self.statusItem.button.title = @"";
    self.statusItem.button.toolTip = enabled
        ? [NSString stringWithFormat:@"VividBrightness +%.0f%%", (self.manager.selectedBoost - 1.0) * 100.0]
        : @"VividBrightness";
}

- (void)togglePopover:(id)sender {
    (void)sender;
    if (self.testWindow != nil) {
        [self.testWindow makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }
    if (self.popover.isShown) {
        [self.popover performClose:nil];
    } else {
        [self.manager refreshDisplays];
        [self.popover showRelativeToRect:self.statusItem.button.bounds
                                  ofView:self.statusItem.button
                           preferredEdge:NSRectEdgeMinY];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)togglePower:(id)sender {
    (void)sender;
    [self.manager toggle];
}

- (void)sliderChanged:(NSSlider *)sender {
    [self.manager selectBoost:sender.doubleValue applyImmediately:self.manager.isEnabled];
}

- (void)presetChanged:(NSSegmentedControl *)sender {
    NSArray<NSNumber *> *values = @[@1.25, @1.5, @1.75, @2.0];
    if (sender.selectedSegment >= 0 && sender.selectedSegment < (NSInteger)values.count) {
        [self.manager selectBoost:values[sender.selectedSegment].doubleValue applyImmediately:YES];
    }
}

- (void)quit:(id)sender {
    (void)sender;
    [NSApp terminate:nil];
}

- (void)handleWake:(NSNotification *)notification {
    (void)notification;
    if (self.manager.isEnabled) {
        [self.manager reapplyAfterWake];
    } else {
        [self.manager refreshDisplays];
    }
}

- (BOOL)isBrightnessShortcut:(NSEvent *)event {
    NSEventModifierFlags mask = NSEventModifierFlagCommand | NSEventModifierFlagShift |
                                NSEventModifierFlagControl | NSEventModifierFlagOption;
    NSEventModifierFlags required = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    return event.keyCode == 11 && (event.modifierFlags & mask) == required;
}

- (void)installEventMonitors {
    __weak typeof(self) weakSelf = self;
    self.localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (![weakSelf isBrightnessShortcut:event]) return event;
        [weakSelf.manager increaseBoost];
        return nil;
    }];
    self.globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        if (![weakSelf isBrightnessShortcut:event]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.manager increaseBoost];
        });
    }];
}

@end

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
