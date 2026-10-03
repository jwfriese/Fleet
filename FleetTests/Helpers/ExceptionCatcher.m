#import "ExceptionCatcher.h"

@implementation FleetTestExceptionCatcher
+ (NSException *)exceptionFromBlock:(void (^)(void))block {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
@end
