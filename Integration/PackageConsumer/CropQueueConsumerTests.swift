import Combine
import SwiftUI
import UIKit
import XCTest
import Fleet

// A Fleet-owned, representative mixed SwiftUI/UIKit crop queue. It uses fake in-memory assets (no camera or network)
// and only public Fleet APIs. It is NOT Reciplan's code: see Documentation/CropQueueFixture.md for what is unknown.

// MARK: Fake assets and application-owned model

struct CropCandidate: Equatable {
    let id: String
    let pixelSize: CGSize
    let color: UIColor
}

@MainActor
final class FakeAssetStore {
    private var cache: [String: UIImage] = [:]
    func image(for candidate: CropCandidate) -> UIImage {
        if let cached = cache[candidate.id] { return cached }
        let renderer = UIGraphicsImageRenderer(size: candidate.pixelSize)
        let image = renderer.image { context in
            candidate.color.setFill()
            context.fill(CGRect(origin: .zero, size: candidate.pixelSize))
        }
        cache[candidate.id] = image
        return image
    }
}

/// Which intended corrections the fixture applies. Each switch is an independent, runtime-selected mutation: nothing
/// is edited or restored on disk, so a mutant can only fail by the assertion it is meant to trip.
struct CropFixtureOptions: Sendable {
    /// Candidate-identity correction: `updateUIViewController` applies a changed candidate to the reused controller.
    var applyCandidateOnUpdate = true
    /// Layout workaround: the first layout is only consumed once the bounds are non-empty.
    var relayoutAfterZero = true
}

@MainActor
final class CropQueueModel: ObservableObject {
    let queueID: String
    let candidates: [CropCandidate]
    let assets = FakeAssetStore()
    let options: CropFixtureOptions
    @Published var index = 0
    /// make/update/dismantle events in order, e.g. "make:a", "update:b", "dismantle".
    private(set) var events: [String] = []
    private(set) var liveObservers = 0
    private(set) var makeCount = 0
    weak var controller: CropController?
    weak var coordinator: CropCoordinator?

    init(queueID: String = "queue", candidates: [CropCandidate], options: CropFixtureOptions = .init()) {
        self.queueID = queueID
        self.candidates = candidates
        self.options = options
    }
    var current: CropCandidate { candidates[index] }
    func log(_ event: String) { events.append(event) }
    func observerStarted() { liveObservers += 1 }
    func observerStopped() { liveObservers -= 1 }
    func noteMade() { makeCount += 1 }
}

// MARK: UIKit crop controller

final class CropController: UIViewController {
    static let marker = "fleet.crop-queue"
    static let cropInset: CGFloat = 12
    let imageView = UIImageView()
    let cropBox = UIView()
    let toolbar = UIToolbar()
    private(set) var candidateID = ""
    private(set) var layoutPasses = 0
    private(set) var nonEmptyLayoutPasses = 0
    private var didInitialLayout = false
    private let relayoutAfterZero: Bool

    init(relayoutAfterZero: Bool) {
        self.relayoutAfterZero = relayoutAfterZero
        super.init(nibName: nil, bundle: nil)
        restorationIdentifier = Self.marker
    }
    required init?(coder: NSCoder) { fatalError("unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.contentMode = .scaleToFill
        cropBox.layer.borderWidth = 2
        cropBox.layer.borderColor = UIColor.yellow.cgColor
        view.addSubview(imageView)
        view.addSubview(cropBox)
        view.addSubview(toolbar)
        toolbar.items = [UIBarButtonItem(title: "Crop", style: .plain, target: nil, action: nil)]
    }

    func apply(candidate: CropCandidate, image: UIImage) {
        candidateID = candidate.id
        imageView.image = image
        didInitialLayout = false
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutPasses += 1
        let bounds = view.bounds
        // The toolbar is always laid out, so a zero-size pass leaves a toolbar-only screen.
        let toolbarHeight: CGFloat = bounds.isEmpty ? 0 : 44
        toolbar.frame = CGRect(x: 0, y: bounds.height - toolbarHeight, width: bounds.width, height: toolbarHeight)
        if !bounds.isEmpty { nonEmptyLayoutPasses += 1 }
        guard !didInitialLayout else { return }
        if relayoutAfterZero { didInitialLayout = !bounds.isEmpty } else { didInitialLayout = true }
        guard let image = imageView.image, !bounds.isEmpty else { return }
        let available = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - toolbarHeight)
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        imageView.frame = CGRect(x: (available.width - size.width) / 2, y: (available.height - size.height) / 2, width: size.width, height: size.height)
        cropBox.frame = imageView.frame.insetBy(dx: Self.cropInset, dy: Self.cropInset)
    }
}

