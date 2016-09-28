import Foundation

extension Bundle {

    /**
     Locates the first bundle with a '.xctest' file extension.

     Note: The original file this func was taken from can be found in the Quick
           project (https://github.com/Quick/Quick)
     */
    internal static var currentTestBundle: Bundle? {
        return allBundles.lazy
            .filter {
                $0.bundlePath.hasSuffix(".xctest")
            }
            .first
    }

}
