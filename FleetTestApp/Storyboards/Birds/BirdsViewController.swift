import UIKit

private let BirdsTableViewCellIdentifier = "BirdsTableViewCell"

class BirdsViewController: UIViewController {
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let birdType = birdTypes[indexPath.row]
        let messageString = "You selected \(birdType)"
        let alert = UIAlertController(title: "Bird Selected", message: messageString, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: ":D", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
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
