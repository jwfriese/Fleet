extension Fleet {
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
