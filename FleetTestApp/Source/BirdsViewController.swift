import UIKit

private let BirdsTableViewCellIdentifier = "BirdsTableViewCell"

struct ContextualActionCall {
    let title: String
    let indexPath: IndexPath
    let sourceView: UIView
}

class BirdsViewController: UIViewController {
    var contextualActionCalls: [ContextualActionCall] = []

    var willSelectRowCallCount: Int = 0
    var didSelectRowCallCount: Int = 0

    var willSelectRowCallArgs: [IndexPath] = [IndexPath]()
    var didSelectRowCallArgs: [IndexPath] = [IndexPath]()

    var willDeselectRowCallCount: Int = 0
    var didDeselectRowCallCount: Int = 0

    var willDeselectRowCallArgs: [IndexPath] = [IndexPath]()
    var didDeselectRowCallArgs: [IndexPath] = [IndexPath]()

    var willBeginEditingRowCallArgs: [IndexPath] = [IndexPath]()
    var didEndEditingRowCallArgs: [IndexPath] = [IndexPath]()

    @IBOutlet weak var birdsTableView: UITableView?

    fileprivate var birdTypes: [String] {
        get {
            return [
                "Pigeon",
                "Duck",
                "Goose",
                "Swan",
                "Crow",
                "Pelican",
                "Hawk",
                "Eagle",
                "Parakeet",
                "Robin",
                "Peacock",
                "Pheasant",
                "Dove",
                "Seagull",
                "Owl",
                "Hummingbird",
                "Penguin",
                "Crane",
                "Flamingo",
                "Toucan",
                "Sparrow",
            ]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        birdsTableView?.dataSource = self
        birdsTableView?.delegate = self
        birdsTableView?.register(UITableViewCell.self, forCellReuseIdentifier: BirdsTableViewCellIdentifier)
    }
}

extension BirdsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        willSelectRowCallCount += 1
        willSelectRowCallArgs.append(indexPath)

        let birdType = birdTypes[indexPath.row]
        if birdType == "Pigeon" {
            return nil
        } else if birdType == "Goose" {
            return IndexPath(row: 1, section: 0)
        }

        return indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectRowCallCount += 1
        didSelectRowCallArgs.append(indexPath)

        let birdType = birdTypes[indexPath.row]
        let messageString = "You selected \(birdType)"
        let alert = UIAlertController(title: "Bird Selected (Selection \(willSelectRowCallCount))", message: messageString, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: ":D", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        willDeselectRowCallCount += 1
        willDeselectRowCallArgs.append(indexPath)

        let birdType = birdTypes[indexPath.row]
        if birdType == "Crow" {
            return nil
        } else if birdType == "Hawk" {
            return IndexPath(row: 5, section: 0)
        }

        return indexPath
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        didDeselectRowCallCount += 1
        didDeselectRowCallArgs.append(indexPath)
    }
}

extension BirdsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return birdTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = birdsTableView?.dequeueReusableCell(withIdentifier: BirdsTableViewCellIdentifier, for: indexPath)
        cell?.textLabel?.text = birdTypes[indexPath.row]
        return cell!
    }

    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        willBeginEditingRowCallArgs.append(indexPath)
    }

    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        didEndEditingRowCallArgs.append(indexPath!)
    }

#if os(iOS)
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let pin = UIContextualAction(style: .normal, title: "Pin") { [weak self] _, sourceView, completion in
            self?.contextualActionCalls.append(ContextualActionCall(title: "Pin", indexPath: indexPath, sourceView: sourceView))
            completion(true)
        }
        let refuse = UIContextualAction(style: .destructive, title: "Refuse") { [weak self] _, sourceView, completion in
            self?.contextualActionCalls.append(ContextualActionCall(title: "Refuse", indexPath: indexPath, sourceView: sourceView))
            completion(false)
        }
        return UISwipeActionsConfiguration(actions: [pin, refuse])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.row == 4 {
            return nil
        }

        if indexPath.row == 5 {
            let later = UIContextualAction(style: .normal, title: "Later") { [weak self] _, sourceView, completion in
                self?.contextualActionCalls.append(ContextualActionCall(title: "Later", indexPath: indexPath, sourceView: sourceView))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { completion(true) }
            }
            let never = UIContextualAction(style: .normal, title: "Never") { [weak self] _, sourceView, _ in
                self?.contextualActionCalls.append(ContextualActionCall(title: "Never", indexPath: indexPath, sourceView: sourceView))
            }
            let twiceA = UIContextualAction(style: .normal, title: "Twice") { [weak self] _, sourceView, completion in
                self?.contextualActionCalls.append(ContextualActionCall(title: "Twice (first)", indexPath: indexPath, sourceView: sourceView))
                completion(true)
            }
            let twiceB = UIContextualAction(style: .normal, title: "Twice") { [weak self] _, sourceView, completion in
                self?.contextualActionCalls.append(ContextualActionCall(title: "Twice (second)", indexPath: indexPath, sourceView: sourceView))
                completion(true)
            }
            return UISwipeActionsConfiguration(actions: [later, never, twiceA, twiceB])
        }

        let actions = ["One", "Two", "Three"].map { title in
            UIContextualAction(style: .normal, title: title) { [weak self] _, sourceView, completion in
                guard let self = self else { return completion(false) }
                self.contextualActionCalls.append(ContextualActionCall(title: title, indexPath: indexPath, sourceView: sourceView))
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "", message: "\(title) tapped at row \(indexPath.row)", preferredStyle: .alert)
                    self.present(alert, animated: false, completion: nil)
                }
                completion(true)
            }
        }
        return UISwipeActionsConfiguration(actions: actions)
    }
#endif

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) { }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.row == 3 {
            return false
        }

        return true
    }
}
