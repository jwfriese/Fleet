#import "FleetObjC.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

IMP createViewDidLoadImpl() {
    id block = ^(id self, SEL _cmd) {};
    return imp_implementationWithBlock(block);
}

const char * getViewDidLoadTypes(Class klass) {
    Method viewDidLoadMethod = class_getInstanceMethod(klass, @selector(viewDidLoad));
    return method_getTypeEncoding(viewDidLoadMethod);
}

IMP createViewWillAppearImpl() {
    id block = ^(id self, SEL _cmd, BOOL animated) {};
    return imp_implementationWithBlock(block);
}

const char * getViewWillAppearTypes(Class klass) {
    Method viewWillAppearMethod = class_getInstanceMethod(klass, @selector(viewWillAppear:));
    return method_getTypeEncoding(viewWillAppearMethod);
}

IMP createViewDidAppearImpl() {
    id block = ^(id self, SEL _cmd, BOOL animated) {};
    return imp_implementationWithBlock(block);
}

const char * getViewDidAppearTypes(Class klass) {
    Method viewDidAppearMethod = class_getInstanceMethod(klass, @selector(viewDidAppear:));
    return method_getTypeEncoding(viewDidAppearMethod);
}

IMP createViewWillDisappearImpl() {
    id block = ^(id self, SEL _cmd, BOOL animated) {};
    return imp_implementationWithBlock(block);
}

const char * getViewWillDisappearTypes(Class klass) {
    Method viewWillDisappearMethod = class_getInstanceMethod(klass, @selector(viewWillDisappear:));
    return method_getTypeEncoding(viewWillDisappearMethod);
}

IMP createViewDidDisappearImpl() {
    id block = ^(id self, SEL _cmd, BOOL animated) {};
    return imp_implementationWithBlock(block);
}

const char * getViewDidDisappearTypes(Class klass) {
    Method viewDidDisappearMethod = class_getInstanceMethod(klass, @selector(viewDidDisappear:));
    return method_getTypeEncoding(viewDidDisappearMethod);
}

@implementation FleetObjC

+ (id)_mockFor:(Class)klass {
    NSString *originalClassName = [NSString stringWithCString:class_getName(klass) encoding:NSUTF8StringEncoding];
    NSString *mockClassName = [NSString stringWithFormat:@"fleet_mock_%@", originalClassName];
    const char *mockClassNameCString = [mockClassName cStringUsingEncoding:NSUTF8StringEncoding];
    Class mockClass = objc_getClass(mockClassNameCString);
    if (mockClass == nil) {
        mockClass = objc_allocateClassPair(klass, mockClassNameCString, 0);
        class_addMethod(mockClass, @selector(viewDidLoad), createViewDidLoadImpl(), getViewDidLoadTypes(mockClass));
        class_addMethod(mockClass, @selector(viewWillAppear:), createViewWillAppearImpl(), getViewWillAppearTypes(mockClass));
        class_addMethod(mockClass, @selector(viewDidAppear:), createViewDidAppearImpl(), getViewDidAppearTypes(mockClass));
        class_addMethod(mockClass, @selector(viewWillDisappear:), createViewWillDisappearImpl(), getViewWillDisappearTypes(mockClass));
        class_addMethod(mockClass, @selector(viewDidDisappear:), createViewDidDisappearImpl(), getViewDidDisappearTypes(mockClass));
        objc_registerClassPair(mockClass);
    }
    
    id instance = [[mockClass alloc] init];
    
    return instance;
}

+ (BOOL)_isClass:(Class)klass kindOf:(Class)superclass {
    if (klass == superclass) {
        return YES;
    }
    
    Class currentClass = class_getSuperclass(klass);
    while (currentClass != nil) {
        if (currentClass == superclass) {
            return YES;
        }
        
        currentClass = class_getSuperclass(currentClass);
    }
    
    return NO;
}

@end