/// A controller that carries the crop marker but is not a `CropController` (wrong-type discovery).
final class ImpostorController: UIViewController {
    init() { super.init(nibName: nil, bundle: nil); restorationIdentifier = CropController.marker }
    required init?(coder: NSCoder) { fatalError("unused") }
}

// MARK: Representable with coordinator

@MainActor
final class CropCoordinator {
    let model: CropQueueModel
    private var subscription: AnyCancellable?
    init(model: CropQueueModel) {
        self.model = model
        model.observerStarted()
        subscription = model.objectWillChange.sink { _ in }
    }
    func stop() {
        guard subscription != nil else { return }
        subscription?.cancel()
        subscription = nil
        model.observerStopped()
    }
    deinit { MainActor.assumeIsolated { stop() } }
}

struct CropQueueView: UIViewControllerRepresentable {
    @ObservedObject var model: CropQueueModel

    func makeCoordinator() -> CropCoordinator {
        let coordinator = CropCoordinator(model: model)
        model.coordinator = coordinator
        return coordinator
    }

    func makeUIViewController(context: Context) -> CropController {
        let controller = CropController(relayoutAfterZero: model.options.relayoutAfterZero)
        controller.loadViewIfNeeded()
        controller.apply(candidate: model.current, image: model.assets.image(for: model.current))
        model.controller = controller
        model.noteMade()
        model.log("make:\(model.current.id)")
        return controller
    }

    func updateUIViewController(_ controller: CropController, context: Context) {
        let candidate = model.current
        model.log("update:\(candidate.id)")
        if model.options.applyCandidateOnUpdate, controller.candidateID != candidate.id {
            controller.apply(candidate: candidate, image: model.assets.image(for: candidate))
        }
    }

    static func dismantleUIViewController(_ controller: CropController, coordinator: CropCoordinator) {
        coordinator.model.log("dismantle")
        coordinator.stop()
    }
}

struct ImpostorView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ImpostorController { ImpostorController() }
    func updateUIViewController(_ controller: ImpostorController, context: Context) {}
}

// MARK: Parent/container fixture controlling zero -> nonzero layout

@MainActor
final class SizeGate: ObservableObject {
    @Published var open = false
}

struct GatedCropContainer: View {
    @ObservedObject var model: CropQueueModel
    @ObservedObject var gate: SizeGate
    let onPrefetchCancel: @MainActor @Sendable () -> Void
    var body: some View {
        CropQueueView(model: model)
            .frame(width: gate.open ? nil : 0, height: gate.open ? nil : 0)
            .fleetObservedTask("prefetch") {
                while !Task.isCancelled { try? await Task.sleep(nanoseconds: 5_000_000) }
                onPrefetchCancel()
            }
    }
}

// MARK: Typed discovery

enum CropDiscoveryError: Error, Equatable {
    case missing
    case ambiguous(count: Int)
    case wrongType(found: String)
}

@MainActor
enum CropDiscovery {
    /// Finds the single marked controller below the host's hosting controller, as `T`.
    static func controller<T: UIViewController>(_ type: T.Type, in host: FleetHostedView) throws -> T {
        var marked: [UIViewController] = []
        func visit(_ controller: UIViewController) {
            if controller.restorationIdentifier == CropController.marker { marked.append(controller) }
            controller.children.forEach(visit)
        }
        visit(host.hostingController)
        guard let first = marked.first else { throw CropDiscoveryError.missing }
        guard marked.count == 1 else { throw CropDiscoveryError.ambiguous(count: marked.count) }
        guard let typed = first as? T else { throw CropDiscoveryError.wrongType(found: String(describing: Swift.type(of: first))) }
        return typed
    }
}

// MARK: Scenario with specific hosted assertions

struct CropAssertion: Error, CustomStringConvertible {
    enum Kind: Equatable { case staleImage, controllerIdentity, imageGeometry, cropGeometry, teardown }
    let kind: Kind
    let detail: String
    var description: String { "\(kind): \(detail)" }
}

@MainActor
enum CropScenario {
    static let candidates = [
        CropCandidate(id: "a", pixelSize: CGSize(width: 400, height: 200), color: .red),
        CropCandidate(id: "b", pixelSize: CGSize(width: 150, height: 300), color: .blue),
    ]

