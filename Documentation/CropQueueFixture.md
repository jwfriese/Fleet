# Mixed-screen crop-queue fixture

`Integration/PackageConsumer/CropQueueConsumerTests.swift` is a Fleet-owned, representative mixed SwiftUI/UIKit scenario. It is compiled by the external package consumer (public APIs only) and run by `script/check-distribution`. It uses fake in-memory assets, a `UIViewControllerRepresentable` crop controller with a coordinator, and a SwiftUI parent that gates the controller's size from zero to non-zero.

**It is not any downstream application's code and does not certify that application's regressions.** No downstream repository or original fixes were supplied. Unknown and therefore assumed: the real candidate/identity contract (here: one controller is reused across candidate changes; `makeUIViewController` runs once), the real layout trigger for the toolbar-only screen (here: a first layout pass consumed at zero bounds), and the real crop-box geometry rules (here: aspect-fit image, crop box inset 12 pt). Validation against a real app remains separate.

## What it demonstrates

| Test | Expected outcome |
| --- | --- |
| `test_correctedBaseline_passesWithPreserveTimingHosting` | Zero-size controller (toolbar only), then non-zero layout: image and crop-box frames match independently computed aspect-fit geometry inside the window; a candidate change keeps the same controller and shows the new image. |
| `test_withoutCandidateIdentityCorrection_failsCurrentImageAssertion` | `CropAssertion.staleImage`: the controller still shows the old candidate/image after the update was delivered. |
| `test_withoutLayoutWorkaround_failsImageGeometryAfterZeroToNonzero` | `CropAssertion.imageGeometry`: the image frame stays empty after the prescribed zero -> non-zero sequence. |
| `test_discovery_distinguishesMissingAmbiguousAndWrongType` | `CropDiscoveryError.missing`, `.ambiguous(count:)`, `.wrongType(found:)`. |
| `test_teardownAfterThrow`, `test_teardownAfterCancellation`, baseline | Dismantle event delivered once, coordinator observer released, controller/coordinator deallocated, observed `prefetch` task cancelled. |

The mutations are runtime switches in `CropFixtureOptions`, so nothing is edited or restored on disk. A mutant counts only if it fails the *named* assertion kind; an unrelated error (timeout, setup) fails the test. Mutants wait for the delivered update/layout pass (events and layout counters), not for the wrong end state, so they do not rely on timeouts.

## Controls used

Only public APIs: `Fleet.withHostedView`, `FleetHostedView.layoutIfNeeded()`, `waitUntilReady`, `waitForUpdate`, `hostingController` (for typed discovery by walking `children`), and `fleetObservedTask`. `FleetEnvironment` still rejects non-positive sizes and the controller's frame is never forced; the zero size comes from SwiftUI laying out a `.frame(width: 0, height: 0)` parent. Discovery is fixture-owned (marker plus typed cast), not a Fleet API.

## Platform

The fixture is iOS-only (it uses UIToolbar); the file compiles to nothing in the tvOS consumer target. The throw path retains the observed prefetch task state outside the throwing scope and asserts it observed cancellation.
