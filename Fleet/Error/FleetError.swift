import Foundation

public class FleetError: NSException {
    init(_ definition: FleetErrorDefinition) {
        super.init(name: definition.name, reason: definition.errorMessage, userInfo: ["description" : definition.errorMessage])
    }

    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
}

protocol FleetErrorDefinition {
    var errorMessage: String { get }
    var name: NSExceptionName { get }
}

extension FleetFailure {
    /// Bridges a legacy exception definition to the recoverable error, keeping its message as the reason.
    init(_ definition: FleetErrorDefinition, kind: Kind, action: String, target: String) {
        self.init(kind: kind, action: action, target: target,
                  state: definition.errorMessage, reason: "See the state for what prevented the action.")
    }
}
