import Combine
import Foundation

// A generic application module compiled separately from the test bundle. It imports neither Fleet,
// FleetRuntime nor ViewInspector, and has no conditional import of them. The only seam it owns is the
// neutral `InspectionSeam` in PantryScreen.swift. It does not certify any downstream application.

/// A fixed row color the screen draws beside each item. Tests read it from pixels of the mounted view.
public enum Swatch: String, Sendable, CaseIterable {
    case red, green, blue

    /// The 8-bit sRGB components the screen paints.
    public var rgb: (red: Int, green: Int, blue: Int) {
        switch self {
        case .red: (230, 25, 25)
        case .green: (25, 200, 25)
        case .blue: (25, 25, 230)
        }
    }
}

public struct PantryItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let swatch: Swatch
    public init(id: String, name: String, swatch: Swatch) {
        self.id = id
        self.name = name
        self.swatch = swatch
    }
}

/// The application's service boundary. Tests inject a fake whose response they hold and release.
@MainActor
public protocol PantryService: AnyObject {
    func remove(id: String) async throws
}

/// Optimistic removal: the row leaves immediately, and returns at its original position if the service fails.
@MainActor
public final class PantryModel: ObservableObject {
    @Published public private(set) var items: [PantryItem]
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var confirmation: String?
    @Published public private(set) var pendingCount = 0

    private let canonical: [PantryItem]
    private var removing: Set<String> = []
    private var tasks: [String: Task<Void, Never>] = [:]
    private let service: PantryService

    public init(items: [PantryItem], service: PantryService) {
        self.items = items
        canonical = items
        self.service = service
    }

    public func remove(id: String) {
        guard !removing.contains(id), let item = canonical.first(where: { $0.id == id }) else { return }
        removing.insert(id)
        pendingCount += 1
        errorMessage = nil
        confirmation = nil
        publish()
        tasks[id] = Task { @MainActor in
            defer {
                pendingCount -= 1
                tasks[id] = nil
            }
            do {
                try await service.remove(id: id)
                confirmation = "Removed \(item.name)"
            } catch {
                removing.remove(id)
                errorMessage = "Could not remove \(item.name)"
                publish()
            }
        }
    }

    /// Cancels work still in flight when the owning test scope ends.
    public func shutdown() {
        tasks.values.forEach { $0.cancel() }
    }

    private func publish() {
        items = canonical.filter { !removing.contains($0.id) }
    }
}
