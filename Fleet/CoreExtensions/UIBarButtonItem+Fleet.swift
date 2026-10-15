import UIKit

extension Fleet {
    enum BarButtonItemError: FleetErrorDefinition, Error {
        case controlUnavailable(message: String)
        case noTarget(title: String)
        case noAction(title: String)
        case unresolvedTarget(title: String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot tap UIBarButtonItem: \(message)"
            case .noTarget(let title):
                return "Attempted to tap UIBarButtonItem (title='\(title)') with no associated target, and no responder in the responder chain handles the action."
            case .unresolvedTarget(let title):
                return "Attempted to tap UIBarButtonItem (title='\(title)') whose target does not respond to the action."
            case .noAction(let title):
                return "Attempted to tap UIBarButtonItem (title='\(title)') with no associated action."
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.BarButtonItemError") } }
    }
}

extension UIBarButtonItem {

    /**
     Mimic a user tap on the bar button, firing any associated events.

     The action is sent with `UIApplication.sendAction(_:to:from:for:)`, as UIKit does
     for bar button items: the item is the sender, and an item without a target
     sends the action up the responder chain from the first responder. Items created
     with `init(primaryAction:)` run their action exactly once.

     - throws:
     A `FleetError` if the bar button is not enabled, if it only presents a menu,
     if it does not have an action, if it has no target and no responder in the chain
     handles the action, or if its target does not respond to the action.
     */
    public func tap() {
        do {
            try performTap()
        } catch let error as Fleet.BarButtonItemError {
            FleetError(error).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `tap()`, but reports failures as a thrown `FleetFailure` instead of raising an
     `NSException`: `.unavailableInteraction` for a disabled, menu-only, or (before iOS/tvOS 16)
     primary-action item, and `.invalidSetup` for a missing action or unresolved target.
     */
    public func tapOrThrow() throws {
        do {
            try performTap()
        } catch let error as Fleet.BarButtonItemError {
            let kind: FleetFailure.Kind
            switch error {
            case .controlUnavailable: kind = .unavailableInteraction
            case .noTarget, .noAction, .unresolvedTarget: kind = .invalidSetup
            }
            throw FleetFailure(error, kind: kind, action: "tap bar button item", target: "UIBarButtonItem '\(safeTitle)'")
        }
    }

    private func performTap() throws(Fleet.BarButtonItemError) {
        guard isEnabled else {
            throw .controlUnavailable(message: "Control is not enabled.")
        }

        // An item built with `init(primaryAction:menu:)` has a nil `action` but runs its primary
        // action on tap; only an item with a menu and no primary action can merely open the menu.
        #if os(iOS)
        if action == nil && primaryAction == nil && menu != nil {
            throw .controlUnavailable(message: "Item presents a menu, which tap() cannot open. Invoke the menu element's handler directly.")
        }
        #endif

        guard let action = action else {
            guard let primaryAction = primaryAction else {
                throw .noAction(title: safeTitle)
            }
            if #available(iOS 16.0, tvOS 16.0, *) {
                primaryAction.performWithSender(self, target: nil)
            } else {
                throw .controlUnavailable(message: "Tapping an item created with a primary action requires iOS or tvOS 16.")
            }
            return
        }

        if let explicitTarget = target, !explicitTarget.responds(to: action) {
            throw .unresolvedTarget(title: safeTitle)
        }

        let resolvedTarget = target ?? Self.firstResponderTarget(forAction: action, sender: self)
        let handled = resolvedTarget.map {
            UIApplication.shared.sendAction(action, to: $0, from: self, for: nil)
        } ?? false
        if !handled {
            throw target == nil ? .noTarget(title: safeTitle) : .unresolvedTarget(title: safeTitle)
        }
    }

    // `UIApplication.sendAction(_:to:from:for:)` with a nil target does not reliably find
    // the first responder in hosts without an active scene, so the chain is started explicitly.
    private static func firstResponderTarget(forAction action: Selector, sender: Any?) -> Any? {
        guard let window = UIApplication.shared.keyWindow,
              let responder = firstResponder(in: window) else { return nil }
        return responder.target(forAction: action, withSender: sender)
    }

    private static func firstResponder(in window: UIWindow) -> UIResponder? {
        func search(_ view: UIView) -> UIResponder? {
            if view.isFirstResponder { return view }
            for subview in view.subviews {
                if let found = search(subview) { return found }
            }
            return nil
        }
        func search(_ controller: UIViewController) -> UIResponder? {
            if controller.isFirstResponder { return controller }
            if let found = controller.presentedViewController.flatMap(search(_:)) { return found }
            for child in controller.children {
                if let found = search(child) { return found }
            }
            return nil
        }
        if let controller = window.rootViewController, let found = search(controller) { return found }
        return search(window)
    }

    fileprivate var safeTitle: String {
        get {
            if let title = title {
                return title
            }

            return "<No Title>"
        }
    }
}
