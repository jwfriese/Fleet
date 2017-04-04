#import <UIKit/UIKit.h>
#import "FleetSwizzle.h"

BOOL didSwizzleUITableViewRowAction = NO;

@implementation UITableViewRowAction (FleetPrivate)

+ (void)initialize {
    if (self == [UITableViewRowAction class]) {
        if (!didSwizzleUITableViewRowAction) {
            [self objc_swizzleInit];
            didSwizzleUITableViewRowAction = YES;
        }
    }
}

+ (void)objc_swizzleInit {
    memorySafeExecuteSelector(self, NSSelectorFromString(@"swizzleInit"));
}

@end
