# Readiness reports for an exact revision

A readiness report tells a maintainer what one committed revision has and has not validated. It uses the existing commands and CI; it adds no tooling. A report describes a single full commit hash and is invalid for any other, including a later commit that only edits documentation. Because a committed file cannot name its own hash, the report is produced after the commit and kept with the retained evidence under `build/` (and with the CI artifacts), not committed to the tree.

## How to produce one

On a clean checkout of the candidate commit (`git status --short` empty, `git rev-parse HEAD` recorded):

1. `script/test all` — native iOS and tvOS suites. Each run writes `xcodebuild.log` and `TestResults.xcresult` in a unique `build/` directory.
2. `python3 -m unittest discover -s script/tests -v` and the syntax checks listed in [AGENTS.md](../AGENTS.md), plus `git diff --check`.
3. `script/check-distribution` — external consumers, which write `validation.json`, lockfiles and result bundles under `build/distribution-*`.
4. Link the CI runs for the same commit: the Tests workflow jobs (iOS, tvOS, consumers) and their uploaded artifacts.

Record, from the logs rather than from memory: test counts and failures per suite, with the build step distinguished from test execution (a successful build is not a pass; consumers report "Executed N tests"). If a check was not run, or ran on a development snapshot (`--allow-dirty`), say so.

## Report contents

- **Revision**: full commit hash and whether the tree was clean.
- **Toolchain and runtimes**: Xcode build, Swift version, simulator runtimes actually used, and the deployment targets, kept distinct (see [Migration](Migration.md#deployment-targets-versus-verified-runtimes)).
- **Completed checks**: command, platform, tests executed, failures, result-bundle and log locations or CI links.
- **Not validated**: runtimes other than those listed, unavailable platforms, checks skipped, and the limits in [Compatibility](Compatibility.md).
- **Outstanding publication requirements**: a deliberately selected version, finished release notes and migration notes, `script/release check VERSION` (full, with consumers) on the committed release revision, passing CI for it, and a separate explicit request to run `script/release publish`.

## What is not publication evidence

`script/release check --tests-only` writes `repository-validation.json`, which the publisher rejects; it must not be cited as publication evidence. A report is not a release, creates no tag, and does not select a version. See [Releasing Fleet](Releasing.md) for the publication path.
