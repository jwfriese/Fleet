# Fleet compatibility and distribution

The next major Fleet release targets iOS 15 and tvOS 15 and uses Swift Package Manager as its supported installation route. These decisions apply to development after Fleet 4.6.1; existing tags keep their historical requirements. This checkout contains the package and external hosted consumer checks; no new major release has been published. Publication requires full validation of the chosen committed release revision.

## Development baseline

| Setting | Selected baseline |
| --- | --- |
| Platforms | iOS 15 or later and tvOS 15 or later |
| Supported development toolchain | Xcode 26.6 with Apple Swift 6.3.3 |
| Swift language mode | Swift 6 for the library, native hosts/tests, and external consumers |
| SwiftPM manifest tools version | 6.3 |
| Verified simulator runtimes | iOS 26.5 and tvOS 26.5 |
| Test command | `script/test all`, with hosted XCTest suites running serially |

The framework, test targets, host applications, project defaults, and historical podspec now agree on the minimum OS version. Apple lists iOS 15 and tvOS 15 as the lower bound for Xcode 26.6's supported deployment range in its [Xcode system requirements](https://developer.apple.com/xcode/system-requirements). Passing on the current simulators establishes current-runtime behavior; it does not establish runtime coverage on every OS back to 15. Additional runtime and toolchain combinations must pass before being described as verified.

The SwiftPM tools version controls manifest features and the minimum tools capable of reading the package. It is distinct from the language mode used to compile Fleet; see the [SwiftPM manifest documentation](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html). This checkout separately selects Swift 6 language mode for Fleet; dependencies retain their own declared modes.

## Distribution policy

SwiftPM is the supported distribution route for the next major release. [Installation instructions](Installation/SwiftPM.md) describe the dynamic `Fleet` product and storyboard setup. `script/check-distribution` exercises external iOS and tvOS test hosts importing Fleet, Objective-C runtime initialization, control actions, navigation, and storyboard metadata and binding. Successful manifest resolution or a framework build is insufficient. See [Releasing Fleet](Releasing.md) for the publication gate.

CocoaPods, Carthage, and direct project/submodule integration are historical routes for Fleet 4.x. Users needing those routes should stay on an existing 4.x release and consult that tag's instructions: [iOS at 4.6.1](https://github.com/jwfriese/Fleet/blob/4.6.1/Documentation/Installation/iOS.md) and [tvOS at 4.6.1](https://github.com/jwfriese/Fleet/blob/4.6.1/Documentation/Installation/tvOS.md). This policy does not promise new maintenance releases or compatibility between those old releases and current Xcode.

The podspec remains in the repository for historical metadata and release-version consistency. Its presence does not promise CocoaPods publication for the next major release. Release tooling will continue to update its version, but will not publish it to CocoaPods trunk.

## Migrating to the next major release

Raise the application and hosted test deployment targets to at least iOS 15 or tvOS 15 and use the documented Xcode baseline. Replace the old Fleet dependency with the SwiftPM product and follow the [storyboard setup instructions](Installation/SwiftPM.md). Until the next major version is published, use a local checkout for development rather than an old tag that lacks the manifest.

Fleet's UI helpers and `FLTScreen` run on `@MainActor`, as do storyboard bindings and associated-object state. Mark UIKit test classes or methods `@MainActor`. Use `override func setUp() async throws` and `override func tearDown() async throws` when fixtures need UI state; await `super` and bounded `fulfillment`/polling calls. Callers on other actors must hop to the main actor before creating or inspecting UI, as exercised by the [detached-task consumer test](../Integration/PackageConsumer/PackageConsumerTests.swift).

The Objective-C `+load` installers remain synchronous and nonisolated and touch only runtime method tables. The instance hooks preserve UIKit's main-thread requirement; Objective-C does not enforce Swift actor annotations, so its callers must follow that requirement too. `Fleet.swallowAnyErrors` remains a synchronous, actor-neutral exception catcher: its closure executes on the calling actor without dispatch or storage. Hosted consumers verify exception closures, presentation completions, alert callbacks, and automatic hook activation in Swift 6 mode. Concurrency checking is not disabled globally, and this migration adds no unsafe Sendable conformances or unsafe isolation annotations.

Keep using hosted tests for UIKit behavior and preserve serial execution around shared application UI state. Actor isolation protects UI access but does not serialize whole async tests. Scene hosting, test cleanup, typed errors, and overlapping Swift Testing suites remain separate modernization work. A release with raised OS requirements and retired installation routes must use a new major version; this document does not select or publish that version.
