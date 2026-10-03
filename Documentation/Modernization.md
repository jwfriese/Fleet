# Fleet modernization checklist

The goal is to make Fleet straightforward to build, dependable to test, and ready for regular feature development. Preserve its focus on exercising real UIKit screen behavior with isolated dependencies. Work through the milestones below in order, using small changes with regression tests for behavior changes.

This is an implementation backlog based on a repository audit on October 2, 2026. Checkboxes track completed work; the starting-point findings below preserve the original audit. Findings from source inspection identify work to investigate or correct; they do not establish how every supported OS behaves at runtime. Proposed compatibility and API choices should be settled before implementing changes that depend on them.

## Verified starting point

The audit machine has Xcode 26.6, build 17F113, and Apple Swift 6.3.3. No dependencies or platform SDKs were installed during the audit.

| Check | Result | Implication |
| --- | --- | --- |
| iOS framework build for a generic simulator | Passed with existing Swift 5 language settings, including arm64 and x86_64 | The existing framework can compile with this toolchain. Runtime compatibility remains unverified. |
| iOS build for testing | Failed with `unable to resolve module dependency: 'Nimble'` | Restore dependency resolution before assessing the test suite. No tests ran. |
| iOS framework build with `SWIFT_VERSION=6` | Failed on concurrency checks for global mutable state | Associated-object keys, swizzle flags, and the storyboard binding map need attention. Additional errors may appear after these are fixed. |
| tvOS framework build for a generic simulator | Could not select a destination because the tvOS platform SDK is not installed | This is an environment limitation; it establishes no tvOS compilation result. |

The framework builds used `CODE_SIGNING_ALLOWED=NO` and derived data outside the repository. The initial sandboxed iOS build could not access Xcode services; the successful check ran with the required access. Build logs are temporary audit artifacts, rather than project prerequisites.

## Phase 0 implementation

The development baseline now uses Xcode 26.6, Swift 6.3.3 in Swift 5 language mode, and iOS/tvOS 26.5 simulators. Installing the tvOS platform enabled its previously unverified test host to compile and run. The canonical command is `script/test all`; `script/test` runs iOS and `script/test tvos` runs tvOS separately. Each run retains logs and an `.xcresult` bundle under `build/`, executes serially, and enables XCTest timeouts.

The iOS suite passes 251 tests and the tvOS suite passes 121 tests. Five Python tooling checks verify simulator selection and runner behavior, including failure propagation. Nimble 14 is pinned through Xcode SwiftPM, with a test-only Objective-C catcher preserving exception assertions independently of Fleet's production error handling.

Restoration exposed specific compatibility and fixture issues:

- Root replacement needed to finish the previous editing session and lay out the new root. A new regression covers responder handoff and immediately usable navigation content.
- Current UIKit returns removed controllers from offscreen navigation pops. Two stale nil assertions now check returned controller identities and the remaining stack.
- The tvOS host contained obsolete Swift API names, lacked a shared notification helper in its test target, and lacked the `HomeTabBar` scene required by a shared storyboard test. These fixtures are restored.
- Focus fixtures now end editing, dismiss presented UI, and restore the borrowed root. The new handoff regression uses a text field on iOS and a real non-text responder on tvOS; interrupting tvOS system text-entry presentation caused a UIKit keyboard-layout stall. Existing tvOS text-field focus tests remain enabled. System keyboard presentation and interruption require separate coverage in M3/M4.

