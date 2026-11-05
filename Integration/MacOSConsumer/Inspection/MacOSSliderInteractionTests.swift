import FleetMacOS
import SwiftUI
import Testing
import ViewInspector

// Synthetic fixture: a replay transport whose slider is bound to a fake player. No downstream
// application is modeled, and no audio is played.

@MainActor
final class FakePlayer: ObservableObject {
    @Published private(set) var position = 0.0
    private(set) var seeks: [Double] = []
    func seek(to time: Double) { seeks.append(time); position = time }
}

struct ReplayTransport: View {
    @ObservedObject var player: FakePlayer
    let seam: InspectionSeam<ReplayTransport>
    var lockedSlider = false
    var duplicateSlider = false
    var title = "Replay"

    var body: some View {
        VStack {
            Text(title)
            Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }), in: 0...120)
                .accessibilityIdentifier("voice.playback.position")
                .disabled(lockedSlider)
            if duplicateSlider {
                Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }), in: 0...120)
                    .accessibilityIdentifier("voice.playback.position")
            }
        }
        .frame(width: 320, height: 120)
        .onReceive(seam.notice) { seam.visit(self) }
    }
}

@MainActor
private func expectFailure(_ expected: MacOSQueryFailure, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(expected)") } catch let failure as MacOSQueryFailure {
        #expect(failure == expected)
    } catch { Issue.record("unexpected error \(error)") }
}

@MainActor
@Suite("Mounted macOS Slider interaction", .serialized)
struct MacOSSliderInteractionTests {
    private let target = "slider 'voice.playback.position'"

    @Test func settingTheBindingReachesTheSeekActionAndRequeryReadsIt() async throws {
        let player = FakePlayer()
        let seam = InspectionSeam<ReplayTransport>()
        try await FleetMacOS.withHostedView(ReplayTransport(player: player, seam: seam)) { host in
            try await host.waitUntilReady()
            try await host.inspect(seam) { screen in
                let slider = try screen.slider(identifier: "voice.playback.position", in: 0...120)
                let initial = try slider.value()
                #expect(initial == 0)
                let kind = try slider.setValue(45)
                #expect(kind == .writesBinding)
                #expect(screen.trace == ["write binding of \(target) to 45.0"])
            }
            #expect(player.seeks == [45])
            try await host.inspect(seam) { screen in
                let value = try screen.slider(identifier: "voice.playback.position", in: 0...120).value()
                #expect(abs(value - 45) < 1e-9)
            }
        }
        #expect(!seam.hasPendingRequest)
    }

    @Test func aValueOutsideTheDeclaredRangeIsRefusedWithoutSeeking() async throws {
        let player = FakePlayer()
        let seam = InspectionSeam<ReplayTransport>()
        try await FleetMacOS.withHostedView(ReplayTransport(player: player, seam: seam)) { host in
            try await host.waitUntilReady()
            try await host.inspect(seam) { screen in
                let slider = try screen.slider(identifier: "voice.playback.position", in: 0...120)
                for bad in [-1.0, 121.0] {
                    do { try slider.setValue(bad); Issue.record("expected unsupported") } catch let failure as MacOSQueryFailure {
                        guard case .unsupported = failure else { Issue.record("unexpected \(failure)"); continue }
                    } catch { Issue.record("unexpected error \(error)") }
                }
            }
            #expect(player.seeks.isEmpty)
        }
    }

    @Test func absentAmbiguousDisabledAndObsoleteStayDistinct() async throws {
        let duplicatePlayer = FakePlayer()
        let seam = InspectionSeam<ReplayTransport>()
        try await FleetMacOS.withHostedView(ReplayTransport(player: duplicatePlayer, seam: seam, duplicateSlider: true)) { host in
            try await host.waitUntilReady()
            try await host.inspect(seam) { screen in
                expectFailure(.ambiguous(target: target, scope: "screen", count: 2)) { _ = try screen.slider(identifier: "voice.playback.position", in: 0...120) }
                expectFailure(.absent(target: "slider 'missing'", scope: "screen")) { _ = try screen.slider(identifier: "missing", in: 0...120) }
            }
        }
        #expect(duplicatePlayer.seeks.isEmpty)

        let player = FakePlayer()
        let lockedSeam = InspectionSeam<ReplayTransport>()
        try await FleetMacOS.withHostedView(ReplayTransport(player: player, seam: lockedSeam, lockedSlider: true)) { host in
            try await host.waitUntilReady()
            var retained: SliderHandle?
            try await host.inspect(lockedSeam) { screen in
                let slider = try screen.slider(identifier: "voice.playback.position", in: 0...120)
                #expect(!slider.isEnabled)
                expectFailure(.disabled(target: target, scope: "screen")) { try slider.setValue(10) }
                let value = try slider.value()
                #expect(value == 0)
                retained = slider
            }
            #expect(player.seeks.isEmpty)
            expectFailure(.obsolete(target: target)) { _ = try retained?.value() }
            expectFailure(.obsolete(target: target)) { try retained?.setValue(20) }
            #expect(player.seeks.isEmpty)
        }
    }

    @Test func aHandleFromAnEarlierScreenCannotSeekASuccessorScreen() async throws {
        let firstSeam = InspectionSeam<ReplayTransport>()
        var retained: SliderHandle?
        try await FleetMacOS.withHostedView(ReplayTransport(player: FakePlayer(), seam: firstSeam)) { host in
            try await host.waitUntilReady()
            try await host.inspect(firstSeam) { retained = try $0.slider(identifier: "voice.playback.position", in: 0...120) }
        }
        let successor = FakePlayer()
        let successorSeam = InspectionSeam<ReplayTransport>()
        try await FleetMacOS.withHostedView(ReplayTransport(player: successor, seam: successorSeam, title: "Next")) { host in
            try await host.waitUntilReady()
            expectFailure(.obsolete(target: target)) { try retained?.setValue(99) }
            #expect(successor.seeks.isEmpty)
            try await host.inspect(successorSeam) { screen in
                try screen.slider(identifier: "voice.playback.position", in: 0...120).setValue(15)
            }
            #expect(successor.seeks == [15])
        }
    }
}
