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

Use full Xcode with the iOS and/or tvOS platform and simulator runtime installed. Phase 0 is verified with Xcode 26.6 and the 26.5 simulator SDKs/runtimes. The project uses Swift 5 language mode. Python 3 is required for simulator selection and runner checks.

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
- Pull requests into `main` require maintainer approval and passing iOS, tvOS,
  and external SwiftPM consumer checks. `.github/CODEOWNERS` assigns review to
  `@jwfriese`; authors cannot approve their own pull requests.
- The `main` branch will always support the stable Xcode version. Other
  branches will point to their corresponding versions they support.

## Releases

Use `script/release prepare VERSION` to create a reviewable version/changelog diff, then `script/release check VERSION` on the committed revision. Publication is a separate `script/release publish VERSION` command; `--dry-run` prints its local plan. See [Releasing Fleet](Documentation/Releasing.md) for prerequisites and recovery steps. Publication requires native tests and real external SwiftPM consumers passing on that exact revision, along with finished release notes and successful CI.
