#import <UIKit/UIKit.h>
#import "FleetSwizzle.h"

BOOL didSwizzleUINavigationController = NO;

@implementation UINavigationController (FleetPrivate)

+ (void)load {
    if (self == [UINavigationController class]) {
        if (!didSwizzleUINavigationController) {
            [self objc_swizzlePushViewController];
            [self objc_swizzlePopViewController];
            [self objc_swizzlePopToViewController];
            [self objc_swizzlePopToRootViewControllerAnimated];
            didSwizzleUINavigationController = YES;
        }
    }
}

+ (void)objc_swizzlePushViewController {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzlePushViewController"));
}

+ (void)objc_swizzlePopViewController {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzlePopViewController"));
}

+ (void)objc_swizzlePopToViewController {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzlePopToViewController"));
}

+ (void)objc_swizzlePopToRootViewControllerAnimated {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzlePopToRootViewControllerAnimated"));
}

@end
