import SwiftUI
import Testing
import UIKit
import XCTest
import Fleet
import ViewInspector
import PantryApp

// Test-only adoption of a screen from a separately compiled application module (`PantryApp`, sources in
// Integration/PackageConsumer/AppModule). The module links neither Fleet nor ViewInspector. This file is
// the whole test-side adapter:
//   * Fleet owns the one hosting window; the imported screen is mounted once.
//   * The app-owned `InspectionSeam` hands the live screen to ViewInspector, which scopes to a row by its
//     stable identifier and invokes the mounted Button's own action.
//   * `fleetObservedContent` is applied *outside* the module, from model state, as semantic metadata.
//   * The independent oracle reads pixels of the already mounted hosting view (no second mount).

@MainActor
final class FakePantryService: PantryService {
    private var held: [String: CheckedContinuation<Void, Error>] = [:]
    private(set) var started: [String] = []
    struct Refused: Error {}

    func remove(id: String) async throws {
        started.append(id)
        try await withCheckedThrowingContinuation { held[id] = $0 }
    }

    func isPending(_ id: String) -> Bool { held[id] != nil }
    func releaseSuccess(_ id: String) { held.removeValue(forKey: id)?.resume() }
    func releaseFailure(_ id: String) { held.removeValue(forKey: id)?.resume(throwing: Refused()) }
    /// Resumes every request still held, so no continuation outlives its test.
    func releaseAll() {
        let pending = held
        held = [:]
        pending.values.forEach { $0.resume(throwing: CancellationError()) }
    }
}

/// Test-side wrapper: the metadata is derived from model state only, so a view-only defect leaves it correct.
private struct ObservedPantry: View {
    @ObservedObject var model: PantryModel
    let seam: PantryApp.InspectionSeam<PantryScreen>
    let defect: PantryDefect?

    var body: some View {
        PantryScreen(model: model, seam: seam, defect: defect)
            .fleetObservedContent("pantry", [
                "rows": model.items.map(\.id).joined(separator: ","),
                "feedback": model.errorMessage ?? model.confirmation ?? "",
            ])
    }
}

/// The step at which a flow's independent check failed. Any other error fails a mutation test.
enum PantryOracle: Error, Equatable {
    case wrongControl(started: [String])
    case metadata(String)
    case visibleRows(stage: String, expected: [String], actual: [String])
}

private let initialRows = ["flour", "eggs", "milk"]
/// What a viewer sees for each row id: the row's own swatch, in row order.
private let swatchOfID = ["flour": "red", "eggs": "green", "milk": "blue"]

@MainActor
private func inspectPantry<T>(
    _ seam: PantryApp.InspectionSeam<PantryScreen>, in context: FleetTestContext, timeout: TimeInterval = 2,
    _ body: @escaping @MainActor (ScopedInspector) throws -> T
) async throws -> T {
    var value: T?
    var failure: Error?
    try await context.waitUntil("mounted PantryScreen to answer inspection", timeout: timeout) {
        seam.run { view in
            do { value = try body(ScopedInspector(try view.inspect())) } catch { failure = error }
        }
    }
    if let failure { throw failure }
    return value!
}

/// Reads the swatch colors, top to bottom, from an image of the mounted hosting view rendered in place at scale 1.
/// A color counts when 12 or more adjacent pixels in one pixel row match it.
@MainActor
private func visibleRows(_ host: FleetHostedView) throws -> [String] {
    guard let view = host.hostingController.viewIfLoaded, host.isReady, view.window === host.context.window else { throw PantryOracle.metadata("not the ready hosted view") }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    var drew = false
    let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
        drew = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
    guard drew, let cg = image.cgImage else { throw PantryOracle.metadata("UIKit could not draw the mounted view") }
    let width = cg.width, height = cg.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { throw PantryOracle.metadata("could not read pixels") }

    func color(at x: Int, _ y: Int) -> Swatch? {
        let offset = (y * width + x) * 4
        return Swatch.allCases.first {
            abs(Int(data[offset]) - $0.rgb.red) <= 12 && abs(Int(data[offset + 1]) - $0.rgb.green) <= 12
                && abs(Int(data[offset + 2]) - $0.rgb.blue) <= 12
        }
    }
    var sequence: [Swatch] = []
    var previous: Swatch?
    for y in 0..<height {
        var found: Swatch?
        var run = 0
        var runColor: Swatch?
        for x in 0..<width {
            let current = color(at: x, y)
            run = (current != nil && current == runColor) ? run + 1 : (current == nil ? 0 : 1)
            runColor = current
            if run >= 12 { found = current; break }
        }
        if let found, found != previous { sequence.append(found) }
        previous = found
    }
    return sequence.map(\.rawValue)
}

