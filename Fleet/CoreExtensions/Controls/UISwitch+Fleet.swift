#if os(iOS)
import UIKit

extension Fleet {
    enum SwitchError: FleetErrorDefinition, Error {
        case controlUnavailable(message: String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot flip UISwitch: \(message)"
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.SwitchError") } }
    }
}

extension UISwitch {
    /**
     Toggles the switch value and fires the appropriate control events.

     - throws:
     A `FleetError` if the switch is hidden, disabled, or if user interaction is disabled.
    */
    public func flip() {
        do {
            try performFlip()
        } catch let error as Fleet.SwitchError {
            FleetError(error).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `flip()`, but reports an unavailable switch as a thrown `FleetFailure`
     (kind `.unavailableInteraction`) instead of raising an `NSException`.
     */
    public func flipOrThrow() throws {
        do {
            try performFlip()
        } catch let error as Fleet.SwitchError {
            throw FleetFailure(error, kind: .unavailableInteraction, action: "flip switch", target: "UISwitch")
        }
    }

    private func performFlip() throws(Fleet.SwitchError) {
        guard isUserInteractionEnabled else {
            throw .controlUnavailable(message: "View does not allow user interaction.")
        }
        guard isEnabled else {
            throw .controlUnavailable(message: "Control is not enabled.")
        }
        guard !isHidden else {
            throw .controlUnavailable(message: "Control is not visible.")
        }

        setOn(!isOn, animated: false)
        sendActions(for: .valueChanged)
        sendActions(for: .touchUpInside)
    }
}

#endif
