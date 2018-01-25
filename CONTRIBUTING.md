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

- We use fastlane so that we can use `scan` for testing. If you don't have it already, install it however
you prefer to install gems on your system.
- We use Carthage to manage our dependencies. After cloning the repository, run `carthage update --platform iOS`
to pull Fleet's dependencies.
- Open `Fleet.xcworkspace` to work on Fleet. Included in this workspace is Fleet's test app, which contains a 
number of interesting flows that support some of Fleet's tests.

## Pull Requests

- Nothing is trivial. Submit pull requests for anything: typos,
  whitespace, you name it.
- We take testing _very seriously_. Please make sure that any PR you make includes
a complete addition to the test suite to capture the new behavior. 
- Not all pull requests will be merged, but all will be acknowledged quickly.
- Make sure your pull request includes any necessary updates to the
  README or other documentation.
- Please make sure to run the unit tests before submitting a PR. To run all of them
from the command line, simply use `./test` from the root directory. 
- The `master` branch will always support the stable Xcode version. Other
  branches will point to their corresponding versions they support.

