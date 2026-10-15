import XCTest
import Fleet
import Nimble

fileprivate class TestTableViewCell: UITableViewCell {}

fileprivate let uiIdentifier = "UI"
fileprivate let testIdentifier = "Test"

fileprivate class TestTableViewDataSource: NSObject, UITableViewDataSource {
    var data: [String] = [uiIdentifier, testIdentifier]

    fileprivate func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    fileprivate func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    fileprivate func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: data[indexPath.row], for: indexPath)
    }
}

@MainActor
class UITableView_FetchCellSpec: XCTestCase {
    var subject: UITableView!
    fileprivate var dataSource: TestTableViewDataSource!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        dataSource = TestTableViewDataSource()

        subject = UITableView()
        subject.register(UITableViewCell.self, forCellReuseIdentifier: uiIdentifier)
        subject.register(TestTableViewCell.self, forCellReuseIdentifier: testIdentifier)

        subject.dataSource = dataSource
        subject.reloadData()

        try! Test.embedViewIntoMainApplicationWindow(subject)
        subject.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
    }

    override func tearDown() async throws {
        // The table view stays in the shared window; detach it before its weak data source goes away.
        subject.removeFromSuperview()
        subject.dataSource = nil
        try await super.tearDown()
    }

    func test_fetchCell_whenTheCellExists_returnsTheCell() {
        let cell = subject.fetchCell(at: IndexPath(row: 0, section: 0))
        expect(cell).to(beAnInstanceOf(UITableViewCell.self))
    }

    func test_fetchCell_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { self.subject.fetchCell(at: IndexPath(row: 0, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Data source required to fetch cells.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCell_whenSectionInIndexPathDoesNotExist_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(row: 0, section: 1)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section 1.", userInfo: nil, closure: nil)
        )
        expect { self.subject.fetchCell(at: IndexPath(row: 0, section: -1)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section -1.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCell_whenRowInIndexPathDoesNotExist_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(row: 2, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 2 in section 0.", userInfo: nil, closure: nil)
        )
        expect { self.subject.fetchCell(at: IndexPath(row: -1, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row -1 in section 0.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenTheCellExists_returnsTheCellTypedCorrectly() {
        expect { self.subject.fetchCell(at: IndexPath(row: 1, section: 0), asType: TestTableViewCell.self) }.toNot(
            raiseException()
        )
    }

    func test_fetchCellAsType_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { self.subject.fetchCell(at: IndexPath(row: 1, section: 0), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Data source required to fetch cells.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenSectionInIndexPathDoesNotExist_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(row: 0, section: 1), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section 1.", userInfo: nil, closure: nil)
        )
        expect { self.subject.fetchCell(at: IndexPath(row: 0, section: -1), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section -1.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenRowInIndexPathDoesNotExist_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(row: 2, section: 0), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 2 in section 0.", userInfo: nil, closure: nil)
        )
        expect { self.subject.fetchCell(at: IndexPath(row: -1, section: 0), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row -1 in section 0.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenCellAtIndexPathIsNotOfRequestedType_raisesException() {
        expect { self.subject.fetchCell(at: IndexPath(row: 0, section: 0), asType: TestTableViewCell.self)  }.to(
            raiseException()
        )
    }

    func test_fetchDisplayedCell_returnsTheInstanceTheTableViewDisplays() {
        subject.layoutIfNeeded()
        let displayed = subject.fetchDisplayedCell(at: IndexPath(row: 0, section: 0))
        expect(displayed).to(beIdenticalTo(subject.cellForRow(at: IndexPath(row: 0, section: 0))))
        expect(self.subject.fetchDisplayedCell(at: IndexPath(row: 0, section: 0))).to(beIdenticalTo(displayed))
    }

    func test_fetchCell_returnsAConfiguredCellDistinctFromTheDisplayedCell() {
        subject.layoutIfNeeded()
        let displayed = subject.fetchDisplayedCell(at: IndexPath(row: 0, section: 0))
        let configured = subject.fetchCell(at: IndexPath(row: 0, section: 0))
        expect(configured).toNot(beIdenticalTo(displayed))
    }

    func test_fetchDisplayedCell_whenRowIsNotDisplayed_raisesException() {
        // Rows of a table view whose frame is empty are never displayed.
        subject.frame = .zero
        subject.layoutIfNeeded()
        expect { self.subject.fetchDisplayedCell(at: IndexPath(row: 1, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Cell at row 1 in section 0 is not currently displayed by the table view.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchDisplayedCell_whenRowIsRetainedButNotVisible_raisesException() {
        // `cellForRow(at:)` may return prepared cells outside the visible region; use a tall data set.
        dataSource.data = Array(repeating: uiIdentifier, count: 200)
        subject.reloadData()
        subject.layoutIfNeeded()
        let farRow = IndexPath(row: 199, section: 0)
        XCTAssertFalse((subject.indexPathsForVisibleRows ?? []).contains(farRow))
        XCTAssertThrowsError(try subject.fetchDisplayedCellOrThrow(at: farRow)) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
        }
    }

    func test_fetchCellOrThrow_reportsFailuresAsSwiftErrors() {
        XCTAssertNoThrow(try subject.fetchCellOrThrow(at: IndexPath(row: 0, section: 0)))
        XCTAssertThrowsError(try subject.fetchCellOrThrow(at: IndexPath(row: 2, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        subject.layoutIfNeeded()
        // Use the displayed form for the type mismatch: re-dequeuing a path the table already dequeued traps.
        XCTAssertThrowsError(try subject.fetchDisplayedCellOrThrow(at: IndexPath(row: 0, section: 0), asType: TestTableViewCell.self)) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        XCTAssertThrowsError(try subject.fetchDisplayedCellOrThrow(at: IndexPath(row: 0, section: 1))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        subject.dataSource = nil
        XCTAssertThrowsError(try subject.fetchDisplayedCellOrThrow(at: IndexPath(row: 0, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
        }
    }

    func test_fetchDisplayedCell_whenIndexPathIsInvalid_raisesException() {
        subject.layoutIfNeeded()
        expect { self.subject.fetchDisplayedCell(at: IndexPath(row: 0, section: 1)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section 1.", userInfo: nil, closure: nil)
        )
        expect { self.subject.fetchDisplayedCell(at: IndexPath(row: 2, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 2 in section 0.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchDisplayedCell_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { self.subject.fetchDisplayedCell(at: IndexPath(row: 0, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Data source required to fetch displayed cells.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchDisplayedCellAsType_returnsTypedCellOrRaisesOnMismatch() {
        subject.layoutIfNeeded()
        let typed = subject.fetchDisplayedCell(at: IndexPath(row: 1, section: 0), asType: TestTableViewCell.self)
        expect(typed).to(beIdenticalTo(subject.cellForRow(at: IndexPath(row: 1, section: 0))))
        expect { self.subject.fetchDisplayedCell(at: IndexPath(row: 0, section: 0), asType: TestTableViewCell.self) }.to(
            raiseException()
        )
    }
}
