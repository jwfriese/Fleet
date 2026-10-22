#import "FleetSwizzle.h"
#import <objc/runtime.h>

void memorySafeExecuteSelector(Class klass, SEL selector) {
    if ([klass respondsToSelector: selector]) {
        IMP implementation = [klass methodForSelector:selector];
        void (*execute)(id, SEL) = (void *)implementation;
        execute(klass, selector);
    }
}

static NSString * const FleetHostingPolicyVariable = @"FLEET_HOSTING_POLICY";
static NSString * const FleetHostingPolicyLegacy = @"legacy";
static NSString * const FleetHostingPolicyPreserveTiming = @"preserve-timing";

NSString * FleetResolvedHostingPolicyName(void) {
    static NSString *resolved = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const char *raw = getenv("FLEET_HOSTING_POLICY");
        if (raw == NULL || raw[0] == '\0') {
            resolved = FleetHostingPolicyLegacy;
            return;
        }
        NSString *value = [NSString stringWithUTF8String:raw];
        if ([value isEqualToString:FleetHostingPolicyLegacy] || [value isEqualToString:FleetHostingPolicyPreserveTiming]) {
            resolved = value;
            return;
        }
        [NSException raise:@"FleetInvalidHostingPolicy"
                    format:@"Invalid %@ value '%@'. Accepted values: '%@' (default) or '%@'. The policy is fixed at process start.",
         FleetHostingPolicyVariable, value, FleetHostingPolicyLegacy, FleetHostingPolicyPreserveTiming];
    });
    return resolved;
}

BOOL FleetPolicyInstallsTimingHooks(void) {
    return [FleetResolvedHostingPolicyName() isEqualToString:FleetHostingPolicyLegacy];
}
