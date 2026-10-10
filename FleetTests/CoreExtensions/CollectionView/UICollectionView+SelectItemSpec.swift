import XCTest
import Fleet
import Nimble

fileprivate class TestCollectionViewController: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    var rejectedSelections: Set<IndexPath> = []
    var rejectedDeselections: Set<IndexPath> = []
    var events: [String] = []

    func numberOfSections(in collectionView: UICollectionView) -> Int { return 2 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { return 5 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        events.append("shouldSelect \(indexPath.section).\(indexPath.item)")
        return !rejectedSelections.contains(indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        events.append("didSelect \(indexPath.section).\(indexPath.item)")
    }

    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        events.append("shouldDeselect \(indexPath.section).\(indexPath.item)")
        return !rejectedDeselections.contains(indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        events.append("didDeselect \(indexPath.section).\(indexPath.item)")
    }
}

@MainActor
class UICollectionView_SelectItemSpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var controller: TestCollectionViewController!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        controller = TestCollectionViewController()
        subject = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
        subject.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        subject.dataSource = controller
        subject.delegate = controller
        subject.reloadData()

        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    func test_selectItem_selectsTheItemAndCallsDelegate() {
        subject.selectItem(at: IndexPath(item: 1, section: 0))

        expect(self.subject.indexPathsForSelectedItems).to(equal([IndexPath(item: 1, section: 0)]))
        expect(self.controller.events).to(equal(["shouldSelect 0.1", "didSelect 0.1"]))
    }

    func test_selectItem_whenAnotherItemIsSelected_deselectsItFirst() {
        subject.selectItem(at: IndexPath(item: 1, section: 0))
        controller.events = []
        subject.selectItem(at: IndexPath(item: 3, section: 1))

        expect(self.subject.indexPathsForSelectedItems).to(equal([IndexPath(item: 3, section: 1)]))
        expect(self.controller.events).to(equal([
            "shouldSelect 1.3", "shouldDeselect 0.1", "didDeselect 0.1", "didSelect 1.3"
        ]))
    }

    func test_selectItem_whenDelegateRejectsSelection_doesNotSelect() {
        controller.rejectedSelections = [IndexPath(item: 2, section: 0)]
        subject.selectItem(at: IndexPath(item: 2, section: 0))

        expect(self.subject.indexPathsForSelectedItems).to(beEmpty())
        expect(self.controller.events).to(equal(["shouldSelect 0.2"]))
    }

    func test_selectItem_whenAllowingMultipleSelection_keepsPreviousSelection() {
        subject.allowsMultipleSelection = true
        subject.selectItem(at: IndexPath(item: 0, section: 0))
        subject.selectItem(at: IndexPath(item: 1, section: 0))

        expect(Set(self.subject.indexPathsForSelectedItems ?? [])).to(equal([
            IndexPath(item: 0, section: 0), IndexPath(item: 1, section: 0)
        ]))
    }

    func test_selectItem_whenAllowingMultipleSelection_andItemSelected_deselectsIt() {
        subject.allowsMultipleSelection = true
        subject.selectItem(at: IndexPath(item: 0, section: 0))
        controller.events = []
        subject.selectItem(at: IndexPath(item: 0, section: 0))

        expect(self.subject.indexPathsForSelectedItems).to(beEmpty())
        expect(self.controller.events).to(equal(["shouldDeselect 0.0", "didDeselect 0.0"]))
    }

    func test_selectItem_whenDelegateRejectsDeselection_keepsPreviousSelection() {
        subject.selectItem(at: IndexPath(item: 0, section: 0))
        controller.rejectedDeselections = [IndexPath(item: 0, section: 0)]
        controller.events = []
        subject.selectItem(at: IndexPath(item: 1, section: 0))

        expect(self.subject.indexPathsForSelectedItems).to(equal([IndexPath(item: 0, section: 0)]))
        expect(self.controller.events).to(equal(["shouldSelect 0.1", "shouldDeselect 0.0"]))
    }

    func test_selectItem_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { self.subject.selectItem(at: IndexPath(item: 0, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Data source required to select item.", userInfo: nil, closure: nil)
        )
    }

    func test_selectItem_whenSelectionNotAllowed_raisesException() {
        subject.allowsSelection = false
        expect { self.subject.selectItem(at: IndexPath(item: 0, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Interaction with item 0 in section 0 rejected: Collection view does not allow selection.", userInfo: nil, closure: nil)
        )
    }

    func test_selectItem_whenSectionDoesNotExist_raisesException() {
        expect { self.subject.selectItem(at: IndexPath(item: 0, section: 2)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no section 2.", userInfo: nil, closure: nil)
        )
    }

    func test_selectItem_whenItemDoesNotExist_raisesException() {
        expect { self.subject.selectItem(at: IndexPath(item: 5, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item 5 in section 0.", userInfo: nil, closure: nil)
        )
    }
}
