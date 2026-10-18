import UIKit

/// Host for the UIKit reference traces. It deliberately does not link Fleet: it records what UIKit's own
/// touch (iOS) and remote (tvOS) handling sends to a collection-view delegate, so the recorded sequences can be
/// compared with the sequences Fleet's `selectItem(at:)` models.
@main
final class TraceAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = TraceViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class TraceCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        backgroundColor = .gray
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        backgroundColor = isFocused ? .blue : (isSelected ? .green : .gray)
    }
}

/// Launch arguments choose the delegate's refusals: `-refuseSelect <item>` and `-refuseDeselect <item>`.
final class TraceViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let traceLabel = UILabel()
    private var events: [String] = []
    private let refusedSelect = TraceViewController.argument("-refuseSelect")
    private let refusedDeselect = TraceViewController.argument("-refuseDeselect")
    private var collectionView: UICollectionView!

    private static func argument(_ name: String) -> Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 20
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(TraceCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        traceLabel.accessibilityIdentifier = "trace"
        traceLabel.text = "(none)"
        traceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        view.addSubview(traceLabel)
        NSLayoutConstraint.activate([
            traceLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            traceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            traceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: traceLabel.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 140),
        ])
    }

    private func record(_ name: String, _ indexPath: IndexPath) {
        events.append("\(name) \(indexPath.section).\(indexPath.item)")
        traceLabel.text = events.joined(separator: ", ")
        traceLabel.accessibilityLabel = traceLabel.text
        traceLabel.accessibilityValue = "\(events.count)"
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 4 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.accessibilityIdentifier = "item-\(indexPath.item)"
        cell.accessibilityLabel = "item-\(indexPath.item)"
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        record("shouldSelect", indexPath)
        return indexPath.item != refusedSelect
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        record("didSelect", indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        record("shouldDeselect", indexPath)
        return indexPath.item != refusedDeselect
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        record("didDeselect", indexPath)
    }
}
