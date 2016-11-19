## Installation

#### Git submodules

1) Run `git submodule add http://github.com/jwfriese/Fleet`

2) Add `Fleet.xcodeproj` to your project file

3) In your test target, navigate to the `Link Binary with Libraries` section, and add `Fleet.framework`.

4) *(The following step is only necessary if you are using Fleet's storyboard-related features)*
To your test target, add a `Run Script`. The script will run a shell script included in Fleet source. For example, if you added the submodule like this:

`git submodule add http://github.com/jwfriese/Fleet Externals/Fleet`

The `Run Script` should look like this:

`$PROJECT_DIR/Externals/Fleet/Fleet/Script/copy_storyboard_info_files.sh "PRODUCTION_TARGET_NAME"`

#### Cocoapods

1) Include Fleet in your `Podfile`:
`pod 'Fleet'`

2) Run `pod install`

3) *(The following step is only necessary if you are using Fleet's storyboard-related features)*
To your test target, add a `Run Script`. The script will run a shell script preserved in the framework's Pod. Assuming your `Pods` directory is in your source root, your `Run Script` would look like this:

`${SRCROOT}/Pods/Fleet/Fleet/Script/copy_storyboard_info_files.sh "PRODUCTION_TARGET_NAME"`

#### Carthage

1) Include Fleet in your `Cartfile`:
`github "jwfriese/Fleet"`

2) Run `carthage update --platform 'iOS'`

3) In your test target, navigate to the `Link Binary with Libraries` section, and add `Fleet.framework`, which you should be able to find in your `Carthage/Build/iOS` directory

4) To your test target, add a `Run Script` to call the Carthage `copy-frameworks` script:

`/usr/local/bin/carthage copy-frameworks`

Additionally, add as an input file Fleet's framework. The path probably looks something like this:

`$(SRCROOT)/Carthage/Build/iOS/Fleet.framework`

5) *(The following step is only necessary if you are using Fleet's storyboard-related features)*
To your test target, add a `Run Script`. The script will run a shell script included in the framework. Assuming your `Carthage` directory is in your source root, your `Run Script` would look like this:

`"$PROJECT_DIR/Carthage/Build/iOS/Fleet.framework/copy_storyboard_info_files.sh"`

For further reference see [Carthage's documentation](https://github.com/Carthage/Carthage/blob/master/README.md).
