#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        for (NSScreen *screen in NSScreen.screens) {
            NSNumber *screenNumber = screen.deviceDescription[@"NSScreenNumber"];
            printf("display=%u name=%s current=%.6f potential=%.6f reference=%.6f\n",
                   screenNumber.unsignedIntValue,
                   screen.localizedName.UTF8String,
                   screen.maximumExtendedDynamicRangeColorComponentValue,
                   screen.maximumPotentialExtendedDynamicRangeColorComponentValue,
                   screen.maximumReferenceExtendedDynamicRangeColorComponentValue);
        }
    }
    return 0;
}
