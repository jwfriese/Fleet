import SnapshotTesting
import UIKit
import XCTest
import Fleet

// Optional adapter: SnapshotTesting compares images; Fleet owns the screen.
//
// SnapshotTesting's `Snapshotting<UIView, UIImage>.image` and its SwiftUI strategy move the view
// into a window of their own (or build a new hosting controller), which would capture a second
// instance. This adapter instead renders the already mounted hosting view in place and hands only
// the resulting `UIImage` to the library's image comparison, reference storage and diff output.

/// Whether a missing or different reference may be rewritten. The default never rewrites.
enum SnapshotRecordPolicy {
    /// Compare only. A missing reference is a failure (SnapshotTesting writes it for inspection).
    case verify
    /// Rewrite the reference. The run reports a failure, as SnapshotTesting does, so it cannot pass CI.
    case record

    /// `FLEET_SNAPSHOT_RECORD=1` (pass it to the test host as `TEST_RUNNER_FLEET_SNAPSHOT_RECORD=1`).
    static var fromEnvironment: SnapshotRecordPolicy {
        ProcessInfo.processInfo.environment["FLEET_SNAPSHOT_RECORD"] == "1" ? .record : .verify
    }
}

struct MountedCaptureError: Error, CustomStringConvertible {
    let description: String
}

