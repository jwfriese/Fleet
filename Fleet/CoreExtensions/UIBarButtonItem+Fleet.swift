import UIKit

extension Fleet {
    enum BarButtonItemError: FleetErrorDefinition {
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
        guard isEnabled else {
            FleetError(Fleet.BarButtonItemError.controlUnavailable(message: "Control is not enabled.")).raise()
            return
        }

        #if os(iOS)
        if action == nil && menu != nil {
            FleetError(Fleet.BarButtonItemError.controlUnavailable(message: "Item presents a menu, which tap() cannot open. Invoke the menu element's handler directly.")).raise()
            return
        }
        #endif

        guard let action = action else {
            if let primaryAction = primaryAction {
                perform(primaryAction)
            } else {
                FleetError(Fleet.BarButtonItemError.noAction(title: safeTitle)).raise()
            }
            return
        }

        if let explicitTarget = target, !explicitTarget.responds(to: action) {
            FleetError(Fleet.BarButtonItemError.unresolvedTarget(title: safeTitle)).raise()
            return
        }

        let resolvedTarget = target ?? Self.firstResponderTarget(forAction: action, sender: self)
        let handled = resolvedTarget.map {
            UIApplication.shared.sendAction(action, to: $0, from: self, for: nil)
        } ?? false
        if !handled {
            if target == nil {
                FleetError(Fleet.BarButtonItemError.noTarget(title: safeTitle)).raise()
            } else {
                FleetError(Fleet.BarButtonItemError.unresolvedTarget(title: safeTitle)).raise()
            }
        }
    }

    private func perform(_ primaryAction: UIAction) {
        if #available(iOS 16.0, tvOS 16.0, *) {
            primaryAction.performWithSender(self, target: nil)
        } else {
            FleetError(Fleet.BarButtonItemError.controlUnavailable(message: "Tapping an item created with a primary action requires iOS or tvOS 16.")).raise()
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
