## Reporting Bugs

Nothing is off-limits. If you're having a problem, we want to hear about
it.

- See a crash? File an issue!
- Code isn't compiling, but you don't know why? File an issue!

Be sure to include in your issue:

- Your Xcode version (eg - Xcode 7.0.1 7A1001)
- Your version of Fleet (eg - v0.7.0 or git sha `7d0b8c21357839a8c5228863b77faecf709254a9`)
- What are the steps to reproduce this issue?
- What platform are you using? (Fleet supports iOS and tvOS as of now)
- Are you using git submodules, Carthage, or Cocoapods to install Fleet?

## Building the Project

Use full Xcode with the iOS and/or tvOS platform and simulator runtime installed. Phase 0 is verified with Xcode 26.6 and the 26.5 simulator SDKs/runtimes. All maintained targets and the SwiftPM package use Swift 6 language mode. UI specifications use `@MainActor` and async XCTest setup/teardown; use bounded waits and keep execution serial. Native Nimble 14 polling remains synchronous pending dependency concurrency support. Python 3 is required for simulator selection and runner checks.

The next major release sets all framework, test, and host deployment targets to iOS/tvOS 15 and uses SwiftPM for distribution. See [compatibility and distribution](Documentation/Compatibility.md) and [SwiftPM setup](Documentation/Installation/SwiftPM.md) for the transition from historical 4.x installation routes.

Open `Fleet.xcworkspace` to work on Fleet. Xcode resolves the pinned Nimble test dependency through Swift Package Manager; the first run requires network access. Ruby, fastlane, and Carthage are not required for the canonical suite. The test targets run inside the included host applications.

Run the tests from the repository root:

```sh
script/test          # iOS
script/test tvos     # tvOS
script/test all      # Both, sequentially
```

The runner selects an available simulator compatible with the selected Xcode SDK, preferring the latest runtime and a booted device. To choose a destination explicitly:

```sh
FLEET_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.5' script/test
```

Use `DEVELOPER_DIR` to select another Xcode installation. Install missing components through Xcode Settings > Components or `xcodebuild -downloadPlatform iOS` / `xcodebuild -downloadPlatform tvOS`. Missing platforms fail the command instead of silently skipping a suite.

To run one test class during development, use `script/test ios -only-testing:FleetTests/FleetSpec`. Run the complete affected platform suite before submitting. Shared changes should pass both platform suites.

Logs and result bundles are retained in unique run directories under `build/`; open a `TestResults.xcresult` bundle in Xcode to inspect failures. `FLEET_BUILD_DIR` changes the output directory. Tests run serially because Fleet shares application UI state, with XCTest timeouts enabled (30 seconds per test by default, maximum 60). The root `./test` command remains a compatibility wrapper.

### Test reliability

**Lifetime assertions.** Use `WeakProbe`, `lifetimeScope`, and `assertReleased` from `FleetTests/Helpers/Test.swift`. A synchronous test runs its whole body (creating objects, calling Fleet, identity checks) inside one `lifetimeScope`, returns only `WeakProbe`s, then calls `assertReleased` after the scope ends. This is required, not stylistic: the retention failures seen in CI were not a Fleet owner. Fleet's retain count is balanced (bind retains once, removal releases), and a `leaks --traceTree` trace of a failing fresh-process run showed the remaining holders were the test's stack and an entry in the test method's *outer* autorelease pool, added between smaller inner scopes. Anything autoreleased outside an inner pool lands there and lives until the test method returns. `assertReleased` drains pools and polls to a bounded deadline, so a genuinely retained object still fails. Do not hold an autorelease pool across an `await`; scope async work in synchronous helpers.

**Hosted UI fixtures.** Tests that touch the application window use `HostedUIFixture` (same file): create it in `setUp`, make windows with `makeKeyWindow(root:)` or `adopt(_:)`, attach views with `embed(_:)`, and `await fixture.restore()` in `tearDown`. Restoration ends editing, dismisses presentations (bounded wait, failing at the deadline), detaches embedded views, hides owned windows, then returns the borrowed window's root and key status. Drop fixture properties (delegates, data sources, subjects) after detaching views. `HostedUIFixtureSpec` proves a successor starts from the original state after both normal and throwing paths. Coordinate asynchronous work with explicit signals or bounded state waits that call `XCTFail` with the trace at their deadline; never use a sleep to establish readiness.

