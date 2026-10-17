import UIKit

extension Fleet {
    enum ButtonError: FleetErrorDefinition, Error {
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
        do {
            try performTap()
        } catch let error as Fleet.ButtonError {
            FleetError(error).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `tap()`, but reports an unavailable button as a thrown `FleetFailure`
     (kind `.unavailableInteraction`) instead of raising an `NSException`.
     */
    public func tapOrThrow() throws {
        do {
            try performTap()
        } catch let error as Fleet.ButtonError {
            throw FleetFailure(error, kind: .unavailableInteraction, action: "tap button", target: "UIButton")
        }
    }

    private func performTap() throws(Fleet.ButtonError) {
        if !isUserInteractionEnabled {
            throw .controlUnavailable("View does not allow user interaction.")
        }
        guard isEnabled else {
            throw .controlUnavailable("Control is not enabled.")
        }
        guard !isHidden else {
            throw .controlUnavailable("Control is not visible.")
        }

        #if os(iOS)
        if showsMenuAsPrimaryAction && menu != nil {
            throw .controlUnavailable("Control presents a menu as its primary action, which tap() cannot open. Invoke the menu element's handler directly.")
        }
        #endif

        sendActions(for: .touchDown)
        sendActions(for: .touchUpInside)
    }
}
