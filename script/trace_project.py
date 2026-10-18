"""Generate the standalone Xcode project for the UIKit collection-view reference traces."""

import hashlib
from pathlib import Path
import plistlib
import shutil


def create_project(destination, fixtures):
    destination = Path(destination)
    shutil.copytree(fixtures, destination / "Sources")
    project = destination / "Trace.xcodeproj"
    schemes = project / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True)
    objects = {}

    def add(identifier, isa, **fields):
        key = hashlib.sha256(identifier.encode()).hexdigest()[:24].upper()
        objects[key] = {"isa": isa, **fields}
        return key

    products = add("products", "PBXGroup", children=[], name="Products", sourceTree="<group>")
    main = add("main", "PBXGroup", children=[products], sourceTree="<group>")
    targets = []

    def configurations(name, settings):
        entries = [add(name + mode, "XCBuildConfiguration", name=mode, buildSettings={**settings})
                   for mode in ("Debug", "Release")]
        return add(name + "configuration-list", "XCConfigurationList", buildConfigurations=entries,
                   defaultConfigurationIsVisible="0", defaultConfigurationName="Debug")

    common = {"SWIFT_VERSION": "6.0", "CODE_SIGNING_ALLOWED": "NO", "GENERATE_INFOPLIST_FILE": "YES",
              "SWIFT_OPTIMIZATION_LEVEL": "-Onone", "ONLY_ACTIVE_ARCH": "YES",
              "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]}
    for platform, sdk, deployment, family in (("ios", "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET", "1,2"),
                                               ("tvos", "appletvos", "TVOS_DEPLOYMENT_TARGET", "3")):
        settings = {**common, "SDKROOT": sdk, deployment: "15.0", "TARGETED_DEVICE_FAMILY": family}

        def file(name):
            reference = add(platform + name, "PBXFileReference", path="Sources/" + name,
                            lastKnownFileType="sourcecode.swift", sourceTree="<group>")
            objects[main]["children"].append(reference)
            return reference

        app_file, test_file = file("TraceApp.swift"), file("TraceUITests.swift")
        app_product = add(platform + "app-product", "PBXFileReference", explicitFileType="wrapper.application",
                          path="TraceHost-" + platform + ".app", sourceTree="BUILT_PRODUCTS_DIR")
        test_product = add(platform + "test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle",
                           path="TraceUITests-" + platform + ".xctest", sourceTree="BUILT_PRODUCTS_DIR")
        objects[products]["children"].extend([app_product, test_product])

        def phase(identifier, isa, **fields):
            return add(platform + identifier, isa, buildActionMask="2147483647", runOnlyForDeploymentPostprocessing="0", **fields)

        def sources(name, reference):
            build_file = add(platform + name + "-build-file", "PBXBuildFile", fileRef=reference)
            return phase(name + "-sources", "PBXSourcesBuildPhase", files=[build_file])

        app_name, test_name = "TraceHost-" + platform, "TraceUITests-" + platform
        app = add(platform + "app", "PBXNativeTarget", name=app_name, productName="TraceHost",
                  productReference=app_product, productType="com.apple.product-type.application",
                  buildConfigurationList=configurations(platform + "app", {**settings,
                      "PRODUCT_NAME": app_name, "PRODUCT_MODULE_NAME": "TraceHost",
                      "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.trace." + platform,
                      "INFOPLIST_KEY_UILaunchScreen_Generation": "YES"}),
                  buildPhases=[sources("app", app_file), phase("app-frameworks", "PBXFrameworksBuildPhase", files=[])],
                  buildRules=[], dependencies=[], packageProductDependencies=[])
        dependency = add(platform + "host-dependency", "PBXTargetDependency", target=app)
        test = add(platform + "test", "PBXNativeTarget", name=test_name, productName=test_name,
                   productReference=test_product, productType="com.apple.product-type.bundle.ui-testing",
                   buildConfigurationList=configurations(platform + "test", {**settings,
                       "PRODUCT_NAME": test_name, "PRODUCT_MODULE_NAME": "TraceUITests",
                       "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.trace.uitests." + platform,
                       "TEST_TARGET_NAME": app_name}),
                   buildPhases=[sources("test", test_file), phase("test-frameworks", "PBXFrameworksBuildPhase", files=[])],
                   buildRules=[], dependencies=[dependency], packageProductDependencies=[])
        targets.extend([app, test])

        def reference(identifier, product, name):
            return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Trace.xcodeproj"/>'

        app_ref = reference(app, app_name + ".app", app_name)
        test_ref = reference(test, test_name + ".xctest", test_name)
        scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{test_ref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{test_ref}</TestableReference></Testables><MacroExpansion>{app_ref}</MacroExpansion></TestAction>
  <LaunchAction buildConfiguration="Debug" launchStyle="0"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
        (schemes / ("Trace-" + platform + ".xcscheme")).write_text(scheme)

    root = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2660"},
               buildConfigurationList=configurations("project", {}), compatibilityVersion="Xcode 14.0",
               developmentRegion="en", knownRegions=["en", "Base"], mainGroup=main,
               productRefGroup=products, projectDirPath="", projectRoot="", targets=targets)
    (project / "project.pbxproj").write_bytes(plistlib.dumps({"archiveVersion": "1", "classes": {},
        "objectVersion": "56", "objects": objects, "rootObject": root}, sort_keys=False))
    return project