    /// Mounts the container at zero size, verifies the toolbar-only state, opens the gate, then changes candidate.
    static func run(options: CropFixtureOptions, observeTask: Bool = true, afterAssertions: (@MainActor (FleetHostedView, CropQueueModel) async throws -> Void)? = nil) async throws -> (CropQueueModel, Int) {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        let model = CropQueueModel(candidates: candidates, options: options)
        let gate = SizeGate()
        var cancelled = 0
        let counter = CancelCounter()
        try await Fleet.withHostedView(GatedCropContainer(model: model, gate: gate, onPrefetchCancel: { counter.count += 1 }), window: window) { host in
            // Lower-level sequence: the controller exists but SwiftUI has laid it out at zero size.
            try host.layoutIfNeeded()
            try await host.waitUntilReady()
            try await host.waitForUpdate("crop controller made") { model.controller != nil && model.controller?.layoutPasses ?? 0 > 0 }
            let controller = try CropDiscovery.controller(CropController.self, in: host)
            guard controller === model.controller else { throw CropAssertion(kind: .controllerIdentity, detail: "discovered controller is not the made controller") }
            guard controller.view.bounds.isEmpty else { throw CropAssertion(kind: .imageGeometry, detail: "expected a zero-size initial layout, got \(controller.view.bounds)") }
            guard controller.nonEmptyLayoutPasses == 0 else { throw CropAssertion(kind: .imageGeometry, detail: "unexpected non-empty layout before the gate opened") }

            gate.open = true
            try host.layoutIfNeeded()
            try await host.waitForUpdate("controller laid out at non-zero size") {
                controller.view.bounds.width > 0 && controller.view.bounds.height > 0 && controller.nonEmptyLayoutPasses > 0
            }
            try assertGeometry(controller, in: window, candidate: candidates[0], model: model)

            // Candidate change: the controller is reused (same identity contract), the image must follow.
            model.index = 1
            try await host.waitForUpdate("update delivered for candidate b") { model.events.contains("update:b") }
            try host.layoutIfNeeded()
            try await host.waitForUpdate("layout pass after candidate change") { controller.view.bounds.width > 0 }
            guard let again = try? CropDiscovery.controller(CropController.self, in: host), again === controller, model.makeCount == 1 else {
                throw CropAssertion(kind: .controllerIdentity, detail: "controller was replaced; expected reuse (makes: \(model.makeCount))")
            }
            guard controller.candidateID == "b", controller.imageView.image === model.assets.image(for: candidates[1]) else {
                throw CropAssertion(kind: .staleImage, detail: "controller shows candidate \(controller.candidateID), expected b")
            }
            try assertGeometry(controller, in: window, candidate: candidates[1], model: model)
            try await afterAssertions?(host, model)
        }
        cancelled = counter.count
        return (model, cancelled)
    }

    static func assertGeometry(_ controller: CropController, in window: UIWindow, candidate: CropCandidate, model: CropQueueModel) throws {
        let bounds = controller.view.bounds
        let toolbarHeight = controller.toolbar.frame.height
        let available = CGSize(width: bounds.width, height: bounds.height - toolbarHeight)
        let scale = min(available.width / candidate.pixelSize.width, available.height / candidate.pixelSize.height)
        let expectedSize = CGSize(width: candidate.pixelSize.width * scale, height: candidate.pixelSize.height * scale)
        let imageFrame = controller.imageView.frame
        func close(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool { abs(lhs - rhs) < 1 }
        guard close(imageFrame.width, expectedSize.width), close(imageFrame.height, expectedSize.height), !imageFrame.isEmpty else {
            throw CropAssertion(kind: .imageGeometry, detail: "image frame \(imageFrame), expected size \(expectedSize) in \(bounds) for \(candidate.id)")
        }
        let inWindow = controller.imageView.convert(controller.imageView.bounds, to: window)
        guard window.bounds.contains(inWindow) else {
            throw CropAssertion(kind: .imageGeometry, detail: "image \(inWindow) is outside the window \(window.bounds)")
        }
        let expectedCrop = imageFrame.insetBy(dx: CropController.cropInset, dy: CropController.cropInset)
        let crop = controller.cropBox.frame
        guard close(crop.minX, expectedCrop.minX), close(crop.minY, expectedCrop.minY), close(crop.width, expectedCrop.width), close(crop.height, expectedCrop.height), imageFrame.contains(crop) else {
            throw CropAssertion(kind: .cropGeometry, detail: "crop box \(crop), expected \(expectedCrop) within image \(imageFrame)")
        }
    }
}

@MainActor
final class CancelCounter { var count = 0 }

// MARK: Tests

@MainActor
final class CropQueueFixtureTests: XCTestCase {
    func test_correctedBaseline_passesWithPreserveTimingHosting() async throws {
        let (model, cancelled) = try await CropScenario.run(options: .init())
        try await assertTornDown(model, cancelled: cancelled)
        XCTAssertEqual(model.events.first, "make:a")
        XCTAssertEqual(model.events.last, "dismantle")
        XCTAssertEqual(model.makeCount, 1)
    }

