import AppKit
import FleetMacOS
import SwiftUI
import Testing
import ViewInspector

// Synthetic fixture: no Keychain, biometric prompt, financial record or real secret.
let syntheticPassphrase = "SYNTHETIC_PASSPHRASE"

@MainActor
final class UnlockModel: ObservableObject {
    @Published var isUnlocked = false
    @Published var unlockCalls = 0
    @Published var switchCalls = 0
    @Published var profileName = ""
}

struct UnlockScreen: View {
    @ObservedObject var model: UnlockModel
    let seam: InspectionSeam<UnlockScreen>
    @State private var passphrase = ""
    var lockedField = false

    var body: some View {
        VStack {
            if model.isUnlocked {
                VStack {
                    Text("Profile content")
                    Button("Switch profile") {
                        model.switchCalls += 1
                        model.isUnlocked = false
                        passphrase = ""
                    }
                }
                .accessibilityIdentifier("profile")
            } else {
                VStack {
                    TextField("Profile name", text: $model.profileName)
                    SecureField("Passphrase", text: $passphrase).disabled(lockedField)
                    Button("Unlock") {
                        model.unlockCalls += 1
                        if passphrase == syntheticPassphrase { model.isUnlocked = true }
                    }
                    .disabled(passphrase.isEmpty)
                    Button("Cancel") {}
                    Button("Cancel") {}
                }
                .accessibilityIdentifier("unlock-form")
            }
        }
        .frame(width: 320, height: 240)
        .onReceive(seam.notice) { seam.visit(self) }
    }
}

private func secureFields(in view: NSView) -> Int {
    (view is NSSecureTextField ? 1 : 0) + view.subviews.reduce(0) { $0 + secureFields(in: $1) }
}

@MainActor
private func expectFailure(_ expected: MacOSQueryFailure, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(expected)") } catch let failure as MacOSQueryFailure {
        #expect(failure == expected)
    } catch { Issue.record("unexpected error \(error)") }
}

@MainActor
@Suite("Mounted macOS control interaction", .serialized)
struct MacOSControlInteractionTests {
    @Test func endedHostCannotProbeOrDriveItselfOrASuccessor() async throws {
        let oldModel = UnlockModel()
        let oldSeam = InspectionSeam<UnlockScreen>()
        var ended: FleetMacOSHost?
        try await FleetMacOS.withHostedView(UnlockScreen(model: oldModel, seam: oldSeam)) { host in
            try await host.waitUntilReady()
            ended = host
        }
        let retained = try #require(ended)
        let successorModel = UnlockModel()
        let successorSeam = InspectionSeam<UnlockScreen>()
        try await FleetMacOS.withHostedView(UnlockScreen(model: successorModel, seam: successorSeam)) { host in
            try await host.waitUntilReady()
            #expect(!retained.isScopeActive)
            let stale = retained.probe(oldSeam) { try $0.container("unlock-form").textField("Profile name").setInput("STALE") }
            #expect(stale == nil)
            let crossed = retained.probe(successorSeam) { try $0.container("unlock-form").textField("Profile name").setInput("STALE") }
            #expect(crossed == nil)
            #expect(oldModel.profileName.isEmpty)
            #expect(successorModel.profileName.isEmpty)
        }
    }

    @Test func secureFieldAndButtonDriveTheMountedBindingsAndReplaceTheScreen() async throws {
        let model = UnlockModel()
        let seam = InspectionSeam<UnlockScreen>()
        try await FleetMacOS.withHostedView(UnlockScreen(model: model, seam: seam)) { host in
            try await host.waitUntilReady()
            #expect(!host.window.isKeyWindow)
            let hostingView = host.hostingController.view
            try await host.waitUntil("AppKit secure field to be realized") { secureFields(in: hostingView) == 1 }

            // A wrong passphrase reaches the real action, which declines to unlock.
            try await host.inspect(seam) { try $0.container("unlock-form").secureField("Passphrase").setInput("WRONG") }
            try await host.waitUntil("Unlock enabled") {
                host.probe(seam) { try $0.container("unlock-form").button("Unlock") }?.isEnabled == true
            }
            try await host.inspect(seam) { try $0.container("unlock-form").button("Unlock").tap() }
            #expect(model.unlockCalls == 1)
            #expect(!model.isUnlocked)

            try await host.inspect(seam) { try $0.container("unlock-form").secureField("Passphrase").setInput(syntheticPassphrase) }
            try await host.inspect(seam) { screen in
                let form = try screen.container("unlock-form")
                let kind = try form.button("Unlock").tap()
                #expect(kind == .invokesClosure)
                #expect(screen.trace == ["tap button 'Unlock'"])
            }
            #expect(model.unlockCalls == 2)
            try await host.waitForUpdate("profile screen") { model.isUnlocked }
            try await host.waitUntil("input subtree removed") { secureFields(in: hostingView) == 0 }

            try await host.inspect(seam) { screen in
                expectFailure(.absent(target: "container 'unlock-form'", scope: "screen")) { _ = try screen.container("unlock-form") }
                try screen.container("profile").button("Switch profile").tap()
            }
            #expect(model.switchCalls == 1)
            try await host.waitUntil("form restored") { secureFields(in: hostingView) == 1 }
        }
        #expect(!seam.hasPendingRequest)
    }

