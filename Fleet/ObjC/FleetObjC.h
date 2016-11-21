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

@end