@MainActor
private func checkpoint(
    _ host: FleetHostedView, _ stage: String, rows: [String], feedback: String
) async throws {
    // Fleet-reported metadata (derived from the model) first: it must be correct in every flow.
    try await host.waitForUpdate("\(stage): metadata") {
        host.currentContent("pantry")?.values["rows"] == rows.joined(separator: ",")
            && host.currentContent("pantry")?.values["feedback"] == feedback
    }
    if host.currentContent("pantry")?.values["rows"] != rows.joined(separator: ",") { throw PantryOracle.metadata(stage) }
    try host.layoutIfNeeded()
    let expected = rows.map { swatchOfID[$0]! }
    let actual = try visibleRows(host)
    if actual != expected { throw PantryOracle.visibleRows(stage: stage, expected: expected, actual: actual) }
}

/// Removes the second row through the mounted button, holds the response, and releases failure then success.
@MainActor
private func runPantryFlow(defect: PantryDefect?) async throws {
    let window = try XCTUnwrap(UIApplication.shared.keyWindow)
    let service = FakePantryService()
    let model = PantryModel(items: [
        PantryItem(id: "flour", name: "Flour", swatch: .red),
        PantryItem(id: "eggs", name: "Eggs", swatch: .green),
        PantryItem(id: "milk", name: "Milk", swatch: .blue),
    ], service: service)
    let seam = PantryApp.InspectionSeam<PantryScreen>()
    try await Fleet.withHostedView(ObservedPantry(model: model, seam: seam, defect: defect), window: window) { host in
        try host.context.addCleanup {
            model.shutdown()
            service.releaseAll()
        }
        try await host.waitForContentPresented("pantry")
        try await checkpoint(host, "initial", rows: initialRows, feedback: "")

        // The actual mounted Button inside the row identified by `row.eggs`, not a parallel command.
        _ = try await inspectPantry(seam, in: host.context) { try $0.container("row.eggs").tap("Remove") }
        try await host.waitForUpdate("a removal request started") { !service.started.isEmpty }
        if service.started != ["eggs"] { throw PantryOracle.wrongControl(started: service.started) }
        XCTAssertTrue(service.isPending("eggs"))
        try await checkpoint(host, "optimistic", rows: ["flour", "milk"], feedback: "")

        service.releaseFailure("eggs")
        try await checkpoint(host, "rollback", rows: initialRows, feedback: "Could not remove Eggs")
        let error = try await inspectPantry(seam, in: host.context) {
            try $0.root.find(viewWithAccessibilityIdentifier: "feedback").text().string()
        }
        XCTAssertEqual(error, "Could not remove Eggs")

        _ = try await inspectPantry(seam, in: host.context) { try $0.container("row.milk").tap("Remove") }
        try await host.waitForUpdate("second removal started") { service.isPending("milk") }
        service.releaseSuccess("milk")
        try await checkpoint(host, "success", rows: ["flour", "eggs"], feedback: "Removed Milk")
        XCTAssertEqual(host.lifecycle.count(of: .appeared), 1)  // one owner, one mount
    }
    XCTAssertFalse(service.isPending("eggs") || service.isPending("milk"))
    XCTAssertFalse(seam.hasPendingRequest)
}

@MainActor
final class ExternalModuleAdoptionXCTests: XCTestCase {
    func test_importedScreen_passesOptimisticRollbackAndSuccessThroughTheMountedButton() async throws {
        try await runPantryFlow(defect: nil)
    }

    func test_wrongControlBinding_failsTheStartedRequestCheck() async throws {
        do {
            try await runPantryFlow(defect: .crossedButtonBinding)
            XCTFail("mutant unexpectedly passed")
        } catch let failure as PantryOracle {
            XCTAssertEqual(failure, .wrongControl(started: ["milk"]))
        }
    }

    func test_reversedRowsWithCorrectMetadata_failTheMountedImageOracle() async throws {
        do {
            try await runPantryFlow(defect: .reversedRows)
            XCTFail("mutant unexpectedly passed")
        } catch let failure as PantryOracle {
            XCTAssertEqual(failure, .visibleRows(stage: "initial", expected: ["red", "green", "blue"], actual: ["blue", "green", "red"]))
        }
    }

    func test_wrongRowImageWithCorrectMetadata_failsTheMountedImageOracle() async throws {
        do {
            try await runPantryFlow(defect: .wrongSwatch)
            XCTFail("mutant unexpectedly passed")
        } catch let failure as PantryOracle {
            XCTAssertEqual(failure, .visibleRows(stage: "initial", expected: ["red", "green", "blue"], actual: ["red", "blue", "blue"]))
        }
    }
}

@MainActor
@Suite("Imported application module (Swift Testing)")
struct ExternalModuleAdoptionTests {
    @Test func importedScreenPassesTheWholeFlow() async throws {
        try await runPantryFlow(defect: nil)
    }

    @Test func reversedRowsFailTheMountedImageOracleNotTheMetadata() async throws {
        await #expect(throws: PantryOracle.visibleRows(stage: "initial", expected: ["red", "green", "blue"], actual: ["blue", "green", "red"])) {
            try await runPantryFlow(defect: .reversedRows)
        }
    }

    @Test func crossedButtonBindingIsDetected() async throws {
        await #expect(throws: PantryOracle.wrongControl(started: ["milk"])) {
            try await runPantryFlow(defect: .crossedButtonBinding)
        }
    }
}
