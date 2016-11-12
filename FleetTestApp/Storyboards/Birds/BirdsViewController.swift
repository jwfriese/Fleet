import UIKit

private let BirdsTableViewCellIdentifier = "BirdsTableViewCell"

class BirdsViewController: UIViewController {
    var willSelectRowCallCount: Int = 0
    var didSelectRowCallCount: Int = 0

    var willSelectRowCallArgs: [IndexPath] = [IndexPath]()
    var didSelectRowCallArgs: [IndexPath] = [IndexPath]()

    var willDeselectRowCallCount: Int = 0
    var didDeselectRowCallCount: Int = 0

    var willDeselectRowCallArgs: [IndexPath] = [IndexPath]()
    var didDeselectRowCallArgs: [IndexPath] = [IndexPath]()

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
}
