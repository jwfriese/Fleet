import XCTest
import Fleet
import Nimble

fileprivate class TestCollectionViewCell: UICollectionViewCell {}

fileprivate let uiIdentifier = "UI"
fileprivate let testIdentifier = "Test"

fileprivate class TestCollectionViewDataSource: NSObject, UICollectionViewDataSource {
    var data: [String] = [uiIdentifier, testIdentifier]

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: data[indexPath.item], for: indexPath)
    }
}

@MainActor
class UICollectionView_FetchCellSpec: XCTestCase {
    var subject: UICollectionView!
    fileprivate var dataSource: TestCollectionViewDataSource!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        dataSource = TestCollectionViewDataSource()

        subject = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
        subject.register(UICollectionViewCell.self, forCellWithReuseIdentifier: uiIdentifier)
        subject.register(TestCollectionViewCell.self, forCellWithReuseIdentifier: testIdentifier)

        subject.dataSource = dataSource
        subject.reloadData()

        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    func test_fetchCell_whenTheCellExists_returnsTheCell() {
        let cell = subject.fetchCell(at: IndexPath(item: 0, section: 0))
        expect(cell).to(beAnInstanceOf(UICollectionViewCell.self))
    }

    func test_fetchCell_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { self.subject.fetchCell(at: IndexPath(item: 0, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Data source required to fetch cells.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCell_whenSectionInIndexPathDoesNotExist_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(item: 0, section: 1)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no section 1.", userInfo: nil, closure: nil)
        )
        expect { self.subject.fetchCell(at: IndexPath(item: 0, section: -1)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no section -1.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCell_whenItemInIndexPathDoesNotExist_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(item: 2, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item 2 in section 0.", userInfo: nil, closure: nil)
        )
        expect { self.subject.fetchCell(at: IndexPath(item: -1, section: 0)) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Collection view has no item -1 in section 0.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenTheCellExists_returnsTheCellTypedCorrectly() {
        let cell = subject.fetchCell(at: IndexPath(item: 1, section: 0), asType: TestCollectionViewCell.self)
        expect(cell).to(beAnInstanceOf(TestCollectionViewCell.self))
    }

    func test_fetchCellAsType_whenCellAtIndexPathIsNotOfRequestedType_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(item: 0, section: 0), asType: TestCollectionViewCell.self) }.to(
            raiseException(named: "Fleet.CollectionViewError")
        )
    }

    func test_fetchCellAsType_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { self.subject.fetchCell(at: IndexPath(item: 1, section: 0), asType: TestCollectionViewCell.self) }.to(
            raiseException(named: "Fleet.CollectionViewError", reason: "Data source required to fetch cells.", userInfo: nil, closure: nil)
        )
    }
}