[GitHub Actions](../.github/workflows/test.yml) replaces Travis with separate iOS/tvOS jobs using the canonical command and retaining results even on failure. The workflow passes actionlint, and its first [remote run on PR #29](https://github.com/jwfriese/Fleet/actions/runs/37092923154) passes both suites on clean runners. [CONTRIBUTING.md](../CONTRIBUTING.md) and [AGENTS.md](../AGENTS.md) document setup, checks, repository structure, and behavioral-test expectations.

The tooling follow-up removes the superseded Ruby/fastlane setup, Xcode 12 Carthage workaround, and Go whitespace utility. The standalone storyboard metadata script now validates its build environment, preserves previous output on failure, handles quoted paths and dotted filenames, and reports missing or conflicting metadata. Ten regression checks cover copying, discovery failures, replacement recovery, and localized duplicates. Its Xcode phases declare inputs/outputs and deliberately run every build because compiled storyboard paths are discovered dynamically. The distribution policy is recorded below.

After this follow-up, `script/test all` passes 251 iOS tests and 121 tvOS tests with zero failures. All 34 Python tooling checks and actionlint pass. The first remote CI run executes both simulator suites and tooling checks successfully, and its downloaded artifacts independently confirm the same native test counts with zero failures and retained result bundles.

Phase 0 restores a usable development/test baseline. Swift 6 is completed in the follow-up below; scene hosting, lifecycle warnings, and the remaining readiness gate are still outstanding. SwiftPM distribution is implemented below; publication awaits a reviewed major release.

## Compatibility baseline

The selected policy for the next major release is iOS 15 and tvOS 15, with SwiftPM as the supported distribution route. Framework, test, host, project, package, and historical podspec deployment settings now agree on 15. The development baseline remains Xcode 26.6 and Apple Swift 6.3.3 in Swift 5 language mode; the SwiftPM manifest uses tools version 6.3. See [compatibility and distribution](Compatibility.md) for the difference between selected minimum deployment targets and verified current-runtime coverage.

CocoaPods, Carthage, and direct integration remain historical Fleet 4.x routes. Their installation documents are marked accordingly, with links to the 4.6.1 tag and the new SwiftPM setup guide. Package and consumer validation run for every pull request and full release check. The Objective-C helper definitions now have explicit `(void)` prototypes, and the collection-view fixture has a reuse identifier; their build warnings are resolved without suppressing diagnostics.

With every target set to deployment version 15.0, the full hosted suites pass 251 iOS and 121 tvOS tests with zero failures. All 34 tooling checks pass, the podspec passes Ruby syntax validation, and all 14 Xcode configurations retain Swift 5 language mode.

## SwiftPM distribution

The package builds a Swift target and an Objective-C runtime target into one dynamic `Fleet` product. Explicit imports and platform guards preserve the native project's source selection. Hosted consumers exercise the existing category activation and exception bridge without unsafe linker flags or changes to automatic runtime initialization. The package also bundles the storyboard metadata script.

`script/check-distribution` generates independent iOS/tvOS application hosts and public-API test bundles, resolves the package from Git at the checkout's exact committed revision, checks the lockfile, and executes eight tests per platform. Coverage includes control actions, navigation, presentation, alert handler dispatch, compiled storyboard resources, binding, lifecycle mocking, and hook activation. Fleet links only to the test bundles. The [installation guide](Installation/SwiftPM.md) documents the tested metadata phase and its current host-naming requirement. Plain macOS `swift test` remains unsuitable for these UIKit tests.

The original suites still pass 251 iOS and 121 tvOS tests. The tooling suite now has 41 checks, including rejection of incorrect package pins, dirty release checkouts, empty or failed consumer runs, and missing/skipped consumer CI. Logs, result bundles, lockfiles, and an exact-revision receipt are retained. A development run with `--allow-dirty` is explicitly a snapshot and cannot certify a release. CI adds a separate consumer job; publication requires that job and both native jobs to have executed successfully. No new major version has been selected or published.

After merging PRs #29–#31, the first [master run](https://github.com/jwfriese/Fleet/actions/runs/37134088395) passed tvOS and both external consumers, but iOS recorded 250 passes and one 60-second timeout in `FleetSpec.test_setAsAppWindowRoot_viewsFromIBOutletsCanBecomeFirstResponderImmediately`. The retained diagnostics show a keyboard task-queue timeout during the preceding root-handoff test, followed by an interrupted XPC connection. The iOS root-hosting fixtures now configure a local custom input view on real `UITextField` instances and assert both successful focus requests and actual first-responder state. This keeps responder readiness and root handoff covered while separating system keyboard startup/presentation from the hosting fixture. The text-input suites retain their existing editing coverage. Cold system-keyboard transitions remain work for M3/M4; timeouts remain failures, with unchanged deadlines and no retries or skipped tests.

## Swift 6 compiler migration

All 14 maintained Xcode configurations, the SwiftPM package, and the independent consumer generator now select Swift 6 language mode. UI hosting/screen APIs, storyboard state, and associated-object storage are main-actor isolated. Unused Swift swizzle flags and presentation association keys are removed. Objective-C `+load` installers remain nonisolated because they touch only runtime method tables; instance hooks retain UIKit main-thread requirements. The synchronous exception bridge preserves its caller's actor. No global concurrency suppression, unsafe Sendable conformance, or unsafe isolation annotation is added.

UI XCTest classes and helpers use `@MainActor`, with async setup/teardown. The external consumers use bounded async XCTest completion waits. Native bounded Nimble polling retains its existing synchronous form: the published Nimble 14 async expectations produce non-Sendable diagnostics in Swift 6 callers. This dependency limitation remains in M2.4; no assertion or deadline is weakened and no concurrency suppression is added to work around it. Native suites retain 251 iOS and 121 tvOS tests. Swift 6 external consumers now have nine tests per platform, adding a detached-task/main-actor hop alongside the existing control, storyboard, lifecycle, exception, presentation, and alert coverage. The tooling suite has 43 checks, including rejection of the old default branch for publication. [Compatibility](Compatibility.md) documents the caller migration. Serial execution remains required; actor isolation does not solve cross-suite test interleaving or lifecycle cleanup.

## Milestone 1 Restore reproducible development

Finish this milestone before changing runtime behavior. A working test suite will preserve the useful coverage already in [FleetTests](../FleetTests).

- [x] **M1.1 Choose and document the support matrix.** The next major release selects iOS/tvOS 15 across framework, test, host, project, package, and historical podspec settings. [Compatibility and distribution](Compatibility.md) documents Xcode 26.6, reference compiler 6.3.3, Swift 6 language mode, and package tools version 6.3. Both platforms remain in scope. Current-runtime coverage is verified on 26.5; additional runtime/toolchain combinations remain to validate. **Done when:** the published matrix and all build/distribution settings agree.

- [x] **M1.2 Restore the current tests with maintained dependencies.** Phase 0 replaces the root Carthage/Nimble 9 dependency with pinned Nimble 14 through Xcode SwiftPM. It retains real Objective-C exception assertions through an independently tested catcher, updates obsolete host APIs, and corrects current UIKit compatibility issues. **Done when:** iOS and tvOS test bundles resolve their dependencies and execute, with failures recorded and explained.

- [x] **M1.3 Establish one documented test command.** Phase 0 adds `script/test [ios|tvos|all]` and makes `./test` forward to it. The runner selects an available simulator, fails when prerequisites are missing, preserves Xcode's exit status through logging, and retains result bundles. Python regression checks cover selection and failure propagation. The obsolete fastlane lane and Ruby dependencies are removed. **Done when:** a fresh checkout can run each platform's suite using documented commands without editing machine-specific paths.

- [x] **M1.4 Replace the historical CI setup.** Phase 0 removes Travis and adds GitHub Actions jobs for both platforms on Xcode 26.6, using the canonical command and retaining logs/result bundles on failure. The workflow passes actionlint; [PR #29's first remote run](https://github.com/jwfriese/Fleet/actions/runs/37092923154) passes all 251 iOS and 121 tvOS tests with zero failures on clean runners, including tooling checks and artifact uploads. Dependency caching remains an optional optimization. **Done when:** a pull request builds and runs the baseline suites on clean runners; failed checks cannot appear successful because of log filtering or retries.

Sources: [project settings](../Fleet.xcodeproj/project.pbxproj), [podspec](../Fleet.podspec), [test runner](../script/test), [pinned dependencies](../Fleet.xcworkspace/xcshareddata/swiftpm/Package.resolved), and [GitHub Actions workflow](../.github/workflows/test.yml).

## Milestone 2 Modernize packaging and compiler support

- [x] **M2.1 Add Swift Package Manager distribution.** The tools-6.3 manifest builds separate Swift/Objective-C targets into a dynamic product, with platform guards matching the native targets. External iOS/tvOS consumers import the public module and verify category activation, dynamic mocking, the exception bridge, and retained UIKit helpers. **Done when:** an external iOS test target and an external tvOS test target can import the package and use the retained features.

- [x] **M2.2 Keep package integration tests hosted appropriately.** Pure tooling tests remain in Python; UIKit tests run in native and independent consumer application hosts. `script/check-distribution` resolves an exact Git revision and exercises packaged storyboard metadata, compiled fixtures, and runtime initialization on both simulators. The original host suites remain intact. **Done when:** the canonical commands run the relevant tests on Apple platform simulators, and an external consumer verifies the package's resources and runtime initialization.

- [x] **M2.3 Complete the Swift 6 migration.** Native and package targets select Swift 6, UI state is main-actor isolated, unused keys/flags are removed, and nonisolated Objective-C installers and synchronous closure bridging have explicit invariants. Both platforms retain hosted native and public-API consumer coverage, including a detached-task actor hop. **Done when:** library and test targets compile in the selected Swift 6 configuration, and Swift 6 consumer tests pass without disabling concurrency checking globally.

- [ ] **M2.4 Update the remaining build infrastructure.** The obsolete Xcode 12 architecture workaround and Ruby/fastlane tooling are removed. Storyboard phases declare inputs/outputs and deliberately run every build to follow host resource changes. Explicit Objective-C `(void)` prototypes and the collection-view fixture reuse identifier resolve their warnings. Remaining warnings include deprecated UIKit APIs and synchronous Nimble polling. Nimble 14 async expectations still produce non-Sendable diagnostics in Swift 6 callers; migrate those waits when the dependency supports the required isolation, or introduce a separately tested bounded-wait replacement. Track UIKit warnings alongside M3/M4. Absolute `/usr/local/bin/carthage` paths are confined to instructions explicitly marked as historical 4.x routes. **Done when:** the selected builds run on Apple silicon and report no unexplained project warnings.

- [x] **M2.5 Decide the legacy distribution policy.** SwiftPM is the supported route for the next major release; CocoaPods, Carthage, and direct integration remain historical 4.x routes. [Compatibility and distribution](Compatibility.md), the tested [SwiftPM setup](Installation/SwiftPM.md), historical installation docs, and release checks cover that transition. **Done when:** installation docs and release checks cover the promised routes, and deprecated routes have clear migration instructions.

Sources: [Objective-C bridge](../Fleet/ObjC), [runtime categories](../Fleet/CoreExtensions), [metadata copy script](../Fleet/Script/copy_storyboard_info_files.sh), and [installation instructions](Installation/iOS.md). SwiftPM provides package and module configuration through its [package manifest API](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html).

## Milestone 3 Make hosting and runtime behavior predictable

Settle public API changes together so users receive one coherent migration. Prefer a small explicit testing context that owns resources and cleanup. Exact type and method names remain design decisions.

- [ ] **M3.1 Introduce Swift error reporting.** Ordinary helper failures currently raise `NSException`, even where documentation describes throwing Swift errors. Introduce typed Swift errors with enough context to diagnose the failed action, and define migration from `FleetError` and `swallowAnyErrors`. Add optional test-framework reporting adapters only where they improve source-location reporting. **Done when:** an invalid action is assertable in XCTest and Swift Testing, identifies the relevant control/state, and does not crash the test process.

- [ ] **M3.2 Provide explicit window and scene hosting.** Replace reliance on the application's global key window with a context that accepts a known window or scene and can own a test window. Support both scene-based hosts and any older lifecycle retained by M1.1. Missing host/window state should produce a useful failure. **Done when:** view loading, layout, presentation, and first-responder tests work in the documented host configurations. Apple's application-wide [`keyWindow` property is deprecated](https://developer.apple.com/documentation/uikit/uiapplication/keywindow).

- [ ] **M3.3 Replace implicit run-loop progress with bounded waits.** Current root setup runs the default run loop until a date one second in the future; that establishes no particular lifecycle completion. Add async waits for observable conditions and transition completion, with deadlines and cancellation. Avoid claiming that a general wait can flush all application work. **Done when:** presentation and responder tests wait for the state they assert, fail helpfully on timeout, and do not depend on arbitrary sleeps.

- [ ] **M3.4 Guarantee cleanup after success and failure.** Release owned windows/controllers, resign responders, restore borrowed host state, clear bindings, and remove test observers. Audit existing fixtures that make windows key or add views without consistently restoring state. **Done when:** repeated tests leave no retained test controllers or altered host state, including when an action throws or a wait is cancelled.

- [ ] **M3.5 Coordinate shared application UI state.** `@MainActor` protects execution on the actor but does not prevent different async tests from interleaving. Serialize the entire lifetime of tests sharing key-window, responder, or process-wide runtime state, while allowing independently safe tests to run concurrently. A suite's `.serialized` trait does not coordinate unrelated suites. **Done when:** XCTest and Swift Testing consumers have a tested isolation policy and overlapping attempts cannot corrupt one another's environment. See [Apple's Swift Testing discussion of serialization](https://developer.apple.com/videos/play/wwdc2024/10195/).

- [ ] **M3.6 Make runtime hooks deliberate and verifiable.** Objective-C `+load` categories currently install hooks when the library loads. Inventory every hook, its supported selectors, and whether it observes or changes behavior. Prefer public UIKit APIs where they meet the requirement; provide explicit installation/configuration for retained hooks and test installation exactly once. Treat hooks as process-wide: changing or restoring them during overlapping tests is unsafe. **Done when:** activation, compatibility failures, and process-wide effects are documented and tested, with a migration path for existing automatic activation.

- [ ] **M3.7 Scope storyboard bindings and resource discovery.** The global binding map retains controllers and has no public cleanup path. Storyboard deserialization selects the first `.xctest` bundle, reads copied compiler metadata, and uses KVC to discover the storyboard name. Give bindings a defined owner/lifetime and accept explicit storyboard/bundle information where possible. The copy script is hardened with quoted paths, required-variable validation, failure propagation, staged replacement/recovery, and actionable diagnostics; conflicting metadata under the same storyboard name fails instead of silently overwriting. Regression checks cover this tooling, including identical localized copies. **Done when:** external references, duplicate storyboard names across bundles, multiple test bundles, missing metadata, and cleanup have coverage on the supported matrix.

- [ ] **M3.8 Define the limits of controller mocking.** Runtime mocks suppress lifecycle overrides but still instantiate a subclass of the production class; this does not guarantee isolation from initialization side effects. Review behavior for required initializers, unsupported controller types, and storyboard `prepare(for:)` interactions. Offer explicit replacement controllers or factories where appropriate. **Done when:** supported mocking behavior and failure cases are tested and documented without promising isolation the implementation cannot provide.

Sources: [errors](../Fleet/Error), [root/window setup](../Fleet/Fleet.swift), [view-controller hooks](../Fleet/CoreExtensions/ViewController), [storyboard binding](../Fleet/CoreExtensions/Storyboard/UIStoryboard+Fleet.swift), [deserialization](../Fleet/CoreExtensions/Storyboard/StoryboardDeserializer.swift), [metadata copy script](../Fleet/Script/copy_storyboard_info_files.sh), and [mock implementation](../Fleet/ObjC/FleetObjC.m).

## Milestone 4 Verify and repair retained interaction semantics

Give each helper a clear behavioral contract. Use regression tests for source-level defects and a small set of instrumented XCUIAutomation scenarios to compare important callback traces with actual UIKit interactions. Resolve mismatches in the helper or narrow its documented guarantee. These comparisons should cover a representative set of interactions rather than duplicate the entire unit suite.

- [ ] **M4.1 Repair navigation behavior.** `fleet_pushViewController` replaces a push with `setViewControllers`, and `fleet_popViewControllerAnimated` unconditionally removes the last element. Compare their lifecycle/delegate behavior with UIKit; cover empty/root-only stacks, repeated pushes, and completion ordering. Prefer forwarding to UIKit with the selected animation policy where possible. **Done when:** retained navigation behavior has explicit guarantees and tests for these boundaries.

- [ ] **M4.2 Define screen traversal consistently.** `Screen` does not descend into selected tab controllers, and its navigation branch stops after one presented controller. Existing tab tests expect a container, so changing traversal requires an intentional API decision. Cover nested presentations, navigation/tab combinations, and split/custom containers within the supported scope. **Done when:** container access and visible content access are unambiguous and tested.

- [ ] **M4.3 Harden indices and table selection.** Table selection/edit-action helpers check upper bounds but omit negative-index checks; tab selection also omits its negative check. Audit redirected delegate index paths. Verify selection refusal, reselection, deselection when optional delegate methods are absent, multi-selection, editing rules, callback order, and notification contents. **Done when:** invalid inputs fail predictably and the documented selection model agrees with observed UIKit behavior.

- [ ] **M4.4 Clarify cell retrieval.** `fetchCell` asks the data source to create a cell rather than retrieving the displayed cell, which can produce a different instance. Define whether Fleet offers configured-cell inspection, displayed-cell inspection, or separate APIs for both. **Done when:** reuse, visible/offscreen rows, and applicable diffable-data-source behavior are tested, and the distinction is clear to consumers.

- [ ] **M4.5 Correct text ranges and editing flows.** Text helpers construct `NSRange` from Swift character counts and assume edits at the end, although `insertText`/`deleteBackward` operate on the selection. Cover UTF-16 ranges, emoji, combining characters, selected ranges, delegate rejection, and empty text. Check for duplicate delegate calls when Fleet manually invokes callbacks around UIKit methods. **Done when:** supported typing/paste/deletion semantics match the contract, and `enter(text:)` stops appropriately when editing is refused or fails.

- [ ] **M4.6 Audit keyboard notifications and focus changes.** Fleet posts keyboard notifications itself without user info; UIKit may also produce notifications. Establish what the helper promises about focus and keyboard events, including software versus hardware keyboard conditions. Remove misleading or duplicate synthesis, or expose an explicitly separate notification simulation facility. **Done when:** focused tests verify the chosen behavior and no claim suggests these helpers prove actual keyboard presentation or layout.

- [ ] **M4.7 Modernize control and bar-button dispatch.** Cover modern primary-action registrations alongside retained target/action behavior, avoiding duplicate invocation. The current bar-button helper requires a non-nil target and calls `perform`; evaluate responder-chain dispatch through public UIKit APIs. Define behavior for menu-backed items and duplicate text labels. **Done when:** supported actions execute exactly once, unavailable controls fail clearly, and unsupported interactions have explicit diagnostics.

- [ ] **M4.8 Verify alerts and legacy row actions.** Alert handler capture hooks the private `setHandler:` selector; row-action handler capture also depends on runtime interception. Cover disabled/nil-handler actions, duplicate titles, dismissal ordering, and missing presentation. Decide whether deprecated row-action support stays in a compatibility module or is retired with migration guidance. **Done when:** retained features pass compatibility checks or fail clearly on unsupported configurations; legacy behavior is never silently assumed to work.

Sources: [navigation implementation](../Fleet/CoreExtensions/UINavigationController+Fleet.swift), [screen traversal](../Fleet/Screen/Screen.swift), [table helpers](../Fleet/CoreExtensions/TableView), [tab selection](../Fleet/CoreExtensions/Navigation/TabBar/UITabBarController+Fleet.swift), [text helpers](../Fleet/CoreExtensions/Controls/TextInput), [bar-button dispatch](../Fleet/CoreExtensions/UIBarButtonItem+Fleet.swift), and [alert hooks](../Fleet/CoreExtensions/Alerts). Modern control dispatch is described by [Apple's `sendActions(for:)` documentation](https://developer.apple.com/documentation/uikit/uicontrol/sendactions(for:)).

## Milestone 5 Establish the regular development workflow

- [ ] **M5.1 Verify both XCTest and Swift Testing consumers.** Preserve the existing XCTest suite. Add representative Swift Testing consumer tests covering hosting, a control action, asynchronous presentation, failure reporting, and cleanup. Keep core behavior independent of a particular assertion framework. **Done when:** both consumers pass through the distributed package with the documented isolation rules; wholesale rewriting of the existing suite is unnecessary.

- [ ] **M5.2 Check repeatability and retain useful evidence.** Run repeated representative UI tests and vary order where supported. Investigate dependencies on windows, observers, responders, bindings, and runtime hooks. Record a baseline for suite duration and separate build time from execution time. **Done when:** agreed repetitions pass without retrying away failures, and CI retains enough evidence to diagnose a regression.

- [ ] **M5.3 Update the working example against the local library.** The example pins Fleet 3.0.0 and old Quick/Nimble revisions, uses obsolete Swift syntax, and contains XCTest examples that still depend on Nimble despite being described as XCTest-only. Use the local package while developing; make examples exercise the public API, including a plain XCTest path and a Swift Testing path. **Done when:** the example builds and its tests run in CI against the current checkout.

- [ ] **M5.4 Reconcile all public documentation.** Fix old API names, `try!` on nonthrowing calls, malformed examples, inconsistent error descriptions, and installation paths. `UIViewController.md` promises immediate completion while the FAQ acknowledges waiting for the UI thread; resolve that contradiction with the verified contract. Document host requirements, cleanup, compatibility, and the limits of simulated interaction. **Done when:** the quick start works from a fresh consumer project and substantive examples are compiled or exercised by maintained fixtures.

- [ ] **M5.5 Update contributor and agent guidance.** Document setup, canonical checks, repository structure, regression-test expectations, platform exclusions, and rules for changing UIKit simulation semantics. Provide short issue/PR templates and a focused `AGENTS.md` if useful for ongoing agent work. **Done when:** a contributor can add a small helper and know which tests/docs/checks to update without reconstructing the old toolchain.

- [ ] **M5.6 Modernize release preparation.** Release tooling is now pulled forward: `script/release prepare` leaves a version/changelog diff for review, `check` validates a clean committed revision including real external consumers, and `publish` verifies that revision and all three CI jobs before pushing only its release tag and creating GitHub release notes. The old Go/CocoaPods publisher is removed. Regression tests cover failure handling and publication recovery; a read-only GitHub Actions workflow runs release validation. Packaging is implemented, but a full check for the selected, prepared major version and reviewed migration notes remains to complete. The existing 4.6.1 tag must not be reused for these changes. **Done when:** release preparation is reviewable and repeatable, and every advertised distribution route resolves the same validated revision.

Sources: [example dependencies](../Examples/FleetExamples/Cartfile), [example tests](../Examples/FleetExamples/FleetExamplesTests), [presentation docs](UIViewController.md), [FAQ](FAQ.md), [contribution guide](../CONTRIBUTING.md), [release commands](../script/release.py), and [release guide](Releasing.md). Swift Testing can run alongside XCTest and runs tests in parallel by default; see its [official repository](https://github.com/swiftlang/swift-testing).

## Gate for resuming regular feature development

Resume regular feature work when these conditions hold. An experimental integration with an unsupported UIKit feature does not need to hold up the release; its unsupported status must be explicit.

- [x] A fresh checkout has a documented setup and test command, and CI runs the selected iOS/tvOS matrix.
- [x] The package works in external test targets, including hosted resources and retained runtime features.
- [ ] The chosen Swift 6 configuration passes, and shared UI state has a tested isolation policy.
- [ ] Retained APIs have clear error, lifecycle, cleanup, and interaction contracts, with known defects resolved or explicitly deprecated.
- [ ] Existing tests and representative consumer tests pass repeatedly without unexplained failures.
- [ ] The example, quick start, contributor instructions, and migration guide match the tested release.
- [ ] Release preparation validates the same revision that will be distributed.

## Expansion after the modernization gate

These are candidates for later feature development. Their scope and order should follow user demand and the cost of maintaining their UIKit contracts.

- [ ] **Collection views and modern lists.** Selection, deselection, supplementary views, and diffable updates using the same contract discipline as table views.
- [ ] **Modern swipe actions and menus.** Add supported contextual-action and menu interaction APIs after deciding the legacy row-action policy.
- [ ] **SwiftUI hosting and mixed screens.** Begin with hosting and UIKit/SwiftUI boundaries; investigate integrations with existing inspection and snapshot tools before attempting broad interaction coverage.
- [ ] **Configurable screen environments.** Size, traits, Dynamic Type, appearance, and localization, with snapshot integrations where they help verify output.
- [ ] **Better diagnostics for humans and agents.** Structured action traces, relevant hierarchy/state attachments, and focused test execution. Extend the established command-line test workflow as concrete needs emerge.

Phase 0, the support-matrix decision, SwiftPM packaging, and the Swift 6 compiler migration are complete. Next use the hosted coverage to modernize runtime and interaction contracts. Each slice can merge after maintainer approval and passing CI on protected `main`; the full readiness gate governs resuming feature development and publishing the modernized major release.
