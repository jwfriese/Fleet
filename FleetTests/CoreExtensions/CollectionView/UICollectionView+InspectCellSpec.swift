import XCTest
import Fleet
import Nimble

fileprivate class LabeledCell: UICollectionViewCell {
    var label: String?
}

fileprivate class OtherCell: UICollectionViewCell {}

fileprivate class OrdinaryDataSource: NSObject, UICollectionViewDataSource {
    let items = (0..<60).map { "item \($0)" }
    var cellProviderCalls = 0

    func numberOfSections(in collectionView: UICollectionView) -> Int { return 1 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { return items.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        cellProviderCalls += 1
        if indexPath.item == 1 {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "other", for: indexPath)
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "labeled", for: indexPath) as! LabeledCell
        cell.label = items[indexPath.item]
        return cell
    }
}

@MainActor
private func makeCollectionView() -> UICollectionView {
    let layout = UICollectionViewFlowLayout()
    layout.itemSize = CGSize(width: 300, height: 100)
    let view = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
    view.register(LabeledCell.self, forCellWithReuseIdentifier: "labeled")
    view.register(OtherCell.self, forCellWithReuseIdentifier: "other")
    return view
}

@MainActor
class UICollectionView_InspectCellSpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var dataSource: OrdinaryDataSource!
    let visible = IndexPath(item: 0, section: 0)
    let offscreen = IndexPath(item: 50, section: 0)

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        dataSource = OrdinaryDataSource()
        subject = makeCollectionView()
        subject.dataSource = dataSource
        subject.reloadData()
        try! Test.embedViewIntoMainApplicationWindow(subject)
        subject.layoutIfNeeded()
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        subject.dataSource = nil
        subject.delegate = nil
        subject = nil
        try await super.tearDown()
    }

    func test_displayedCell_whenOnScreen_returnsTheLiveCell() {
        let cell = subject.displayedCell(at: visible)
        expect(cell).toNot(beNil())
        expect(cell).to(beIdenticalTo(subject.cellForItem(at: visible)))
        expect(cell).to(beIdenticalTo(subject.fetchCell(at: visible)))
    }

    func test_displayedCell_whenOffscreen_returnsNilWithoutScrolling() {
        let offsetBefore = subject.contentOffset
        expect(self.subject.displayedCell(at: self.offscreen)).to(beNil())
        expect(self.subject.contentOffset).to(equal(offsetBefore))
    }

    func test_displayedCell_asType_returnsTypedCell() {
        expect(self.subject.displayedCell(at: self.visible, asType: LabeledCell.self)?.label).to(equal("item 0"))
    }

    func test_displayedCell_asType_whenOffscreen_returnsNil() {
        expect(self.subject.displayedCell(at: self.offscreen, asType: LabeledCell.self)).to(beNil())
    }

    func test_displayedCell_asType_whenTypeMismatches_raisesDescriptiveException() {
        expect { _ = self.subject.displayedCell(at: IndexPath(item: 1, section: 0), asType: LabeledCell.self) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Cell at item 1 in section 0 is of type `OtherCell` (wanted `LabeledCell`).", userInfo: nil, closure: nil)
        )
    }

    func test_displayedCell_afterReload_isANewLiveCellOrSameReusedInstance() {
        dataSource.cellProviderCalls = 0
        subject.reloadData()
        subject.layoutIfNeeded()
        expect(self.dataSource.cellProviderCalls).to(beGreaterThan(0))
        expect(self.subject.displayedCell(at: self.visible, asType: LabeledCell.self)?.label).to(equal("item 0"))
    }

    func test_displayedCell_validatesIndexPaths() {
        expect { _ = self.subject.displayedCell(at: IndexPath(item: 60, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item 60 in section 0.", userInfo: nil, closure: nil)
        )
        expect { _ = self.subject.displayedCell(at: IndexPath(item: 0, section: -1)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no section -1.", userInfo: nil, closure: nil)
        )
        subject.dataSource = nil
        expect { _ = self.subject.displayedCell(at: self.visible) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Data source required to inspect cells.", userInfo: nil, closure: nil)
        )
    }

    func test_configuredCell_forOffscreenItem_buildsACellThatIsNotDisplayed() {
        let offsetBefore = subject.contentOffset
        let cell = subject.configuredCell(at: offscreen, asType: LabeledCell.self)

        expect(cell.label).to(equal("item 50"))
        expect(self.subject.cellForItem(at: self.offscreen)).to(beNil())
        expect(self.subject.contentOffset).to(equal(offsetBefore))
    }

    func test_configuredCell_forVisibleItem_isNotTheDisplayedCell() {
        let configured = subject.configuredCell(at: visible)
        expect(configured).toNot(beIdenticalTo(self.subject.displayedCell(at: self.visible)))
    }

    func test_configuredCell_runsTheDataSourceEachTime() {
        dataSource.cellProviderCalls = 0
        _ = subject.configuredCell(at: offscreen)
        _ = subject.configuredCell(at: offscreen)
        expect(self.dataSource.cellProviderCalls).to(equal(2))
    }

    func test_configuredCell_asType_whenTypeMismatches_raisesDescriptiveException() {
        expect { _ = self.subject.configuredCell(at: IndexPath(item: 1, section: 0), asType: LabeledCell.self) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Cell at item 1 in section 0 is of type `OtherCell` (wanted `LabeledCell`).", userInfo: nil, closure: nil)
        )
    }

    func test_configuredCell_validatesIndexPathsBeforeCallingDataSource() {
        dataSource.cellProviderCalls = 0
        expect { _ = self.subject.configuredCell(at: IndexPath(item: 60, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item 60 in section 0.", userInfo: nil, closure: nil)
        )
        expect { _ = self.subject.configuredCell(at: IndexPath(item: -1, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item -1 in section 0.", userInfo: nil, closure: nil)
        )
        expect(self.dataSource.cellProviderCalls).to(equal(0))
        subject.dataSource = nil
        expect { _ = self.subject.configuredCell(at: self.visible) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Data source required to configure cells.", userInfo: nil, closure: nil)
        )
    }
}

// MARK: - Diffable data source

fileprivate struct Fruit: Hashable, Sendable {
    let name: String
}

@MainActor
class UICollectionView_DiffableSpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var dataSource: UICollectionViewDiffableDataSource<Int, Fruit>!
    var selectionEvents: [String] = []
    fileprivate var delegate: DiffableDelegate!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        subject = makeCollectionView()
        dataSource = UICollectionViewDiffableDataSource<Int, Fruit>(collectionView: subject) { collectionView, indexPath, fruit in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "labeled", for: indexPath) as! LabeledCell
            cell.label = fruit.name
            return cell
        }
        delegate = DiffableDelegate()
        subject.delegate = delegate

        var snapshot = NSDiffableDataSourceSnapshot<Int, Fruit>()
        snapshot.appendSections([0])
        snapshot.appendItems((0..<60).map { Fruit(name: "fruit \($0)") })
        await dataSource.apply(snapshot, animatingDifferences: false)

        try! Test.embedViewIntoMainApplicationWindow(subject)
        subject.layoutIfNeeded()
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        subject.dataSource = nil
        subject.delegate = nil
        subject = nil
        try await super.tearDown()
    }

    func test_fetchCell_withStableSnapshot_returnsDisplayedCell() {
        let cell = subject.fetchCell(at: IndexPath(item: 50, section: 0), asType: LabeledCell.self)
        expect(cell.label).to(equal("fruit 50"))
        expect(self.subject.displayedCell(at: IndexPath(item: 50, section: 0))).to(beIdenticalTo(cell))
    }

    func test_displayedCell_withStableSnapshot_isNilOffscreen() {
        expect(self.subject.displayedCell(at: IndexPath(item: 50, section: 0))).to(beNil())
        expect(self.subject.displayedCell(at: IndexPath(item: 0, section: 0), asType: LabeledCell.self)?.label).to(equal("fruit 0"))
    }

    func test_configuredCell_withStableSnapshot_runsTheCellProvider() {
        let cell = subject.configuredCell(at: IndexPath(item: 50, section: 0), asType: LabeledCell.self)
        expect(cell.label).to(equal("fruit 50"))
        expect(self.subject.cellForItem(at: IndexPath(item: 50, section: 0))).to(beNil())
    }

    func test_selectItem_withStableSnapshot_runsDelegateAndSelectsByIdentifier() {
        subject.selectItem(at: IndexPath(item: 2, section: 0))
        expect(self.delegate.events).to(equal(["didSelect 2"]))
        expect(self.subject.indexPathsForSelectedItems).to(equal([IndexPath(item: 2, section: 0)]))
        expect(self.dataSource.itemIdentifier(for: self.subject.indexPathsForSelectedItems![0])).to(equal(Fruit(name: "fruit 2")))
    }

    func test_deselectItem_withStableSnapshot_runsDelegate() {
        subject.selectItem(at: IndexPath(item: 2, section: 0))
        delegate.events = []
        subject.deselectItem(at: IndexPath(item: 2, section: 0))
        expect(self.delegate.events).to(equal(["didDeselect 2"]))
        expect(self.subject.indexPathsForSelectedItems).to(beEmpty())
    }

    func test_afterAppliedUpdate_indicesFollowTheNewSnapshot() async {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems((10..<60).map { Fruit(name: "fruit \($0)") })
        await dataSource.apply(snapshot, animatingDifferences: false)

        expect { self.subject.selectItem(at: IndexPath(item: 10, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item 10 in section 0.", userInfo: nil, closure: nil)
        )
        expect(self.subject.indexPathsForSelectedItems).to(beEmpty())
    }
}

fileprivate class DiffableDelegate: NSObject, UICollectionViewDelegate {
    var events: [String] = []
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        events.append("didSelect \(indexPath.item)")
    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        events.append("didDeselect \(indexPath.item)")
    }
}
