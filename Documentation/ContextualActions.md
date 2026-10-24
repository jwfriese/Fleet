# Menu and swipe-row actions

Fleet can invoke an application-declared contextual action for one specific SwiftUI row. It dispatches the declared handler. It does not present a menu, reveal a swipe row, or deliver a gesture.

## Supported matrix

| Surface (`FleetActionSurface`) | Declared with | Fleet does |
| --- | --- | --- |
| `.control` (default) | `FleetElementAction("Delete") { ... }` | runs the closure |
| `.swipeAction` | `FleetElementAction("Delete", surface: .swipeAction, isDestructive: true) { ... }` | runs the closure |
| `.contextMenu` | `FleetElementAction("Pin", surface: .contextMenu) { ... }` | runs the closure |

Pass the same closure to the real `swipeActions` button or `contextMenu` item and to the `FleetElementAction`. Rows are addressed by stable identity (`fleetElement("row.\(id)")`), so an identical label on another row is never invoked.

```swift
try host.perform("Delete", onElement: "row.b", via: .swipeAction)
```

Anything else (long-press previews, drag, custom gestures, nested menus) cannot be expressed: there is no surface for it, and Fleet adds no private SwiftUI/UIKit hook or gesture emulator.

## Failures

`perform` throws `FleetFailure` naming the element, action and surface:

- `.invalidInput`: element not mounted, identity shared by several mounted elements, no action with that name/surface, or the name matches several surfaces and `via:` was omitted (never "the first").
- `.unavailableInteraction`: the action is disabled.

`host.element(_:).declaredActions` lists every action with its surface, enabled state and destructive flag.

## Three different kinds of evidence

| Question | Answered by | Not answered by |
| --- | --- | --- |
| Does the row's declared handler do the right thing, once, to the right row? | `host.perform(_:onElement:via:)` plus the resulting hosted state (`waitForElementRemoval`, model assertions) | menu or swipe presentation |
| Is a menu currently mounted? | Not provided. ViewInspector 0.10.5 has no `swipeActions` or `contextMenu` support, so the optional integration reports these as `unsupported` | |
| Does a physical swipe or long press reveal the action and reach it? | An XCUITest | Fleet |

## Complementary XCUITest (physical reachability)

Fleet's dispatch proves the handler; add a UI test in a separate UI-test target for the gesture:

```swift
let row = app.cells["row.b"]            // accessibilityIdentifier set on the row
row.swipeLeft()
app.buttons["Delete"].tap()              // reachable, labelled, hit-testable
XCTAssertFalse(row.waitForExistence(timeout: 2))
```

For a context menu use `row.press(forDuration: 1)` and tap the menu item. Do not treat UIKit `UITableView` swipe semantics as proof of SwiftUI behavior; verify on the SwiftUI screen itself.

## Tested matrix

Native suite `ContextualActionSpec` and the public consumer suite "Contextual action dispatch" (`Integration/PackageConsumer/SwiftUIHostingConsumerTests.swift`) run on iOS and tvOS simulators, Xcode 26.6 / runtimes 26.5. The tvOS runs exercise dispatch only; neither platform's run exercises physical swipes.
