#import <UIKit/UIKit.h>
#import "FleetSwizzle.h"

BOOL didSwizzleUITableViewRowAction = NO;

@implementation UITableViewRowAction (FleetPrivate)

+ (void)load {
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
