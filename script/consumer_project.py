"""Generate a standalone Xcode consumer with a Git-pinned SwiftPM dependency."""

import hashlib
from pathlib import Path
import plistlib
import shutil


def create_project(destination, fixtures, package_url, revision):
    destination = Path(destination)
    shutil.copytree(fixtures, destination / "Sources")
    project = destination / "Consumer.xcodeproj"
    schemes = project / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True)
    objects = {}

    def add(identifier, isa, **fields):
        key = hashlib.sha256(identifier.encode()).hexdigest()[:24].upper()
        objects[key] = {"isa": isa, **fields}
        return key

    package = add("package", "XCRemoteSwiftPackageReference", repositoryURL=package_url,
                  requirement={"kind": "revision", "revision": revision})
    products = add("products", "PBXGroup", children=[], name="Products", sourceTree="<group>")
    main = add("main", "PBXGroup", children=[products], sourceTree="<group>")
    targets = []

    def configurations(name, settings):
        entries = [add(name + mode, "XCBuildConfiguration", name=mode, buildSettings={**settings})
                   for mode in ("Debug", "Release")]
        return add(name + "configuration-list", "XCConfigurationList", buildConfigurations=entries,
                   defaultConfigurationIsVisible="0", defaultConfigurationName="Debug")

    common = {"SWIFT_VERSION": "6.0", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
              "CODE_SIGNING_ALLOWED": "NO", "GENERATE_INFOPLIST_FILE": "YES",
              "SWIFT_OPTIMIZATION_LEVEL": "-Onone", "ONLY_ACTIVE_ARCH": "YES",
              "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]}
    for platform, sdk, deployment, family in (("ios", "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET", "1,2"),
                                               ("tvos", "appletvos", "TVOS_DEPLOYMENT_TARGET", "3")):
        settings = {**common, "SDKROOT": sdk, deployment: "15.0", "TARGETED_DEVICE_FAMILY": family}

        def file(name, kind):
            reference = add(platform + name, "PBXFileReference", path="Sources/" + name,
                            lastKnownFileType=kind, sourceTree="<group>")
            objects[main]["children"].append(reference)
            return reference

        app_file = file("AppDelegate.swift", "sourcecode.swift")
        test_file = file("PackageConsumerTests.swift", "sourcecode.swift")
        storyboard = file(platform + "/Consumer.storyboard", "file.storyboard")
        app_product = add(platform + "app-product", "PBXFileReference", explicitFileType="wrapper.application",
                          path="ConsumerHost-" + platform + ".app", sourceTree="BUILT_PRODUCTS_DIR")
        test_product = add(platform + "test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle",
                           path="ConsumerTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
        objects[products]["children"].extend([app_product, test_product])

        def phase(identifier, isa, **fields):
            return add(platform + identifier, isa, buildActionMask="2147483647", runOnlyForDeploymentPostprocessing="0", **fields)

        def build_file(name, reference):
            return add(platform + name, "PBXBuildFile", fileRef=reference)

        app_sources = phase("app-sources", "PBXSourcesBuildPhase", files=[build_file("app-build-file", app_file)])
        resources = phase("app-resources", "PBXResourcesBuildPhase", files=[build_file("storyboard-build-file", storyboard)])
        test_sources = phase("test-sources", "PBXSourcesBuildPhase", files=[build_file("test-build-file", test_file)])
        test_resources = phase("test-resources", "PBXResourcesBuildPhase", files=[])
        script = phase("metadata", "PBXShellScriptBuildPhase", files=[], alwaysOutOfDate="1",
                       inputPaths=["$(SRCROOT)/Sources/CopyStoryboardMetadata.sh"],
                       outputPaths=["$(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/StoryboardInfo"],
                       name="Copy Fleet storyboard metadata", shellPath="/bin/bash",
                       shellScript='/bin/bash "$SRCROOT/Sources/CopyStoryboardMetadata.sh"')

        def frameworks(name):
            dependency = add(platform + name + "dependency", "XCSwiftPackageProductDependency",
                             package=package, productName="Fleet")
            link = add(platform + name + "link", "PBXBuildFile", productRef=dependency)
            return dependency, phase(name + "frameworks", "PBXFrameworksBuildPhase", files=[link])

        app_frameworks = phase("app-frameworks", "PBXFrameworksBuildPhase", files=[])
        test_dependency, test_frameworks = frameworks("test")
        app_name = "ConsumerHost-" + platform
        app = add(platform + "app", "PBXNativeTarget", name=app_name, productName="ConsumerHost",
                  productReference=app_product, productType="com.apple.product-type.application",
                  buildConfigurationList=configurations(platform + "app", {**settings,
                      "PRODUCT_NAME": "ConsumerHost-" + platform, "PRODUCT_MODULE_NAME": "ConsumerHost",
                      "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.consumer." + platform,
                      "INFOPLIST_KEY_UILaunchScreen_Generation": "YES"}),
                  buildPhases=[app_sources, app_frameworks, resources], buildRules=[], dependencies=[],
                  packageProductDependencies=[])
        dependency = add(platform + "host-dependency", "PBXTargetDependency", target=app)
        test = add(platform + "test", "PBXNativeTarget", name="ConsumerTests-" + platform,
                   productName="ConsumerTests", productReference=test_product,
                   productType="com.apple.product-type.bundle.unit-test",
                   buildConfigurationList=configurations(platform + "test", {**settings,
                       "PRODUCT_NAME": "ConsumerTests", "PRODUCT_MODULE_NAME": "ConsumerTests",
                       "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.consumer.tests." + platform,
                       "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/ConsumerHost-" + platform + ".app/ConsumerHost-" + platform,
                       "BUNDLE_LOADER": "$(TEST_HOST)"}),
                   buildPhases=[test_sources, test_frameworks, test_resources, script], buildRules=[],
                   dependencies=[dependency], packageProductDependencies=[test_dependency])
        targets.extend([app, test])

        def reference(identifier, product, name):
            return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Consumer.xcodeproj"/>'

        app_ref = reference(app, "ConsumerHost-" + platform + ".app", app_name)
        test_ref = reference(test, "ConsumerTests.xctest", "ConsumerTests-" + platform)
        scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{test_ref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{test_ref}</TestableReference></Testables><MacroExpansion>{app_ref}</MacroExpansion></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
        (schemes / ("Consumer-" + platform + ".xcscheme")).write_text(scheme)

    root = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2660"},
               buildConfigurationList=configurations("project", {}), compatibilityVersion="Xcode 14.0",
               developmentRegion="en", knownRegions=["en", "Base"], mainGroup=main,
               productRefGroup=products, projectDirPath="", projectRoot="", targets=targets,
               packageReferences=[package])
    (project / "project.pbxproj").write_bytes(plistlib.dumps({"archiveVersion": "1", "classes": {},
        "objectVersion": "56", "objects": objects, "rootObject": root}, sort_keys=False))
    return project
