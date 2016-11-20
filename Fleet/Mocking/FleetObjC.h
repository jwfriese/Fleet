#import <Foundation/Foundation.h>

@interface FleetObjC: NSObject

+ (id)mockFor:(Class)klass;
+ (BOOL)isClass:(Class)klass kindOf:(Class)superclass;

@end
