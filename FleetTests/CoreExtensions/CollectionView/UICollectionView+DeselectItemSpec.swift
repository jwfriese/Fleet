import XCTest
import Fleet
import Nimble

fileprivate class DeselectingController: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    var rejectedDeselections: Set<IndexPath> = []
    var events: [String] = []

    func numberOfSections(in collectionView: UICollectionView) -> Int { return 1 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { return 3 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        events.append("shouldDeselect \(indexPath.item)")
        return !rejectedDeselections.contains(indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        events.append("didDeselect \(indexPath.item)")
    }
}

@MainActor
class UICollectionView_DeselectItemSpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var controller: DeselectingController!
    let first = IndexPath(item: 0, section: 0)

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        controller = DeselectingController()
        subject = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
        subject.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        subject.dataSource = controller
        subject.delegate = controller
        subject.reloadData()

        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        subject.dataSource = nil
        subject.delegate = nil
        subject = nil
        try await super.tearDown()
    }

    func test_deselectItem_deselectsAndCallsDelegateInOrder() {
        subject.selectItem(at: first)
        controller.events = []
        subject.deselectItem(at: first)

        expect(self.subject.indexPathsForSelectedItems).to(beEmpty())
        expect(self.controller.events).to(equal(["shouldDeselect 0", "didDeselect 0"]))
    }

    func test_deselectItem_whenDelegateRefuses_keepsSelectionAndSkipsDidDeselect() {
        subject.selectItem(at: first)
        controller.rejectedDeselections = [first]
        controller.events = []
        subject.deselectItem(at: first)

        expect(self.subject.indexPathsForSelectedItems).to(equal([first]))
        expect(self.controller.events).to(equal(["shouldDeselect 0"]))
    }

    func test_deselectItem_leavesOtherSelectedItemsAlone() {
        subject.allowsMultipleSelection = true
        subject.selectItem(at: first)
        subject.selectItem(at: IndexPath(item: 1, section: 0))
        subject.deselectItem(at: first)

        expect(self.subject.indexPathsForSelectedItems).to(equal([IndexPath(item: 1, section: 0)]))
    }

    func test_deselectItem_whenItemIsNotSelected_raisesBeforeCallingDelegate() {
        expect { self.subject.deselectItem(at: self.first) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Interaction with item 0 in section 0 rejected: Item is not selected.", userInfo: nil, closure: nil)
        )
        expect(self.controller.events).to(beEmpty())
    }

    func test_deselectItem_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { self.subject.deselectItem(at: self.first) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Data source required to deselect item.", userInfo: nil, closure: nil)
        )
    }

    func test_deselectItem_whenSelectionNotAllowed_raisesException() {
        subject.selectItem(at: first)
        subject.allowsSelection = false
        expect { self.subject.deselectItem(at: self.first) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Interaction with item 0 in section 0 rejected: Collection view does not allow selection.", userInfo: nil, closure: nil)
        )
        expect(self.controller.events).to(beEmpty())
    }

    func test_deselectItem_whenIndicesAreInvalid_raisesWithoutChangingSelection() {
        subject.selectItem(at: first)
        expect { self.subject.deselectItem(at: IndexPath(item: 0, section: -1)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no section -1.", userInfo: nil, closure: nil)
        )
        expect { self.subject.deselectItem(at: IndexPath(item: -1, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item -1 in section 0.", userInfo: nil, closure: nil)
        )
        expect { self.subject.deselectItem(at: IndexPath(item: 3, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item 3 in section 0.", userInfo: nil, closure: nil)
        )
        expect(self.subject.indexPathsForSelectedItems).to(equal([first]))
    }
}
