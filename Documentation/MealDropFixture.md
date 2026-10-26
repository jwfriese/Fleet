# Meal drag-and-drop transfer fixture

`Integration/PackageConsumer/MealDropConsumerTests.swift` is a Fleet-owned example of testing an application's *transfer intent and destination rules* for moving meals between day slots and adjacent weeks. It uses fake transfer data, a fake async service, a `UIViewControllerRepresentable` week screen, and only public Fleet APIs (`Fleet.withHostedView`, `waitForUpdate`, `hostingController`). It is compiled by the external package consumer and run by `script/check-distribution`. It is **not Reciplan's code**; real payload types, conflict rules and services remain application-owned.

## What each helper claims

`DropReport.coverage` states what actually happened:

| Coverage | Meaning | Produced by |
| --- | --- | --- |
| `.intentValidated` | Only the application's validation rules ran. | `MealDropDriver.validateIntent` |
| `.handlerInvoked` | The application's drop handler was called directly. | `MealDropDriver.invokeHandler` |
| `.physicalRoutingObserved` | Real drag delivery, hover or autoscroll was seen. | Nothing in this fixture |

A direct handler call proves rules and resulting screen state, never that UIKit delivered a drag to the handler.

## Cases

Valid move updates source and destination labels on the hosted screen; an adjacent-week move empties the source on the current week and appears only after the week changes; invalid destinations, unsupported payload kinds, missing sources and duplicates are rejected before the service is called and leave state unchanged; a failed async acceptance does not mutate; cancelling a hung acceptance returns `.cancelled`, the in-flight service work observes cancellation, and nothing mutates. All waits are bounded and condition-based.

## Complementary XCUITest coverage (not provided here)

Actual drag delivery to `UIDropInteraction`/`onDrop`, hover feedback, edge autoscroll while dragging, and reachability of other weeks during a drag need an XCUITest against a real app (compare `Integration/UIKitTraceHarness`). Drag gestures are not synthesized by Fleet.

## Platform

iOS only (the file compiles to nothing in the tvOS consumer target); consumer deployment target is iOS 15.
