import XCTest
import Fleet
import Nimble

fileprivate class TitledHeader: UICollectionReusableView {
    var title: String?
}

fileprivate class OtherSupplementary: UICollectionReusableView {}

fileprivate class PlainCell: UICollectionViewCell {}

fileprivate let badgeKind = "badge"
fileprivate let itemCounts = [3, 0, 40, 1]

fileprivate class SupplementaryDataSource: NSObject, UICollectionViewDataSource {
    var providerCalls = 0

    func numberOfSections(in collectionView: UICollectionView) -> Int { return itemCounts.count }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { return itemCounts[section] }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        providerCalls += 1
        if kind == UICollectionView.elementKindSectionFooter {
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "other", for: indexPath)
        }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! TitledHeader
        header.title = "\(kind) \(indexPath.section)"
        return header
    }
}

@MainActor
private func registerViews(_ view: UICollectionView) {
    view.register(PlainCell.self, forCellWithReuseIdentifier: "cell")
    for kind in [UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter, badgeKind] {
        view.register(TitledHeader.self, forSupplementaryViewOfKind: kind, withReuseIdentifier: "header")
        view.register(OtherSupplementary.self, forSupplementaryViewOfKind: kind, withReuseIdentifier: "other")
    }
}

@MainActor
private func makeFlowCollectionView() -> UICollectionView {
    let layout = UICollectionViewFlowLayout()
    layout.itemSize = CGSize(width: 300, height: 100)
    layout.headerReferenceSize = CGSize(width: 300, height: 40)
    layout.footerReferenceSize = CGSize(width: 300, height: 40)
    let view = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
    registerViews(view)
    return view
}

@MainActor private var header: String { UICollectionView.elementKindSectionHeader }
@MainActor private var footer: String { UICollectionView.elementKindSectionFooter }

@MainActor
private func expectFailure(_ kind: FleetFailure.Kind, _ body: () throws -> Any?, file: StaticString = #filePath, line: UInt = #line) {
    do {
        _ = try body()
        XCTFail("Expected a FleetFailure", file: file, line: line)
    } catch let failure as FleetFailure {
        XCTAssertEqual(failure.kind, kind, "\(failure)", file: file, line: line)
        XCTAssertEqual(failure.action, "inspect supplementary view", file: file, line: line)
    } catch {
        XCTFail("Unexpected error \(error)", file: file, line: line)
    }
}

@MainActor
class UICollectionView_InspectSupplementaryViewSpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var dataSource: SupplementaryDataSource!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        dataSource = SupplementaryDataSource()
        subject = makeFlowCollectionView()
        subject.dataSource = dataSource
        subject.reloadData()
        try! Test.embedViewIntoMainApplicationWindow(subject)
        subject.layoutIfNeeded()
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        subject.dataSource = nil
        subject = nil
        try await super.tearDown()
    }

    func test_visibleHeaderAndFooter_returnLiveInstances() throws {
        let headerView = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0))
        expect(headerView).toNot(beNil())
        expect(headerView).to(beIdenticalTo(subject.supplementaryView(forElementKind: header, at: IndexPath(item: 0, section: 0))))
        let typed = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0), asType: TitledHeader.self)
        expect(typed?.title).to(equal("\(header) 0"))
        expect(typed).to(beIdenticalTo(headerView))
        // tvOS's flow layout lays out no footers in this fixture, so footers are only asserted on iOS.
        #if os(iOS)
        let footerView = try subject.displayedSupplementaryViewOrThrow(ofKind: footer, at: IndexPath(item: 0, section: 0), asType: OtherSupplementary.self)
        expect(footerView).toNot(beNil())
        #endif
    }

    func test_headerInEmptySection_isInspectable() throws {
        // The request is valid even though the section has no items. Flow layout on iOS lays the header out;
        // tvOS's flow layout does not, so the result must agree with what UIKit reports as visible.
        let path = IndexPath(item: 0, section: 1)
        let view = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: path, asType: TitledHeader.self)
        #if os(tvOS)
        expect(view == nil).to(equal(!subject.indexPathsForVisibleSupplementaryElements(ofKind: header).contains(path)))
        #else
        expect(view?.title).to(equal("\(header) 1"))
        #endif
    }

    func test_offscreenHeader_returnsNilWithoutScrollingOrProvider() throws {
        let offset = subject.contentOffset
        let calls = dataSource.providerCalls
        let result = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 3))
        expect(result).to(beNil())
        expect(self.subject.contentOffset).to(equal(offset))
        expect(self.dataSource.providerCalls).to(equal(calls))
    }

    func test_unknownKindOrIndex_returnsNilNotFailure() throws {
        expect(try self.subject.displayedSupplementaryViewOrThrow(ofKind: badgeKind, at: IndexPath(item: 0, section: 0))).to(beNil())
        expect(try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 5, section: 0))).to(beNil())
    }

    func test_preparedButNotVisibleView_isNil() throws {
        subject.setContentOffset(CGPoint(x: 0, y: 40), animated: false)
        subject.layoutIfNeeded()
        let visible = Set(subject.indexPathsForVisibleSupplementaryElements(ofKind: header))
        for section in 0..<itemCounts.count {
            let path = IndexPath(item: 0, section: section)
            if !visible.contains(path) {
                expect(try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: path)).to(beNil())
            }
        }
    }

    func test_afterScrolling_reusedViewIsReportedAtItsNewPath() throws {
        let first = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0))
        subject.setContentOffset(CGPoint(x: 0, y: 400), animated: false)
        subject.layoutIfNeeded()
        expect(try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0))).to(beNil())
        expect(first).toNot(beNil())
        let nowVisible = subject.indexPathsForVisibleSupplementaryElements(ofKind: header)
        expect(nowVisible).toNot(beEmpty())
        for path in nowVisible {
            let view = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: path, asType: TitledHeader.self)
            expect(view?.title).to(equal("\(header) \(path.section)"))
        }
    }

    func test_typeMismatch_throwsInvalidInputWithoutMutation() {
        let calls = dataSource.providerCalls
        let offset = subject.contentOffset
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0), asType: OtherSupplementary.self) }
        expect(self.dataSource.providerCalls).to(equal(calls))
        expect(self.subject.contentOffset).to(equal(offset))
    }

    func test_invalidRequests_throwContextualFailures() {
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(index: 0)) }
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath()) }
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 4)) }
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: -1)) }
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: -1, section: 0)) }
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: "", at: IndexPath(item: 0, section: 0)) }
        subject.dataSource = nil
        expectFailure(.invalidSetup) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0)) }
        subject.dataSource = dataSource
    }
}

