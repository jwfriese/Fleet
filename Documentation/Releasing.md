# Releasing Fleet

Fleet releases use three separate commands: prepare a diff, validate a committed revision, and publish that revision. The commands require Python 3.9 or newer and Git. Simulator validation also needs the Xcode environment described in [CONTRIBUTING.md](../CONTRIBUTING.md). Publication requires an authenticated GitHub CLI with access to the destination repository.

## Current readiness

Release tooling is available, but publication remains blocked until Fleet has a `Package.swift` and an executable `script/check-distribution` that verifies external iOS and tvOS consumers. These files are intentionally absent while packaging is being modernized. The existing framework tests and Nimble's SwiftPM dependency do not establish that Fleet can be distributed through SwiftPM.

The [compatibility policy](Compatibility.md) selects iOS/tvOS 15 and SwiftPM for the next major release. CocoaPods, Carthage, and direct integration remain historical 4.x routes. CocoaPods trunk publication is not part of this workflow; the old Go publisher has been removed. The podspec's version and platform settings are still maintained so repository metadata stays consistent. Finish SwiftPM packaging, external consumer validation, and installation instructions before publication.

## Prepare

Start from a clean checkout with the development changes already committed. Select the next version deliberately; the examples below use `5.0.0` as an illustration, not a selected release.

```sh
script/release prepare 5.0.0
git diff
git status --short
```

Preparation accepts stable `X.Y.Z` versions, using the repository's existing tag convention without a `v` prefix. Prerelease identifiers are not yet supported. It rejects conflicting metadata, existing tags, versions that do not increase, and staged, unstaged, or untracked work.

The command updates `CURRENT_PROJECT_VERSION`, Fleet's plist version, the podspec version, and a new changelog entry. It preserves unrelated version strings. It does not stage, commit, tag, push, or publish anything. Complete the changelog's draft text with compatibility requirements and migration steps, then review and commit those changes through the normal review process.

## Check the committed release

```sh
script/release check 5.0.0
```

Full validation requires a clean committed checkout, matching version metadata, finished release notes, and the packaging prerequisites. It runs the Python tooling checks, `script/test all`, and `script/check-distribution`, in that order. Both platform suites must report successful execution of at least one test. Any failing command fails the check; there are no automatic retries.

The distribution checker must build and execute external test hosts on both platforms, consuming Fleet through SwiftPM from the checked-out revision. It must exercise linking/runtime initialization, a real control action, navigation, and storyboard resources/binding through the public API. Include support-matrix and resource checks needed for every advertised installation route. Manifest resolution or a successful framework build alone is insufficient. The checker returns nonzero if either consumer fails and preserves its simulator result bundles.

A successful check records the exact Git commit, version, test counts, and completed distribution check in `build/releases/VERSION/validation.json`. Its combined log is adjacent to the receipt; the canonical runner also keeps each platform's logs and result bundles. A new check invalidates prior full-validation evidence before it starts. Changes to HEAD or tracked files during validation fail the check.

While packaging is pending, repository validation is available separately:

```sh
script/release check 5.0.0 --tests-only
```

This still runs both platform suites on a clean committed checkout. It writes `repository-validation.json`, which the publisher will not accept. It also invalidates any earlier full-validation receipt for that version.

The manually dispatched [Release validation workflow](../.github/workflows/release.yml) performs the full check on the selected committed ref and uploads its evidence and simulator results. It has read-only repository permissions and does not publish. Until packaging is ready, this workflow fails with the packaging diagnostic. A downloaded full-validation receipt can be placed at the same local path for publication, provided it belongs to the identical commit; treat it as trusted build evidence, not as a credential.

## Publish

Merge and push the reviewed release changes to `master`, and wait for the [Tests workflow](../.github/workflows/test.yml) to pass for that exact commit. Check out that revision locally on `master`, and obtain a successful full-validation receipt.

Review the local publication plan:

```sh
script/release publish 5.0.0 --dry-run
```

Dry run enforces the local version, cleanliness, packaging, branch, and receipt requirements. It prints the selected commit and destination without making network requests or mutations. Online branch, tag, and CI checks happen during actual publication.

When deliberately publishing the reviewed release:

```sh
script/release publish 5.0.0
```

Use `--remote NAME` to choose a remote other than `origin`. The remote must have exactly one GitHub push URL. The publisher checks that destination's `master` commit, release tags, and latest applicable Tests workflow run. Both platform jobs and their simulator test steps must have executed successfully; an older successful run cannot override a newer failed or pending run.

Publication creates an annotated tag at the validated commit, pushes only that tag, and creates a GitHub release from the reviewed changelog. It does not push branches, unrelated tags, or a CocoaPods specification. Conflicting local or remote tags fail without being moved or deleted. GitHub release creation uses `--verify-tag` to prevent implicit tagging of a different revision.

If a tag push succeeds but release creation fails, the command exits nonzero. Preserve the tag and retry the same version/commit after resolving the failure. A matching tag is reused; an existing published release is left intact. An existing draft requires review on GitHub. Publication never deletes public state to recover from a partial failure.

## Maintaining the tooling

```sh
python3 -m unittest discover -s script/tests -v
bash -n script/test script/release test Fleet/Script/copy_storyboard_info_files.sh
git diff --check
```

Release regression tests use temporary Git repositories and simulated publication responses. They verify preparation, failure propagation, exact revision checks, packaging gates, CI requirements, targeted pushes, and recovery without publishing anything. Actual SwiftPM consumer coverage is the separate packaging prerequisite.
