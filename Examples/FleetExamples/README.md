> **Historical example.** This project pins Fleet 3.0.0 with Carthage and old Quick/Nimble revisions and is not built by Fleet's test suite or CI. For a maintained example that is compiled against the current package, see the [quick start](../../Documentation/QuickStart.md).

Included in this folder is an example project totally test-driven using Fleet. As you learn
Fleet, we encourage you to check out its tests for guidance and best practices.

Fleet loves [Quick](https://github.com/Quick/Quick) and [Nimble](https://github.com/Quick/Nimble),
and so this project includes tests written using those two frameworks in the [WithQuick](./FleetExamplesTests/WithQuick)
folder.

Because not all projects prefer the BDD-style testing that Quick facilitates, all tests written using Quick
have functionally-equivalent versions written using only XCTest in the [WithXCTest](./FleetExamplesTests/WithXCTest)
folder.
