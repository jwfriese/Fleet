"""Generate a standalone Xcode consumer with a Git-pinned SwiftPM dependency."""

import hashlib
from pathlib import Path
import plistlib
import shutil


MODULE_NAME = "PantryApp"
MODULE_SOURCES = ("PantryModel.swift", "PantryScreen.swift")


def create_project(destination, fixtures, package_url, revision, viewinspector=None, snapshot=None):
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
    inspector = None
    if viewinspector:
        inspector = add("viewinspector", "XCRemoteSwiftPackageReference", repositoryURL=viewinspector[0],
                        requirement={"kind": "revision", "revision": viewinspector[1]})
    snapshotting = None
    if snapshot:
        snapshotting = add("snapshottesting", "XCRemoteSwiftPackageReference", repositoryURL=snapshot[0],
                           requirement={"kind": "revision", "revision": snapshot[1]})
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
        swift_testing_file = file("SwiftTestingConsumerTests.swift", "sourcecode.swift")
        proof_file = file("ViewInspector/ViewInspectorProofTests.swift", "sourcecode.swift") if inspector else None
        scoped_file = file("ViewInspector/ScopedInspectionTests.swift", "sourcecode.swift") if inspector else None
        module_test_file = file("ViewInspector/ExternalModuleAdoptionTests.swift", "sourcecode.swift") if inspector else None
        module_files = [file("AppModule/" + name, "sourcecode.swift") for name in MODULE_SOURCES] if inspector else []
        snapshot_file = file("SnapshotTesting/SnapshotEnvironmentTests.swift", "sourcecode.swift") if snapshotting else None
        cases_file = file("EnvironmentCasesConsumerTests.swift", "sourcecode.swift")
        swiftui_file = file("SwiftUIHostingConsumerTests.swift", "sourcecode.swift")
        crop_file = file("CropQueueConsumerTests.swift", "sourcecode.swift")
        household_file = file("HouseholdPlanConsumerTests.swift", "sourcecode.swift")
        presented_file = file("PresentedContentConsumerTests.swift", "sourcecode.swift")
        meal_drop_file = file("MealDropConsumerTests.swift", "sourcecode.swift")
        scenario_file = file("HostingTraceScenario.swift", "sourcecode.swift")
        baseline_file = file("BaselineTraceTests.swift", "sourcecode.swift")
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
        test_sources = phase("test-sources", "PBXSourcesBuildPhase", files=[build_file("test-build-file", test_file),
                                                                  build_file("swift-testing-build-file", swift_testing_file),
                                                                  build_file("swiftui-build-file", swiftui_file),
                                                                  build_file("crop-queue-build-file", crop_file),
                                                                  build_file("household-plan-build-file", household_file),
                                                                  build_file("presented-content-build-file", presented_file),
                                                                  build_file("meal-drop-build-file", meal_drop_file),
                                                                  build_file("cases-build-file", cases_file),
                                                                  *([build_file("proof-build-file", proof_file),
                                                                     build_file("scoped-build-file", scoped_file),
                                                                     build_file("module-test-build-file", module_test_file)] if inspector else []),
                                                                  *([build_file("snapshot-build-file", snapshot_file)] if snapshotting else []),
                                                                  build_file("scenario-build-file", scenario_file)])
        baseline_sources = phase("baseline-sources", "PBXSourcesBuildPhase", files=[
            build_file("baseline-test-build-file", baseline_file), build_file("baseline-scenario-build-file", scenario_file)])
        baseline_product = add(platform + "baseline-product", "PBXFileReference", explicitFileType="wrapper.cfbundle",
                               path="BaselineTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
        objects[products]["children"].append(baseline_product)
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
            dependencies, links = [dependency], [link]
            if inspector:
                extra = add(platform + name + "viewinspector-dependency", "XCSwiftPackageProductDependency",
                            package=inspector, productName="ViewInspector")
                dependencies.append(extra)
                links.append(add(platform + name + "viewinspector-link", "PBXBuildFile", productRef=extra))
            if snapshotting:
                extra = add(platform + name + "snapshottesting-dependency", "XCSwiftPackageProductDependency",
                            package=snapshotting, productName="SnapshotTesting")
                dependencies.append(extra)
                links.append(add(platform + name + "snapshottesting-link", "PBXBuildFile", productRef=extra))
            if module:
                links.append(add(platform + name + "module-link", "PBXBuildFile", fileRef=module_product))
            return dependencies, phase(name + "frameworks", "PBXFrameworksBuildPhase", files=links)

        module = None
        if inspector:
            # A separately compiled application framework: it has no package product dependency and no
            # Fleet or ViewInspector import. Only the test target links it.
            module_product = add(platform + "module-product", "PBXFileReference", explicitFileType="wrapper.framework",
                                 path=MODULE_NAME + ".framework", sourceTree="BUILT_PRODUCTS_DIR")
            objects[products]["children"].append(module_product)
            module = add(platform + "module", "PBXNativeTarget", name=MODULE_NAME + "-" + platform, productName=MODULE_NAME,
                         productReference=module_product, productType="com.apple.product-type.framework",
                         buildConfigurationList=configurations(platform + "module", {**settings,
                             "PRODUCT_NAME": MODULE_NAME, "PRODUCT_MODULE_NAME": MODULE_NAME, "DEFINES_MODULE": "YES",
                             "SKIP_INSTALL": "YES", "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.consumer.module." + platform,
                             "DYLIB_INSTALL_NAME_BASE": "@rpath"}),
                         buildPhases=[phase("module-sources", "PBXSourcesBuildPhase", files=[
                                          build_file("module-build-file-" + str(index), reference)
                                          for index, reference in enumerate(module_files)]),
                                      phase("module-frameworks", "PBXFrameworksBuildPhase", files=[])],
                         buildRules=[], dependencies=[], packageProductDependencies=[])
            targets.append(module)

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
        module_dependencies = [add(platform + "module-dependency", "PBXTargetDependency", target=module)] if module else []
        embed = [phase("module-embed", "PBXCopyFilesBuildPhase", dstPath="", dstSubfolderSpec="10", files=[
            add(platform + "module-embed-file", "PBXBuildFile", fileRef=module_product,
                settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})])] if module else []
        test = add(platform + "test", "PBXNativeTarget", name="ConsumerTests-" + platform,
                   productName="ConsumerTests", productReference=test_product,
                   productType="com.apple.product-type.bundle.unit-test",
                   buildConfigurationList=configurations(platform + "test", {**settings,
                       "PRODUCT_NAME": "ConsumerTests", "PRODUCT_MODULE_NAME": "ConsumerTests",
                       "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.consumer.tests." + platform,
                       "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/ConsumerHost-" + platform + ".app/ConsumerHost-" + platform,
                       "BUNDLE_LOADER": "$(TEST_HOST)"}),
                   buildPhases=[test_sources, test_frameworks, test_resources, script, *embed], buildRules=[],
                   dependencies=[dependency, *module_dependencies], packageProductDependencies=test_dependency)
        # The baseline bundle links no package product, so its process never loads Fleet or its runtime hooks.
        baseline = add(platform + "baseline", "PBXNativeTarget", name="BaselineTests-" + platform,
                       productName="BaselineTests", productReference=baseline_product,
                       productType="com.apple.product-type.bundle.unit-test",
                       buildConfigurationList=configurations(platform + "baseline", {**settings,
                           "PRODUCT_NAME": "BaselineTests", "PRODUCT_MODULE_NAME": "BaselineTests",
                           "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.consumer.baseline." + platform,
                           "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/ConsumerHost-" + platform + ".app/ConsumerHost-" + platform,
                           "BUNDLE_LOADER": "$(TEST_HOST)"}),
                       buildPhases=[baseline_sources, phase("baseline-frameworks", "PBXFrameworksBuildPhase", files=[])],
                       buildRules=[], dependencies=[dependency], packageProductDependencies=[])
        targets.extend([app, test, baseline])

        def reference(identifier, product, name):
            return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Consumer.xcodeproj"/>'

        app_ref = reference(app, "ConsumerHost-" + platform + ".app", app_name)
        test_ref = reference(test, "ConsumerTests.xctest", "ConsumerTests-" + platform)
        baseline_ref = reference(baseline, "BaselineTests.xctest", "BaselineTests-" + platform)

        def scheme_xml(tests):
            return f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{tests}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{tests}</TestableReference></Testables><MacroExpansion>{app_ref}</MacroExpansion></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
        (schemes / ("Consumer-" + platform + ".xcscheme")).write_text(scheme_xml(test_ref))
        (schemes / ("Baseline-" + platform + ".xcscheme")).write_text(scheme_xml(baseline_ref))

    root = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2660"},
               buildConfigurationList=configurations("project", {}), compatibilityVersion="Xcode 14.0",
               developmentRegion="en", knownRegions=["en", "Base"], mainGroup=main,
               productRefGroup=products, projectDirPath="", projectRoot="", targets=targets,
               packageReferences=[package] + ([inspector] if inspector else []) + ([snapshotting] if snapshotting else []))
    (project / "project.pbxproj").write_bytes(plistlib.dumps({"archiveVersion": "1", "classes": {},
        "objectVersion": "56", "objects": objects, "rootObject": root}, sort_keys=False))
    return project


