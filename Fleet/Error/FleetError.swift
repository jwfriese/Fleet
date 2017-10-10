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
