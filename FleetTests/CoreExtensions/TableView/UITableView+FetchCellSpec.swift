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
