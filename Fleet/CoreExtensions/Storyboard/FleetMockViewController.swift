import UIKit

/**
 A functionally-inert view controller that Fleet uses for its
 general-purpose storyboard mocking. This view controller overrides
 its `viewDidLoad`, `viewWillAppear(_:)`, `viewDidAppear(_:)`,
 `viewWillDisappear(_:)`, and `viewDidDisappear(_:)` methods so that
 they take no action.
 */
public class FleetMockViewController: UIViewController {
    public override func viewDidLoad() {}
    public override func viewWillAppear(_ animated: Bool) {}
    public override func viewDidAppear(_ animated: Bool) {}
    public override func viewWillDisappear(_ animated: Bool) {}
    public override func viewDidDisappear(_ animated: Bool) {}
}
