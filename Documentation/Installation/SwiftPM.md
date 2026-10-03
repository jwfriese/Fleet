# Installing Fleet with SwiftPM

Fleet's next major release uses a dynamic SwiftPM product named `Fleet`, with minimum deployment targets of iOS 15 and tvOS 15. Use Xcode 26.6 and Swift tools 6.3 or newer for the manifest; Fleet and the maintained consumer fixtures compile in Swift 6 language mode. The supported and verified combinations are recorded in [compatibility and distribution](../Compatibility.md).

This checkout contains the package, but no new major release has been published. During development, add this checkout as a local package in Xcode. Once the reviewed major release is published, add `https://github.com/jwfriese/Fleet` through Xcode's package dependency UI and select that release. Do not select an older 4.x tag expecting it to contain this manifest.

## Configure hosted tests

Add the `Fleet` product to your hosted unit test target and use `import Fleet` in its Swift files. The [external consumer fixture](../../Integration/PackageConsumer) links Fleet only to the test target; the application host does not depend on Fleet. Xcode embeds the dynamic product and its resources for the hosted tests.

Mark UIKit test classes or methods `@MainActor`; Fleet UI helpers require main-actor access. Use async XCTest setup/teardown for UI fixtures and bounded async waits for completion. Use a UIKit application host with a window. The maintained fixture uses an app-delegate window; scene-based hosting is still tracked separately. Run tests serially around Fleet's shared application state and process-wide hooks. Fleet remains a UIKit library; plain macOS `swift test` cannot run its hosted suites.

## Configure storyboard metadata

Only tests using Fleet's storyboard binding/mocking need this phase. Compile the storyboards in the application host and make that host a dependency of the test target. Add a Run Script phase to the test target after its framework/resource phases, set its shell to `/bin/bash`, and uncheck **Based on dependency analysis** so host storyboard changes refresh the copied metadata.

Use the contents of the maintained [CopyStoryboardMetadata.sh](../../Integration/PackageConsumer/CopyStoryboardMetadata.sh) as the phase script. It finds Fleet's script inside the built package resource bundle without depending on SwiftPM's generated bundle name, then runs it with the test target's Xcode environment. It fails the build if the resource is missing or ambiguous. The bundled script validates the host intermediates, rejects conflicting metadata, and preserves previous output on failure.

Declare `$(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/StoryboardInfo` as an output. If the phase invokes a saved wrapper file, declare that file as an input. The test host's target name and executable/product name must match for the current metadata discovery convention; renaming that layout requires an explicit integration change. For tests that do not use storyboards, omit the phase.

The script discovers the host through `TEST_HOST` and copies compiler metadata into the test bundle. Storyboard creation itself should use the host's bundle, for example:

```swift
@MainActor
final class StoryboardTests: XCTestCase {
    func testBinding() throws {
        let storyboard = UIStoryboard(name: "Consumer", bundle: .main)
        let replacement = UIViewController()
        try storyboard.bind(viewController: replacement, toIdentifier: "Detail")
        XCTAssertTrue(storyboard.instantiateViewController(withIdentifier: "Detail") === replacement)
    }
}
```

The [consumer tests](../../Integration/PackageConsumer/PackageConsumerTests.swift) exercise these public calls on both platforms, including rejection of an already loaded controller and lifecycle suppression for storyboard mocks.

## Validate the distributed checkout

On a clean committed checkout, run:

```sh
script/check-distribution
```

The checker generates an independent application/test project under `build/distribution-*`, resolves Fleet through a Git package URL pinned to this checkout's exact commit, verifies the resolved revision, and runs both hosted consumer suites. It retains resolution/build logs, result bundles, the package lockfile, and a validation receipt. Failures and empty test runs return nonzero.

For development before committing, use `script/check-distribution --allow-dirty`. It builds a temporary Git snapshot of the package sources and records that the result is a development snapshot. A single-platform diagnostic is available as `script/check-distribution ios --allow-dirty` or `tvos`. Release validation always runs the default command on a clean checkout for both platforms; development snapshots do not certify publication.

`DEVELOPER_DIR`, `FLEET_BUILD_DIR`, and single-platform `FLEET_TEST_DESTINATION` overrides work as in the canonical runner. See [Releasing Fleet](../Releasing.md) for the full validation and publication process.
