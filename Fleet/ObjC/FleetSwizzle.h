#import <Foundation/Foundation.h>
#import <objc/runtime.h>

void memorySafeExecuteSelector(Class klass, SEL selector) {
    if ([klass respondsToSelector: selector]) {
        IMP implementation = [klass methodForSelector:selector];
        void (*execute)(id, SEL) = (void *)implementation;
        execute(klass, selector);
    }
}
