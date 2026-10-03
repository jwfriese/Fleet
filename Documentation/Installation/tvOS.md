## Installation

These instructions describe Fleet 4.x's historical installation routes. The next major release requires tvOS 15 and uses [SwiftPM](SwiftPM.md). See [compatibility and distribution](../Compatibility.md), or use the [instructions at the 4.6.1 tag](https://github.com/jwfriese/Fleet/blob/4.6.1/Documentation/Installation/tvOS.md) when working with that release. These routes are not supported for the next major release.

#### Git submodules

1) Run `git submodule add http://github.com/jwfriese/Fleet`

2) Add `Fleet.xcodeproj` to your project file

3) In your test target, navigate to the `Link Binary with Libraries` section, and add `Fleet.framework`.

4) In your test target, navigate to the `Target Dependencies` section, and add `Fleet-tvOS`.

5) *(The following step is only necessary if you are using Fleet's storyboard-related features)*
To your test target, add a `Run Script`. The script will run a shell script included in Fleet source. For example, if you added the submodule like this:

`git submodule add http://github.com/jwfriese/Fleet Externals/Fleet`

The `Run Script` should look like this:

`"$PROJECT_DIR/Externals/Fleet/Fleet/Script/copy_storyboard_info_files.sh"`

For each storyboard metadata phase below, uncheck **Based on dependency analysis** so it refreshes after host storyboard changes. The script uses Xcode's `TEST_HOST` to locate the host's compiled storyboards; the host must build before the test target. It fails the build when metadata is missing or when two storyboards have the same name with different metadata, preserving previous output on failure. Identical localized copies are accepted. Historical target-name arguments remain accepted, but are unnecessary.

#### Cocoapods

1) Include Fleet in your `Podfile`:
`pod 'Fleet'`

Make sure to put this in the section of your `Podfile` calls for `tvOS` as the platform.

2) Run `pod install`

3) *(The following step is only necessary if you are using Fleet's storyboard-related features)*
To your test target, add a `Run Script`. The script will run a shell script preserved in the framework's Pod. Assuming your `Pods` directory is in your source root, your `Run Script` would look like this:

`"${SRCROOT}/Pods/Fleet/Fleet/Script/copy_storyboard_info_files.sh"`

#### Carthage

1) Include Fleet in your `Cartfile`:
`github "jwfriese/Fleet"`

2) Run `carthage update --platform 'tvOS'`

3) In your test target, navigate to the `Link Binary with Libraries` section, and add `Fleet.framework`, which you should be able to find in your `Carthage/Build/tvOS` directory

4) To your test target, add a `Run Script` to call the Carthage `copy-frameworks` script:

`/usr/local/bin/carthage copy-frameworks`

Additionally, add as an input file Fleet's framework. The path probably looks something like this:

`$(SRCROOT)/Carthage/Build/tvOS/Fleet.framework`

5) *(The following step is only necessary if you are using Fleet's storyboard-related features)*
To your test target, add a `Run Script`. The script will run a shell script included in the framework. Assuming your `Carthage` directory is in your source root, your `Run Script` would look like this:

`"$PROJECT_DIR/Carthage/Build/tvOS/Fleet.framework/copy_storyboard_info_files.sh"`

For further reference see [Carthage's documentation](https://github.com/Carthage/Carthage/blob/master/README.md).
