# Fleet documentation

[Quick start](QuickStart.md) is a compiled Swift Testing example and lists current limits.

## Hosting and environments

| Guide | Platforms | Provides |
| --- | --- | --- |
| [Scoped hosting](Hosting.md) | iOS, tvOS | `Fleet.withContext(window:)` / `withContext(scene:)`: whole-lifetime exclusion, bounded waits, cleanup, storyboard binding ownership, and `FleetEnvironment` (size, appearance; Dynamic Type on 17+). |
| [SwiftUI hosting](SwiftUIHosting.md) | iOS, tvOS | `Fleet.withHostedView`: scoped SwiftUI host, distinct appearance/update/removal and observed-task events, lower-level `mount`. |
| [ViewInspector compatibility](ViewInspector.md) | iOS, tvOS | Executable proof (optional, consumer test target only) of inspecting the SwiftUI screen a Fleet context owns; pinned matrix, required seam and evidence levels. |
| [Named environments and snapshots](SnapshotTesting.md) | iOS, tvOS | Recipe (optional, consumer test target only) running named environment cases in sequential hosted scopes, with an adapter that compares the mounted screen through SnapshotTesting. |
| [Runtime hooks](RuntimeHooks.md) | iOS, tvOS | Inventory of process-wide Objective-C hooks. |

## Reference

| Type | Platforms | Provides |
| --- | --- | --- |
| [UIAlertController](UIAlertController.md) | iOS, tvOS | Tap alert actions. |
| [UIBarButtonItem](UIBarButtonItem.md) | iOS, tvOS | Tap bar button items. |
| [UIButton](UIButton.md) | iOS, tvOS | Tap buttons. |
| [UICollectionView](UICollectionView.md) | iOS, tvOS | Inspect and fetch cells; select and deselect items. |
| [UINavigationBar](UINavigationBar.md) | iOS, tvOS | Tap top items. |
| [UINavigationController](UINavigationController.md) | iOS, tvOS | Immediate push and pop. |
| [UIStoryboard](UIStoryboard.md) | iOS, tvOS | Mock and bind view controllers. |
| [UISwitch](UISwitch.md) | iOS | Flip switches. |
| [UITabBarController](UITabBarController.md) | iOS, tvOS | Select tabs. |
| [UITableView](UITableView.md) | iOS, tvOS | Select rows, fetch cells, perform contextual swipe actions. |
| [UITextField](UITextField.md) | iOS | Enter and edit text. |
| [UITextView](UITextView.md) | iOS | Enter and edit text. |
| [UIToolbar](UIToolbar.md) | iOS | Tap items. |
| [UIViewController](UIViewController.md) | iOS, tvOS | Non-animated presentation. |

## Guides

- [FAQ](FAQ.md), including migration from `FleetError` to the `...OrThrow` forms
- [Compatibility and distribution](Compatibility.md)
- SwiftPM: [Installation](Installation/SwiftPM.md). Historical 4.x: [iOS](Installation/iOS.md), [tvOS](Installation/tvOS.md).
- [Modernization](Modernization.md) (implemented work, remaining gaps, and historical audit evidence) and [Releasing](Releasing.md), for maintainers.
