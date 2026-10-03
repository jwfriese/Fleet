#if SWIFT_PACKAGE
import FleetRuntime
#endif

extension Fleet {
    // The Objective-C catcher invokes its block synchronously without dispatching
    // or storing it, preserving the calling actor (including MainActor UI closures).
    public static func swallowAnyErrors(_ throwable: @escaping () -> ()) {
        do {
            try FleetObjC._catchException {
                throwable()
            }
        } catch {
            print("`Fleet.swallowAnyErrors` caught an error: \(error)")
        }
    }
}
