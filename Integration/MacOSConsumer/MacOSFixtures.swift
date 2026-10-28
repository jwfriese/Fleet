import AppKit
import FleetMacOS
import SwiftUI

/// Application state injected into the hosted view, standing in for a real model.
@MainActor
final class SessionModel: ObservableObject {
    @Published var unlocked = false
    @Published var draft = "pending"

    func unlock() { unlocked = true }
    func revoke() { unlocked = false; draft = "" }
}

struct SessionScreen: View {
    @ObservedObject var model: SessionModel
    var body: some View {
        VStack {
            Text(model.unlocked ? "account: \(model.draft)" : "locked")
        }
        .frame(width: 200, height: 100)
    }
}

struct ConsumerError: Error, Equatable {}

/// A window the test owns, so a borrowed scope has state to restore.
@MainActor
func makeBorrowedWindow(styleMask: NSWindow.StyleMask = [.titled, .resizable]) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                          styleMask: styleMask, backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    return window
}

/// Yields to the main actor until `condition` holds or the bound passes; no fixed sleeps.
@MainActor
func eventually(_ timeout: TimeInterval = 5, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
}
