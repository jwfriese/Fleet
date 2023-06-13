#import <UIKit/UIKit.h>
#import "FleetSwizzle.h"

BOOL didSwizzleUIAlertAction = NO;

@implementation UIAlertAction (FleetPrivate)

+ (void)load {
    if (self == [UIAlertAction class]) {
        if (!didSwizzleUIAlertAction) {
            [self objc_swizzleHandlerSetter];
            didSwizzleUIAlertAction = YES;
        }
    }
}

+ (void)objc_swizzleHandlerSetter {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzleHandlerSetter"));
}

@end
