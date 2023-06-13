#import <UIKit/UIKit.h>
#import "FleetSwizzle.h"

BOOL didSwizzleUIStoryboard = NO;

@implementation UIStoryboard (FleetPrivate)

+ (void)load {
    if (self == [UIStoryboard class]) {
        if (!didSwizzleUIStoryboard) {
            [self objc_swizzleViewControllerInstantiationMethod];
            didSwizzleUIStoryboard = YES;
        }
    }
}

+ (void)objc_swizzleViewControllerInstantiationMethod {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzleViewControllerInstantiationMethod"));
}

@end