/// Renders the mounted hosting view where it is, at scale 1 so references do not depend on the
/// simulator's display scale. Throws, rather than snapshotting something else, if it is not the
/// window's hosting view or UIKit declines to draw it.
@MainActor
func captureMounted(_ host: FleetHostedView, report: CaseReport) throws -> UIImage {
    let view = host.hostingController.view!
    guard host.isReady, view.window === host.context.window,
          host.context.window.rootViewController === host.hostingController else {
        throw MountedCaptureError(description: "\(report.label) hosting view is not the ready root of Fleet's window.")
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    var drew = false
    let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
        drew = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
    guard drew else { throw MountedCaptureError(description: "\(report.label) UIKit could not draw the mounted view.") }
    return image
}

/// Compares `image` with the reference named after the case. Returns SnapshotTesting's failure
/// message (prefixed with the case label) or `nil` on a match.
@MainActor
func verifyCase(
    _ image: UIImage, report: CaseReport, directory: URL, policy: SnapshotRecordPolicy,
    file: StaticString = #filePath, testName: String = #function, line: UInt = #line
) -> String? {
    verifySnapshot(
        of: image, as: .image(scale: 1), named: report.artifactName, record: policy == .record,
        snapshotDirectory: directory.path, file: file, testName: testName, line: line
    ).map { "\(report.label) \($0)" }
}

@MainActor
final class SnapshotEnvironmentTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("fleet-snapshots-\(UUID().uuidString)")
        directory = root.appendingPathComponent("references")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard EnvironmentCases.traitOverridesAvailable else { throw XCTSkip("Per-window trait overrides need iOS/tvOS 17.") }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }

    private func window() throws -> UIWindow { try XCTUnwrap(UIApplication.shared.keyWindow) }

    /// Records every case into a per-test directory, then verifies a fresh run against it.
    /// References here are produced and consumed in one process on one runtime, so the comparison is
    /// reproducible by construction. Committing references additionally requires pinning the
    /// Xcode, runtime and device (see Documentation/SnapshotTesting.md).
    func test_namedCases_recordThenVerifyTheMountedScreen() async throws {
        var reports: [CaseReport] = []
        try await EnvironmentCases.run(EnvironmentCases.standard, window: try window()) { host, report, _ in
            let image = try captureMounted(host, report: report)
            XCTAssertEqual(image.size, EnvironmentCases.phone, report.label)
            // The first pass records, which SnapshotTesting reports as a failure message.
            let recorded = verifyCase(image, report: report, directory: directory, policy: .record)
            XCTAssertNotNil(recorded, report.label)
            reports.append(report)
        }
        try await EnvironmentCases.run(EnvironmentCases.standard, window: try window()) { host, report, _ in
            let image = try captureMounted(host, report: report)
            XCTAssertNil(verifyCase(image, report: report, directory: directory, policy: .verify), report.label)
        }
        XCTAssertEqual(reports.map(\.name), EnvironmentCases.standard.map(\.name))
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names.count, EnvironmentCases.standard.count, "one reference per named case: \(names)")
    }

    /// The cases must actually differ, otherwise matching references would prove nothing.
    func test_distinctCases_produceDistinctImages() async throws {
        var images: [String: Data] = [:]
        try await EnvironmentCases.run(EnvironmentCases.standard, window: try window()) { host, report, _ in
            images[report.name] = try captureMounted(host, report: report).pngData()
        }
        XCTAssertEqual(Set(images.values).count, EnvironmentCases.standard.count, "cases rendered identically: \(images.keys)")
    }

    /// A deliberate mismatch: the reference is the light case, the actual is the dark case.
    /// SnapshotTesting reports the failure and supplies reference, failure and difference images.
    func test_deliberateMismatch_yieldsActualExpectedAndDiffImages() async throws {
        let cases = EnvironmentCases.standard.filter { ["light", "dark"].contains($0.name) }
        var light: (UIImage, CaseReport)?
        var dark: (UIImage, CaseReport)?
        try await EnvironmentCases.run(cases, window: try window()) { host, report, _ in
            let image = try captureMounted(host, report: report)
            if report.name == "light" { light = (image, report) } else { dark = (image, report) }
        }
        let (expected, lightReport) = try XCTUnwrap(light)
        let (actual, darkReport) = try XCTUnwrap(dark)

        // Reference = light, recorded under the dark case's name; actual = dark.
        let named = CaseReport(name: darkReport.name, resolved: darkReport.resolved, features: darkReport.features)
        _ = verifyCase(expected, report: named, directory: directory, policy: .record)
        let message = try XCTUnwrap(verifyCase(actual, report: named, directory: directory, policy: .verify))
        XCTAssertTrue(message.hasPrefix(named.label), "case identity, resolved environment and features lead the message")
        XCTAssertTrue(message.contains("does not match reference"), message)
        XCTAssertFalse(lightReport.label.isEmpty)

        // The library's diffing yields the three images, named as SnapshotTesting attaches them.
        let diffing = Snapshotting<UIImage, UIImage>.image(scale: 1).diffing
        let (_, attachments) = try XCTUnwrap(diffing.diff(expected, actual))
        XCTAssertEqual(attachments.compactMap(\.name).sorted(), ["difference", "failure", "reference"])
        // The mismatch is the expected outcome, so the test passes; keep the evidence anyway
        // (XCTest deletes attachments of passing tests by default).
        for attachment in attachments {
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let report = XCTAttachment(string: message)
        report.lifetime = .keepAlways
        add(report)

        // The failing actual image is also written under SNAPSHOT_ARTIFACTS (set by
        // script/check-distribution so CI retains it) or the temporary directory.
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] ?? NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SnapshotEnvironmentTests")
        let written = try FileManager.default.contentsOfDirectory(atPath: base.path)
        XCTAssertTrue(written.contains { $0.hasSuffix(".dark.png") }, "no failing image under \(base.path): \(written)")
    }

    /// Capturing leaves Fleet's window and host alone; a later case begins from the baseline.
    func test_capture_doesNotReplaceTheHostOrLeakIntoALaterCase() async throws {
        let window = try window()
        let rootBefore = window.rootViewController
        let scene = try XCTUnwrap(window.windowScene)
        let windowsBefore = scene.windows.map(ObjectIdentifier.init)
        var roots: [UIViewController] = []  // strong, so freed addresses cannot be reused
        try await EnvironmentCases.run(EnvironmentCases.standard, window: window) { host, report, _ in
            let before = ObjectIdentifier(host.hostingController)
            _ = try captureMounted(host, report: report)
            XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(window.rootViewController)), before, report.label)
            XCTAssertEqual(scene.windows.map(ObjectIdentifier.init), windowsBefore, report.label)
            XCTAssertTrue(window.isKeyWindow, report.label)
            roots.append(host.hostingController)
        }
        XCTAssertEqual(Set(roots.map(ObjectIdentifier.init)).count, roots.count, "each case has a fresh host")
        XCTAssertTrue(window.rootViewController === rootBefore)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .unspecified)
    }

    /// A capture refused before drawing surfaces as an error with the case identity, never as a pass.
    func test_captureOfANonRootView_isRefused() async throws {
        do {
            try await EnvironmentCases.run([EnvironmentCases.standard[0]], window: try window()) { host, report, _ in
                host.hostingController.view.removeFromSuperview()
                _ = try captureMounted(host, report: report)
            }
            XCTFail("expected refusal")
        } catch let error as MountedCaptureError {
            XCTAssertTrue(error.description.contains("[case light"), error.description)
        }
    }
}
