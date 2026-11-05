// swift-tools-version: 6.3
import PackageDescription

let runtimeSources = [
    "ObjC/FleetObjC.m",
    "ObjC/FleetSwizzle.m",
    "CoreExtensions/Alerts/UIAlertAction+Fleet.m",
    "CoreExtensions/Storyboard/UIStoryboard+Fleet.m",
    "CoreExtensions/UINavigationController+Fleet.m",
    "CoreExtensions/ViewController/UIViewController+Fleet.m",
]

let package = Package(
    name: "Fleet",
    platforms: [.iOS(.v15), .tvOS(.v15), .macOS(.v13)],
    products: [
        // Retain the Objective-C categories and their existing +load activation
        // in a single dynamic product. External hosted tests verify the hooks.
        .library(name: "Fleet", type: .dynamic, targets: ["Fleet"]),
        // Test-only macOS SwiftUI hosting. Independent of UIKit and the Objective-C runtime hooks.
        .library(name: "FleetMacOS", targets: ["FleetMacOS"]),
        // Optional, test-only interaction adapter for FleetMacOS-hosted Button/TextField/SecureField/TextEditor.
        // ViewInspector is an implementation dependency; hosting-only consumers do not link it.
        .library(name: "FleetMacOSInspection", targets: ["FleetMacOSInspection"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", exact: "0.10.5"),
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
            sources: ["Fleet.swift", "CoreExtensions", "Error", "Hosting", "Logging", "Mocking", "Screen", "ObjC/Swizzle.swift"],
            resources: [.copy("Script/copy_storyboard_info_files.sh")]
        ),
        .target(name: "FleetMacOS", path: "FleetMacOS"),
        .target(
            name: "FleetMacOSInspection",
            dependencies: ["FleetMacOS", .product(name: "ViewInspector", package: "ViewInspector")],
            path: "FleetMacOSInspection"
        ),
        .testTarget(name: "FleetMacOSTests", dependencies: ["FleetMacOS"], path: "FleetMacOSTests"),
    ],
    swiftLanguageModes: [.v6]
)
