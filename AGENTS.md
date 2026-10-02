# Working on Fleet

Fleet is a UIKit testing library for iOS and tvOS. It helps hosted unit tests exercise real controls, view controllers, navigation, and storyboards. Preserve those behavioral contracts while modernizing the implementation.

## Build and test

- The Phase 0 reference environment is Xcode 26.6 (Apple Swift 6.3.3), with iOS/tvOS 26.5 simulator SDKs and runtimes. The project still uses Swift 5 language mode; a full Swift 6 migration is separate work.
- Use full Xcode, not only standalone Command Line Tools. Set `DEVELOPER_DIR` to another Xcode installation if needed. Install missing platforms/runtimes through Xcode Settings > Components or `xcodebuild -downloadPlatform iOS` / `xcodebuild -downloadPlatform tvOS`.
- Run `script/test` for the complete iOS suite, `script/test tvos` for tvOS, or `script/test all` for both. The root `./test` forwards to this runner.
- Narrow a development run with `script/test ios -only-testing:FleetTests/ClassName/test_method`. Run the complete affected platform suite before reporting completion; run both platforms for changes shared by both when their SDKs/runtimes are available.
- Set `FLEET_TEST_DESTINATION` to an explicit `xcodebuild` destination if automatic selection is unsuitable. Use that override with one platform at a time. `FLEET_BUILD_DIR` overrides the default `build/` output directory.
- Run `python3 -m unittest discover -s script/tests -v` for test-runner or release-tooling changes. Check shell syntax with `bash -n script/test script/release test` and check whitespace with `git diff --check`.
- The first test run needs network access to fetch packages. Xcode resolves pinned Nimble dependencies from `Fleet.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Commit intentional dependency changes together with that lockfile.
- Test hosts and test targets require iOS/tvOS 13 for Nimble. Phase 0 does not settle the library's public deployment/support matrix; see `Documentation/Modernization.md`.
- Test runs execute serially because Fleet modifies application UI state and installs process-wide runtime hooks. Do not enable parallel execution until that shared state is isolated.
- The runner enables XCTest timeouts (30 seconds per test by default, maximum 60). A timeout is a failure; diagnose its result bundle instead of retrying it away.
- Each run writes `xcodebuild.log` and `TestResults.xcresult` into a unique directory under `build/`. Report test counts and failures; a successful framework build alone is not a passing test suite. Preserve failures instead of adding retries or silently skipping tests.

The canonical test path needs neither Ruby/fastlane nor Carthage. Historical tooling and the separate example's Carthage setup are not the canonical development workflow. Plain macOS `swift test` cannot run Fleet's UIKit suite.

## Repository structure

- `Fleet/`: production library. `CoreExtensions/` provides UIKit interactions; `Screen/` inspects controllers; `Mocking/` and `ObjC/` implement runtime mocking and bridging.
- `FleetTests/`: XCTest specifications and test helpers. Nimble comes from SwiftPM; `Helpers/ExceptionCatcher.*` and `RaiseExceptionMatcher.swift` preserve exception assertions independently of Fleet's production catcher.
- `FleetTestApp/` and `FleetTestApp-tvOS/`: applications hosting the test bundles and storyboard fixtures. `TestAppCommon/` contains shared controllers.
- `Fleet.xcodeproj` / `Fleet.xcworkspace`: shared iOS `Fleet` and tvOS `Fleet-tvOS` schemes. Add new shared source/test files to both applicable targets; use platform guards for APIs unavailable on tvOS.
- `Fleet/Script/copy_storyboard_info_files.sh`: extracts compiled storyboard metadata required for binding tests. Keep it connected to the test targets.
- `script/test`, `script/select-simulator.py`, and `script/tests/`: canonical test runner, simulator selection, and tooling regression checks.
- `.github/workflows/test.yml`: GitHub Actions runs both platform suites through the same command and retains their results.
- `script/release` and `script/release.py`: separate preparation, validation, and publication commands. `.github/workflows/release.yml` runs full release validation manually with read-only permissions. `Documentation/Releasing.md` describes prerequisites and recovery.
- `Documentation/`, `README.md`, and `CONTRIBUTING.md`: public API documentation, setup, and contribution instructions. `Documentation/Modernization.md` tracks remaining modernization.
- `Examples/FleetExamples/`: a historical consumer example with its own dependencies. Its migration is still pending; the canonical suite does not build it.

## Making changes

For behavior changes, first add or identify a failing regression test, then make the smallest implementation change that satisfies it. Preserve existing coverage. If an old expectation conflicts with current UIKit, establish the actual behavior and document why the expectation changes. Never weaken an assertion solely to make CI green.

UIKit interaction helpers must account for relevant delegate/control events and unavailable controls. An action dispatched programmatically does not prove physical hit testing, accessibility, or actual keyboard presentation. Document the exact supported behavior.

Presentation, lifecycle, and focus can complete asynchronously. Wait for the state being asserted with bounded waits; avoid arbitrary sleeps. Keep windows, first responders, observers, and storyboard bindings from leaking between tests.

Fleet currently installs Objective-C swizzles in `+load`. Changes to selectors, initialization, static/dynamic linking, or mocking need hosted integration coverage. Keep any unsafe runtime assumptions explicit and avoid unrelated API redesign during build-tool changes.

Keep public API docs and platform exclusions in sync with changes. Do not add generated build output, simulator identifiers, or machine-specific paths to the repository.

Release preparation requires a clean checkout and leaves an unstaged diff for review; do not commit unrelated work to satisfy it. Full release checks also require validated packaging and external consumers. `check --tests-only` cannot produce publication evidence. Never bypass the packaging gate with an empty or always-successful checker.

Run publication only when the user explicitly requests publishing the selected version. `script/release publish` writes a Git tag and GitHub release; it is not a validation command. Use `--dry-run` for its local plan. The old Go publisher is removed. Preserve conflicting or partially published tags rather than moving/deleting them to get a command to pass.
