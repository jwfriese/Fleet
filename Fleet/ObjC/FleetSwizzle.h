#import <Foundation/Foundation.h>

/**
 Internal Fleet use only
 */
void memorySafeExecuteSelector(Class klass, SEL selector);

/**
 Internal Fleet use only. The process-start hosting policy, resolved once from the
 `FLEET_HOSTING_POLICY` environment variable before any hook is selected:
 unset or "legacy" -> "legacy"; "preserve-timing" -> "preserve-timing".
 Any other value raises an NSException naming the accepted values.
 */
NSString * FleetResolvedHostingPolicyName(void);

/**
 Internal Fleet use only. YES when the resolved policy installs the nonanimated
 presentation/navigation hooks (legacy).
 */
BOOL FleetPolicyInstallsTimingHooks(void);
