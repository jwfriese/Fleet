import UIKit

extension Fleet {
    enum ButtonError: FleetErrorDefinition {
        case controlUnavailable(String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot tap UIButton: \(message)"
            }
        }

        var name: NSExceptionName { get { return NSExceptionName("Fleet.ButtonError") } }
    }
}

extension UIButton {

    /**
     Mimics a user tap on the button, firing all appropriate control events.

     Handlers registered with `addTarget(_:action:for:)`, `addAction(_:for:)`, and the
     button's `primaryAction` each run exactly once. Buttons that present a menu as
     their primary action are rejected rather than tapped, because tapping them opens
     the menu instead of sending control events.

     - throws:
     A `FleetError` if the button is hidden, disabled, does not allow user interaction,
     or presents a menu as its primary action.
     */
    public func tap() {
        if !isUserInteractionEnabled {
            FleetError(Fleet.ButtonError.controlUnavailable("View does not allow user interaction.")).raise()
            return
        }
        guard isEnabled else {
            FleetError(Fleet.ButtonError.controlUnavailable("Control is not enabled.")).raise()
            return
        }
        guard !isHidden else {
            FleetError(Fleet.ButtonError.controlUnavailable("Control is not visible.")).raise()
            return
        }

        #if os(iOS)
        if showsMenuAsPrimaryAction && menu != nil {
            FleetError(Fleet.ButtonError.controlUnavailable("Control presents a menu as its primary action, which tap() cannot open. Invoke the menu element's handler directly.")).raise()
            return
        }
        #endif

        sendActions(for: .touchDown)
        sendActions(for: .touchUpInside)
    }
}
