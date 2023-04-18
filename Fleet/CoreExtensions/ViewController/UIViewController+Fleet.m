#import <UIKit/UIKit.h>
#import "FleetSwizzle.h"

BOOL didSwizzleUIViewController = NO;

@implementation UIViewController (FleetPrivate)

+ (void)load {
    if (self == [UIViewController class]) {
        if (!didSwizzleUIViewController) {
            [self objc_swizzleViewDidLoad];
            [self objc_swizzlePresent];
            [self objc_swizzleDismiss];
            didSwizzleUIViewController = YES;
        }
    }
}

+ (void)objc_swizzleViewDidLoad {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzleViewDidLoad"));
}

+ (void)objc_swizzlePresent {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzlePresent"));
}

+ (void)objc_swizzleDismiss {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzleDismiss"));
}

@end
