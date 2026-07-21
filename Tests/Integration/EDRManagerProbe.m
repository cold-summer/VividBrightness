#import <Cocoa/Cocoa.h>
#import "EDRBrightnessManager.h"

static double CurrentEDR(void) {
    double value = 1.0;
    for (NSScreen *screen in NSScreen.screens) {
        value = fmax(value, screen.maximumExtendedDynamicRangeColorComponentValue);
    }
    return value;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        EDRBrightnessManager *manager = [[EDRBrightnessManager alloc] init];
        double before = CurrentEDR();
        [manager selectBoost:1.5 applyImmediately:YES];

        double maximum = before;
        BOOL renderedFrames = NO;
        BOOL enabledOverlay = NO;
        BOOL reportedExpectedStatus = NO;
        for (NSInteger index = 0; index < 10; index++) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            double current = CurrentEDR();
            maximum = fmax(maximum, current);
            renderedFrames = renderedFrames || manager.renderedFrameCount > 0;
            enabledOverlay = enabledOverlay || manager.isEnabled;
            reportedExpectedStatus = reportedExpectedStatus ||
                [manager.statusMessage isEqualToString:@"XDR 已激活 · 当前增强 +50%"];
            printf("sample=%ld edr=%.6f frames=%lu overlays_enabled=%s\n",
                   (long)index + 1, current, (unsigned long)manager.renderedFrameCount,
                   manager.isEnabled ? "true" : "false");
            fflush(stdout);
        }

        [manager resetBrightness];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
        printf("before=%.6f maximum=%.6f supported_displays=%lu\n",
               before, maximum, (unsigned long)manager.displayCount);
        if (maximum <= 1.05) return 6;
        if (!enabledOverlay) return 7;
        if (!renderedFrames) return 8;
        if (!reportedExpectedStatus) return 9;
        return 0;
    }
}
