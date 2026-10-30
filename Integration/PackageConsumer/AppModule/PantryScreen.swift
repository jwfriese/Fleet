import Combine
import SwiftUI

/// The application-owned inspection seam: a main-actor rendezvous the *mounted* screen answers.
/// A request is single-slot and always cleared by `run`, so no callback outlives its request.
@MainActor
public final class InspectionSeam<V: View> {
    public let notice = PassthroughSubject<Void, Never>()
    private var pending: (@MainActor (V) -> Void)?
    public var hasPendingRequest: Bool { pending != nil }

    public init() {}

    public func visit(_ view: V) {
        let request = pending
        pending = nil
        request?(view)
    }

    /// Delivers `request` to the mounted instance synchronously. Returns `false` when none answered.
    public func run(_ request: @escaping @MainActor (V) -> Void) -> Bool {
        var answered = false
        pending = { view in
            answered = true
            request(view)
        }
        notice.send()
        pending = nil
        return answered
    }
}

/// View-only defects for negative controls. The model and any metadata a test derives from it stay correct.
public enum PantryDefect: Sendable {
    /// Each Remove button removes the *next* row.
    case crossedButtonBinding
    /// The rows are drawn in reverse order.
    case reversedRows
    /// The second row is drawn with the last row's swatch.
    case wrongSwatch
}

public struct PantryScreen: View {
    @ObservedObject var model: PantryModel
    let seam: InspectionSeam<PantryScreen>
    let defect: PantryDefect?

    public init(model: PantryModel, seam: InspectionSeam<PantryScreen>, defect: PantryDefect? = nil) {
        self.model = model
        self.seam = seam
        self.defect = defect
    }

    private var rows: [PantryItem] {
        defect == .reversedRows ? model.items.reversed() : model.items
    }

    private func swatch(_ item: PantryItem, at index: Int) -> Swatch {
        defect == .wrongSwatch && index == 1 ? .blue : item.swatch
    }

    private func target(_ index: Int) -> String {
        let items = rows
        if defect == .crossedButtonBinding { return items[(index + 1) % items.count].id }
        return items[index].id
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let items = rows
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack {
                    let rgb = swatch(item, at: index).rgb
                    Rectangle()
                        .fill(Color(red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255))
                        .frame(width: 24, height: 24)
                    Text(item.name)
                    Spacer()
                    Button("Remove") { model.remove(id: target(index)) }
                }
                .accessibilityIdentifier("row.\(item.id)")
            }
            if let message = model.errorMessage {
                Text(message).accessibilityIdentifier("feedback")
            } else if let message = model.confirmation {
                Text(message).accessibilityIdentifier("feedback")
            }
        }
        .padding()
        .onReceive(seam.notice) { seam.visit(self) }
    }
}
