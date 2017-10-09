#import <Foundation/Foundation.h>

@interface FleetObjC: NSObject

/**
 Internal Fleet use only
 */
+ (id)_mockFor:(Class)klass;

/**
 Internal Fleet use only
 */
+ (BOOL)_isClass:(Class)klass kindOf:(Class)superclass;

+ (BOOL)_catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error;

@end
