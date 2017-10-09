extension Fleet {
    public static func `do`(_ throwable: @escaping () -> ()) {
        do {
            try FleetObjC._catchException {
                throwable()
            }
        } catch {
            print("`Fleet.do` caught an error: \(error)")
        }
    }
}
