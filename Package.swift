// swift-tools-version: 6.3
import PackageDescription

let runtimeSources = [
    "ObjC/FleetObjC.m",
    "ObjC/FleetSwizzle.m",
    "CoreExtensions/Alerts/UIAlertAction+Fleet.m",
    "CoreExtensions/Storyboard/UIStoryboard+Fleet.m",
    "CoreExtensions/TableView/UITableViewRowAction+Fleet.m",
    "CoreExtensions/UINavigationController+Fleet.m",
    "CoreExtensions/ViewController/UIViewController+Fleet.m",
]

let package = Package(
    name: "Fleet",
    platforms: [.iOS(.v15), .tvOS(.v15)],
    products: [
        // Retain the Objective-C categories and their existing +load activation
        // in a single dynamic product. External hosted tests verify the hooks.
        .library(name: "Fleet", type: .dynamic, targets: ["Fleet"]),
    ],
    targets: [
        .target(
            name: "FleetRuntime",
            path: "Fleet",
            sources: runtimeSources,
            publicHeadersPath: "ObjC",
            cSettings: [.headerSearchPath("ObjC")]
        ),
        .target(
            name: "Fleet",
            dependencies: ["FleetRuntime"],
            path: "Fleet",
            exclude: runtimeSources + ["Info.plist", "Fleet.h", "ObjC/FleetObjC.h", "ObjC/FleetSwizzle.h"],
            sources: ["Fleet.swift", "CoreExtensions", "Error", "Logging", "Mocking", "Screen", "ObjC/Swizzle.swift"],
            resources: [.copy("Script/copy_storyboard_info_files.sh")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