// MARK: - Diffable data source

@MainActor
class UICollectionView_DiffableSupplementarySpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var dataSource: UICollectionViewDiffableDataSource<Int, Int>!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        subject = makeFlowCollectionView()
        dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: subject) { view, indexPath, _ in
            view.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        }
        dataSource.supplementaryViewProvider = { view, kind, indexPath in
            let result = view.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! TitledHeader
            result.title = "\(kind) \(indexPath.section)"
            return result
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0, 1, 2, 3])
        snapshot.appendItems([1, 2], toSection: 0)
        snapshot.appendItems(Array(100..<140), toSection: 2)
        snapshot.appendItems([500], toSection: 3)
        await dataSource.apply(snapshot, animatingDifferences: false)
        try! Test.embedViewIntoMainApplicationWindow(subject)
        subject.layoutIfNeeded()
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        subject.dataSource = nil
        subject = nil
        try await super.tearDown()
    }

    func test_headerFooterAndEmptySection() throws {
        let first = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0), asType: TitledHeader.self)
        expect(first?.title).to(equal("\(header) 0"))
        let emptyPath = IndexPath(item: 0, section: 1)
        let empty = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: emptyPath, asType: TitledHeader.self)
        expect(empty == nil).to(equal(!subject.indexPathsForVisibleSupplementaryElements(ofKind: header).contains(emptyPath)))
        #if os(iOS)
        expect(try self.subject.displayedSupplementaryViewOrThrow(ofKind: footer, at: IndexPath(item: 0, section: 0))).toNot(beNil())
        #endif
    }

    func test_offscreenIsNilAndInvalidSectionThrows() throws {
        expect(try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 3))).to(beNil())
        expectFailure(.invalidInput) { try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 4)) }
    }
}

// MARK: - Compositional layout

@MainActor
class UICollectionView_CompositionalSupplementarySpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var dataSource: SupplementaryDataSource!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(100)))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(100)), subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(40))
            section.boundarySupplementaryItems = [
                .init(layoutSize: size, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top),
                .init(layoutSize: size, elementKind: UICollectionView.elementKindSectionFooter, alignment: .bottom),
            ]
            return section
        }
        subject = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
        registerViews(subject)
        dataSource = SupplementaryDataSource()
        subject.dataSource = dataSource
        subject.reloadData()
        try! Test.embedViewIntoMainApplicationWindow(subject)
        subject.layoutIfNeeded()
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        subject.dataSource = nil
        subject = nil
        try await super.tearDown()
    }

    func test_visibleHeader_isLiveAndOffscreenHeaderIsNil() throws {
        let view = try subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 0), asType: TitledHeader.self)
        expect(view?.title).to(equal("\(header) 0"))
        let calls = dataSource.providerCalls
        expect(try self.subject.displayedSupplementaryViewOrThrow(ofKind: header, at: IndexPath(item: 0, section: 3))).to(beNil())
        expect(self.dataSource.providerCalls).to(equal(calls))
    }
}
