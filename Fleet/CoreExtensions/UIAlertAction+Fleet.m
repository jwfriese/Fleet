#import "UIAlertAction+Fleet.h"
#import <objc/runtime.h>

@interface ObjectifiedBlock : NSObject

@property (nonatomic, copy) void (^block)(UIAlertAction *);

- (instancetype)initWithBlock:(void (^)(UIAlertAction *))block;

@end

@implementation ObjectifiedBlock

- (instancetype)initWithBlock:(void (^)(UIAlertAction *))block {
    if (self == [super init]) {
        self.block = block;
    }

    return self;
}

@end

BOOL didSwizzleUIAlertAction = NO;
unsigned int handlerAssociatedKey = 0;

@interface UIAlertAction (FleetPrivate)

@property (nonatomic, copy) void (^fleet_property_handler)(UIAlertAction *);

@end

@implementation UIAlertAction (FleetPrivate)

+ (void)initialize {
    if (self == [UIAlertAction class]) {
        if (!didSwizzleUIAlertAction) {
            [self swizzleHandlerSettler];
            didSwizzleUIAlertAction = YES;
        }
    }
}

+ (void)swizzleHandlerSettler {
    SEL originalSelector = NSSelectorFromString(@"setHandler:");
    SEL swizzledSelector = @selector(fleet_setHandler:);

    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);

    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (void)fleet_setHandler:(void (^)(UIAlertAction *))handler {
    self.fleet_property_handler = handler;
    [self fleet_setHandler: handler];
}

- (void (^)(UIAlertAction *))fleet_property_handler {
    ObjectifiedBlock *block = objc_getAssociatedObject(self, &handlerAssociatedKey);
    return [block block];
}

- (void)setFleet_property_handler:(void (^)(UIAlertAction *))fleet_property_handler {
    ObjectifiedBlock *block = [[ObjectifiedBlock alloc] initWithBlock: fleet_property_handler];
    objc_setAssociatedObject(self, &handlerAssociatedKey, block, OBJC_ASSOCIATION_RETAIN);
}

@end
