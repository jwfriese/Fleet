# Test-only adoption from a separate application module

Platforms: iOS and tvOS (consumer-verified, `--with-viewinspector`). macOS is not covered.

This page records an executable proof that Fleet and ViewInspector can stay out of an application's compile and link graph while a test bundle hosts one of its screens, operates the real mounted Button, and detects regressions that only change what is drawn. The fixture is generic. It does not certify any downstream application; a private adopter needs its own source and mutations.

## The source split (what is compiled where)

| Target | Sources | Links |
| --- | --- | --- |
| `ConsumerHost-<platform>` (app) | `AppDelegate.swift` | nothing |
| `PantryApp` (framework, separately compiled) | `Integration/PackageConsumer/AppModule/PantryModel.swift`, `PantryScreen.swift` | nothing: no package product dependency, no Fleet, FleetRuntime or ViewInspector import, no conditional import |
| `ConsumerTests-<platform>` (hosted test bundle) | `ViewInspector/ExternalModuleAdoptionTests.swift` and the other consumer tests | Fleet, ViewInspector, `PantryApp` (embedded in the bundle) |

`script/tests/test_distribution.py` (`ApplicationModuleBoundaryTests`) fails if the generated `PantryApp` target gains a package dependency or build dependency, if the app target gains a package dependency, or if a module source imports Fleet or ViewInspector.

## What the application must own

Only one neutral piece, `InspectionSeam<V: View>` in `PantryScreen.swift` (Combine only): the screen subscribes with `.onReceive(seam.notice) { seam.visit(self) }`, and the test hands the seam a closure that receives the live, mounted `self`. This is the same seam described in [ViewInspector](ViewInspector.md). Beyond it the module needs:

- stable accessibility identifiers on rows (`row.<id>`) so the test scopes by identity, not position;
- a service protocol the test can fake and hold (`PantryService`), and a model with a `shutdown()` the test calls at scope end;
- public screen, model and item types.

No new Fleet product or module split was needed.

## How task, content and element observations integrate

`fleetElement`, `fleetObservedContent` and `fleetObservedTask` are Fleet APIs, so the module cannot call them. Fleet's modifiers are view modifiers: the test applies them from outside, on the imported screen, in a test-side wrapper (`ObservedPantry`). The wrapper derives `fleetObservedContent("pantry", ["rows": ..., "feedback": ...])` from the model, so it reports semantic state. `fleetObservedTask` and `fleetElement` can wrap the screen the same way, but they can only describe the wrapper's own subtree; a task started or a row declared inside the module is not reported by them.

Unsupported route: observing a `.task` that lives inside the imported module, or a per-row `fleetElement` action registered on a module-internal row, requires the module to expose an application-owned hook (a closure or protocol) for the test to attach. This fixture does not do that, and no such hook is a Fleet requirement.

## The proof (`ExternalModuleAdoptionTests.swift`)

1. `Fleet.withHostedView` mounts the wrapper once (`host.lifecycle.count(of: .appeared) == 1`). Cleanup shuts the model down and resumes every held request.
2. A ViewInspector query through the seam descends into `row.eggs` and taps the Button labelled "Remove" inside it. That invokes the Button's own action closure, not a command registered beside it. The fake service must report exactly `["eggs"]` started.
3. The response is held. The optimistic stage is checked: rows `flour, milk`.
4. `releaseFailure("eggs")`: rows return in the original order `flour, eggs, milk`, and the feedback text reads "Could not remove Eggs".
5. Removing `milk` and calling `releaseSuccess` leaves `flour, eggs` and "Removed Milk".

At every stage the test first checks Fleet's reported `rows`/`feedback` metadata, then runs the independent oracle.

## The independent oracle and the negative controls

The oracle renders the **already mounted** hosting view in place (`drawHierarchy`, scale 1, no remount, no new window) and reads the swatch color painted beside each row, top to bottom. Metadata, model arrays and body reflection cannot supply it, since each is correct in the mutants below. It reports declared colors that are visible in pixels; it does not read text and is not a general rendering engine.

| Mutant (view only) | Model and metadata | Result |
| --- | --- | --- |
| `crossedButtonBinding`: each Remove removes the next row | correct | the `wrongControl(started: ["milk"])` check fails |
| `reversedRows`: rows drawn in reverse | correct | `visibleRows` fails at `initial`: expected red, green, blue; actual blue, green, red |
| `wrongSwatch`: second row drawn with the last row's color | correct | `visibleRows` fails at `initial`: actual red, blue, blue |

Each is asserted in XCTest; the corrected flow, `reversedRows` and `crossedButtonBinding` also run under Swift Testing.

## Reproduce

```
script/check-distribution --allow-dirty --with-viewinspector [ios|tvos]
python3 -m unittest discover -s script/tests -v
```

On a clean committed checkout, omit `--allow-dirty` to pin the committed revision. The run pins the Fleet package revision and ViewInspector `2dacb6e514be19379c605a5a11564d0f3fea89d9` (0.10.5) in the generated project's `Package.resolved`, and writes `validation.json` with both revisions under `build/distribution-*`. Reference run for the handoff: Xcode 26.6, iOS and tvOS simulator 26.5, 84 consumer tests per policy on iOS, and the tvOS consumer passing, with legacy and preserve-timing hosting.

## Limits

- ViewInspector reports the mounted instance's declaration; `tap()` is not a physical touch.
- The pixel oracle covers colored swatches in one portrait layout. Text and image *content* are not extracted.
- One screen with one stack of rows; sheets, navigation and `@StateObject` children inside the module are not covered.
- The module is a framework. Static libraries, Swift packages as the application module and Objective-C screens were not run.