    func test_withoutCandidateIdentityCorrection_failsCurrentImageAssertion() async throws {
        await expectFailure(.staleImage, options: .init(applyCandidateOnUpdate: false))
    }

    func test_withoutLayoutWorkaround_failsImageGeometryAfterZeroToNonzero() async throws {
        await expectFailure(.imageGeometry, options: .init(relayoutAfterZero: false))
    }

    func test_discovery_distinguishesMissingAmbiguousAndWrongType() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        try await Fleet.withHostedView(Text("no crop queue"), window: window) { host in
            XCTAssertThrowsError(try CropDiscovery.controller(CropController.self, in: host)) {
                XCTAssertEqual($0 as? CropDiscoveryError, .missing)
            }
        }
        let model = CropQueueModel(candidates: CropScenario.candidates)
        let other = CropQueueModel(candidates: CropScenario.candidates)
        try await Fleet.withHostedView(VStack { CropQueueView(model: model); CropQueueView(model: other) }, window: window) { host in
            try await host.waitForUpdate("both controllers made") { model.controller != nil && other.controller != nil }
            XCTAssertThrowsError(try CropDiscovery.controller(CropController.self, in: host)) {
                XCTAssertEqual($0 as? CropDiscoveryError, .ambiguous(count: 2))
            }
        }
        try await Fleet.withHostedView(ImpostorView(), window: window) { host in
            try await host.waitForUpdate("impostor present") { (try? CropDiscovery.controller(UIViewController.self, in: host)) != nil }
            XCTAssertThrowsError(try CropDiscovery.controller(CropController.self, in: host)) {
                XCTAssertEqual($0 as? CropDiscoveryError, .wrongType(found: "ImpostorController"))
            }
        }
    }

    func test_teardownAfterThrow() async throws {
        struct Boom: Error {}
        let captured = ModelBox()
        do {
            _ = try await CropScenario.run(options: .init()) { _, model in captured.model = model; throw Boom() }
            XCTFail("expected the body to throw")
        } catch is Boom {}
        let model = try XCTUnwrap(captured.model)
        try await assertTornDown(model, cancelled: nil)
    }

    func test_teardownAfterCancellation() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        let model = CropQueueModel(candidates: CropScenario.candidates)
        let gate = SizeGate()
        gate.open = true
        let counter = CancelCounter()
        let ready = ReadyFlag()
        let task = Task { @MainActor in
            try await Fleet.withHostedView(GatedCropContainer(model: model, gate: gate, onPrefetchCancel: { counter.count += 1 }), window: window) { host in
                try await host.waitForTaskStart("prefetch")
                ready.value = true
                try await host.waitForUpdate("never satisfied", timeout: 20) { false }
            }
        }
        try await poll("scope entered") { ready.value }
        task.cancel()
        _ = try? await task.value
        try await assertTornDown(model, cancelled: counter.count)
    }

    // MARK: helpers

    private func expectFailure(_ expected: CropAssertion.Kind, options: CropFixtureOptions) async {
        do {
            _ = try await CropScenario.run(options: options)
            XCTFail("mutant unexpectedly passed; expected \(expected)")
        } catch let failure as CropAssertion {
            XCTAssertEqual(failure.kind, expected, "wrong assertion tripped: \(failure)")
        } catch {
            XCTFail("mutant failed with an unrelated error (timeout or setup), which does not count: \(error)")
        }
    }

    private func assertTornDown(_ model: CropQueueModel, cancelled: Int?) async throws {
        try await poll("coordinator dismantled and observers released") { model.events.last == "dismantle" && model.liveObservers == 0 }
        XCTAssertEqual(model.liveObservers, 0)
        XCTAssertEqual(model.events.filter { $0 == "dismantle" }.count, 1)
        if let cancelled { XCTAssertEqual(cancelled, 1, "observed prefetch task must have observed cancellation") }
        XCTAssertNil(model.controller, "the crop controller must be released after teardown")
        XCTAssertNil(model.coordinator, "the coordinator must be released after teardown")
    }

    /// Bounded, condition-based wait for state that outlives a scope (no Fleet handle remains).
    private func poll(_ what: String, timeout: TimeInterval = 5, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw CropAssertion(kind: .teardown, detail: "timed out waiting for \(what)") }
            await Task { @MainActor in try? await Task.sleep(nanoseconds: 10_000_000) }.value
        }
    }
}

@MainActor final class ModelBox { var model: CropQueueModel? }
@MainActor final class ReadyFlag { var value = false }
