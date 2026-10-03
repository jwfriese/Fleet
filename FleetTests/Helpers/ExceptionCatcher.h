#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Nimble's SwiftPM product does not include its Objective-C exception matcher.
@interface FleetTestExceptionCatcher : NSObject
+ (nullable NSException *)exceptionFromBlock:(void (^)(void))block;
@end

NS_ASSUME_NONNULL_END