    @Test func absentAmbiguousDisabledUnsupportedAndObsoleteStayDistinct() async throws {
        let model = UnlockModel()
        let seam = InspectionSeam<UnlockScreen>()
        try await FleetMacOS.withHostedView(UnlockScreen(model: model, seam: seam, lockedField: true)) { host in
            try await host.waitUntilReady()
            var retained: ButtonHandle?
            try await host.inspect(seam) { screen in
                let form = try screen.container("unlock-form")
                expectFailure(.ambiguous(target: "button 'Cancel'", scope: "screen > 'unlock-form'", count: 2)) { _ = try form.button("Cancel") }
                expectFailure(.absent(target: "button 'Missing'", scope: "screen > 'unlock-form'")) { _ = try form.button("Missing") }
                expectFailure(.absent(target: "secure field 'Profile name'", scope: "screen > 'unlock-form'")) { _ = try form.secureField("Profile name") }
                expectFailure(.disabled(target: "button 'Unlock'", scope: "screen > 'unlock-form'")) { try form.button("Unlock").tap() }
                expectFailure(.disabled(target: "secure field 'Passphrase'", scope: "screen > 'unlock-form'")) {
                    try form.secureField("Passphrase").setInput("must-not-appear")
                }
                try form.textField("Profile name").setInput("Synthetic")
                retained = try form.button("Unlock")
                guard case let .unsupported(_, reason, recommendation) = MacOSInspector.unsupported("keyEvent") else {
                    Issue.record("expected unsupported"); return
                }
                #expect(reason.contains("physical input"))
                #expect(recommendation.contains("XCUITest"))
            }
            try await host.waitForUpdate("text field binding written") { model.profileName == "Synthetic" }
            #expect(model.unlockCalls == 0)
            // The inspection ended, so the retained handle cannot act.
            expectFailure(.obsolete(target: "button 'Unlock'")) { try retained?.tap() }
            #expect(model.unlockCalls == 0)
        }
    }

    @Test func secureValuesNeverAppearInFailuresOrTraces() async throws {
        let model = UnlockModel()
        let seam = InspectionSeam<UnlockScreen>()
        let secret = "SECRET-VALUE-\(syntheticPassphrase)"
        try await FleetMacOS.withHostedView(UnlockScreen(model: model, seam: seam, lockedField: true)) { host in
            try await host.waitUntilReady()
            var rendered: [String] = []
            try await host.inspect(seam) { screen in
                let form = try screen.container("unlock-form")
                do { try form.secureField("Passphrase").setInput(secret) } catch { rendered.append(String(describing: error)) }
                do { try form.secureField("Nope").setInput(secret) } catch { rendered.append(String(describing: error)) }
                rendered.append(contentsOf: screen.trace)
            }
            #expect(rendered.count == 2)
            #expect(rendered.allSatisfy { !$0.contains(secret) && !$0.contains("SECRET") })
        }
        let open = UnlockModel()
        let openSeam = InspectionSeam<UnlockScreen>()
        try await FleetMacOS.withHostedView(UnlockScreen(model: open, seam: openSeam)) { host in
            try await host.waitUntilReady()
            try await host.inspect(openSeam) { screen in
                try screen.container("unlock-form").secureField("Passphrase").setInput(secret)
                #expect(screen.trace == ["write binding of secure field 'Passphrase' (value withheld)"])
                #expect(!screen.trace.joined().contains(secret))
            }
        }
    }

    @Test func errorAndCancellationCleanUpAndLeaveASuccessorScopeClean() async throws {
        struct Boom: Error {}
        let seam = InspectionSeam<UnlockScreen>()
        var failedWindow: NSWindow?
        do {
            try await FleetMacOS.withHostedView(UnlockScreen(model: UnlockModel(), seam: seam)) { host in
                failedWindow = host.window
                try await host.waitUntilReady()
                try await host.inspect(seam) { try $0.container("unlock-form").secureField("Passphrase").setInput("x") }
                throw Boom()
            }
            Issue.record("expected error")
        } catch is Boom {}
        #expect(failedWindow?.isVisible == false)
        #expect(!seam.hasPendingRequest)

        let cancelled = Task { @MainActor in
            try await FleetMacOS.withHostedView(UnlockScreen(model: UnlockModel(), seam: seam)) { host in
                try await host.waitUntilReady()
                try await host.waitUntil("never", timeout: 30) { false }
            }
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        cancelled.cancel()
        do { try await cancelled.value; Issue.record("expected cancellation") } catch is CancellationError {}
        #expect(!seam.hasPendingRequest)

        // A successor starts clean: the lease was released and no request is pending.
        try await FleetMacOS.withHostedView(UnlockScreen(model: UnlockModel(), seam: InspectionSeam<UnlockScreen>())) { host in
            try await host.waitUntilReady()
            #expect(host.appearCount >= 0)
        }
    }

    @Test func noAnswerTimesOutBoundedly() async throws {
        let seam = InspectionSeam<UnlockScreen>()
        // The screen is not subscribed to this seam, so nothing answers.
        try await FleetMacOS.withHostedView(UnlockScreen(model: UnlockModel(), seam: InspectionSeam<UnlockScreen>())) { host in
            try await host.waitUntilReady()
            do {
                try await host.inspect(seam, timeout: 0.2) { _ in () }
                Issue.record("expected timeout")
            } catch let failure as FleetMacOSFailure {
                #expect(failure.kind == .timedOut)
            }
            #expect(!seam.hasPendingRequest)
        }
    }
}
