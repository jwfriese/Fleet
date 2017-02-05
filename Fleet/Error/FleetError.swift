import Foundation

public class FleetError: NSException {
    init(_ definition: FleetErrorDefinition) {
        super.init(name: definition.name, reason: definition.errorMessage, userInfo: nil)
    }

    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
}

protocol FleetErrorDefinition {
    var errorMessage: String { get }
    var name: NSExceptionName { get }
}