MACOS_SOURCES = ("MacOSFixtures.swift", "MacOSXCTestConsumerTests.swift", "MacOSSwiftTestingConsumerTests.swift")


def create_macos_project(destination, fixtures, package_url, revision):
    """Generate a standalone macOS test-bundle project depending only on the Git-pinned FleetMacOS product."""
    destination = Path(destination)
    shutil.copytree(fixtures, destination / "Sources")
    project = destination / "MacOSConsumer.xcodeproj"
    schemes = project / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True)
    objects = {}

    def add(identifier, isa, **fields):
        key = hashlib.sha256(("macos" + identifier).encode()).hexdigest()[:24].upper()
        objects[key] = {"isa": isa, **fields}
        return key

    package = add("package", "XCRemoteSwiftPackageReference", repositoryURL=package_url,
                  requirement={"kind": "revision", "revision": revision})
    products = add("products", "PBXGroup", children=[], name="Products", sourceTree="<group>")
    main = add("main", "PBXGroup", children=[products], sourceTree="<group>")
    files = []
    for name in MACOS_SOURCES:
        reference = add(name, "PBXFileReference", path="Sources/" + name,
                        lastKnownFileType="sourcecode.swift", sourceTree="<group>")
        objects[main]["children"].append(reference)
        files.append(add(name + "-build", "PBXBuildFile", fileRef=reference))
    product = add("test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle",
                  path="MacOSConsumerTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
    objects[products]["children"].append(product)
    settings = {"SWIFT_VERSION": "6.0", "SDKROOT": "macosx", "MACOSX_DEPLOYMENT_TARGET": "13.0",
                "CODE_SIGNING_ALLOWED": "NO", "GENERATE_INFOPLIST_FILE": "YES", "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                "ONLY_ACTIVE_ARCH": "YES", "PRODUCT_NAME": "MacOSConsumerTests",
                "PRODUCT_MODULE_NAME": "MacOSConsumerTests", "PRODUCT_BUNDLE_IDENTIFIER": "org.fleet.consumer.tests.macos",
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks", "@loader_path/../Frameworks"]}

    def configurations(name, build_settings):
        entries = [add(name + mode, "XCBuildConfiguration", name=mode, buildSettings={**build_settings})
                   for mode in ("Debug", "Release")]
        return add(name + "configuration-list", "XCConfigurationList", buildConfigurations=entries,
                   defaultConfigurationIsVisible="0", defaultConfigurationName="Debug")

    def phase(identifier, isa, **fields):
        return add(identifier, isa, buildActionMask="2147483647", runOnlyForDeploymentPostprocessing="0", **fields)

    dependency = add("dependency", "XCSwiftPackageProductDependency", package=package, productName="FleetMacOS")
    link = add("link", "PBXBuildFile", productRef=dependency)
    test = add("test", "PBXNativeTarget", name="MacOSConsumerTests", productName="MacOSConsumerTests",
               productReference=product, productType="com.apple.product-type.bundle.unit-test",
               buildConfigurationList=configurations("test", settings),
               buildPhases=[phase("sources", "PBXSourcesBuildPhase", files=files),
                            phase("frameworks", "PBXFrameworksBuildPhase", files=[link])],
               buildRules=[], dependencies=[], packageProductDependencies=[dependency])
    root = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2660"},
               buildConfigurationList=configurations("project", {}), compatibilityVersion="Xcode 14.0",
               developmentRegion="en", knownRegions=["en", "Base"], mainGroup=main,
               productRefGroup=products, projectDirPath="", projectRoot="", targets=[test],
               packageReferences=[package])
    (project / "project.pbxproj").write_bytes(plistlib.dumps({"archiveVersion": "1", "classes": {},
        "objectVersion": "56", "objects": objects, "rootObject": root}, sort_keys=False))
    reference = (f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test}" '
                 'BuildableName="MacOSConsumerTests.xctest" BlueprintName="MacOSConsumerTests" '
                 'ReferencedContainer="container:MacOSConsumer.xcodeproj"/>')
    (schemes / "MacOSConsumer.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{reference}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0"/>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
    return project