**Reliability runs (opt-in).** Repeating tests is the evidence for flakiness work; retrying until success is not. Run each class in both modes, then the whole suite, and record the source revision (`git rev-parse HEAD`), `xcodebuild -version`, simulator, mode, counts, failures, and the `build/` result-bundle path. Keep failures; do not retry them away.

```bash
# Process reuse, then fresh process per iteration (separates accumulated state from cold-start behavior)
script/test ios  -only-testing:FleetTests/UIStoryboard_FleetSpec -test-iterations 20 -run-tests-until-failure -test-repetition-relaunch-enabled NO
script/test ios  -only-testing:FleetTests/UIStoryboard_FleetSpec -test-iterations 20 -run-tests-until-failure -test-repetition-relaunch-enabled YES
script/test tvos -only-testing:Fleet-tvOSTests/UIStoryboard_FleetSpec -test-iterations 20 -run-tests-until-failure -test-repetition-relaunch-enabled NO
script/test tvos -only-testing:Fleet-tvOSTests/UIStoryboard_FleetSpec -test-iterations 20 -run-tests-until-failure -test-repetition-relaunch-enabled YES

# Order variation: xcodebuild always runs a class alphabetically, so vary the neighbors instead.
# Each test alone in a fresh process (the "first test in the process" case), then the class with its
# surrounding suites (the other hosted fixture suites run before and after it).
for t in $(grep -o 'func test_[A-Za-z0-9_]*' FleetTests/CoreExtensions/Storyboard/UIStoryboard+FleetSpec.swift | sed 's/func //'); do
  script/test ios -only-testing:FleetTests/UIStoryboard_FleetSpec/$t -test-iterations 5 -run-tests-until-failure -test-repetition-relaunch-enabled YES || break
done
script/test ios -only-testing:FleetTests/UIStoryboard_FleetSpec -only-testing:FleetTests/UINavigationController_FleetSpec -only-testing:FleetTests/ScreenSpec -only-testing:FleetTests/UIAlertController_FleetSpec -only-testing:FleetTests/UITextField_FleetSpec -test-iterations 10 -run-tests-until-failure -test-repetition-relaunch-enabled NO

# Final-revision evidence: three consecutive complete suites per platform on the unchanged commit
for i in 1 2 3; do script/test all || break; done
```

For runner, release, packaging-checker, or storyboard-script changes, also run `python3 -m unittest discover -s script/tests -v` and `bash -n script/test script/release script/check-distribution test Fleet/Script/copy_storyboard_info_files.sh Integration/PackageConsumer/CopyStoryboardMetadata.sh`. Packaging and runtime-linking changes must pass `script/check-distribution` for both external hosted consumers on a clean committed revision. Use `script/check-distribution --allow-dirty` before committing for development; that run creates a separate Git snapshot and is not release evidence. GitHub Actions runs the tooling, native suites, and committed consumer checks. See [AGENTS.md](AGENTS.md) for repository structure and guidance for agent work.

## Pull Requests

- Nothing is trivial. Submit pull requests for anything: typos,
  whitespace, you name it.
- We take testing _very seriously_. Please make sure that any PR you make includes
a complete addition to the test suite to capture the new behavior.
- Not all pull requests will be merged, but all will be acknowledged quickly.
- Make sure your pull request includes any necessary updates to the
  README or other documentation.
- Please make sure to run the unit tests before submitting a PR using `script/test all`.
- For non-admin contributors, pull requests into `main` require maintainer approval and passing iOS, tvOS,
  and external SwiftPM consumer checks. `.github/CODEOWNERS` assigns review to
  `@jwfriese`; authors cannot approve their own pull requests.
- The owner/admin exception allows the maintainer to merge their own PRs after
  the same checks pass. Automation uses a separate machine account with write
  access and no admin privileges, so its PRs still require maintainer approval.
- The `main` branch will always support the stable Xcode version. Other
  branches will point to their corresponding versions they support.

## Releases

Use `script/release prepare VERSION` to create a reviewable version/changelog diff, then `script/release check VERSION` on the committed revision. Publication is a separate `script/release publish VERSION` command; `--dry-run` prints its local plan. See [Releasing Fleet](Documentation/Releasing.md) for prerequisites and recovery steps. Publication requires native tests and real external SwiftPM consumers passing on that exact revision, along with finished release notes and successful CI.
