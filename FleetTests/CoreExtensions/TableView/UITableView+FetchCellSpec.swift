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

class UITableView_FetchCellSpec: XCTestCase {
    var subject: UITableView!
    fileprivate var dataSource: TestTableViewDataSource!

    override func setUp() {
        super.setUp()

        dataSource = TestTableViewDataSource()

        subject = UITableView()
        subject.register(UITableViewCell.self, forCellReuseIdentifier: uiIdentifier)
        subject.register(TestTableViewCell.self, forCellReuseIdentifier: testIdentifier)

        subject.dataSource = dataSource
        subject.reloadData()

        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    func test_fetchCell_whenTheCellExists_returnsTheCell() {
        let cell = try! subject.fetchCell(at: IndexPath(row: 0, section: 0))
        expect(cell).to(beAnInstanceOf(UITableViewCell.self))
    }

    func test_fetchCell_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { try self.subject.fetchCell(at: IndexPath(row: 0, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Data source required to fetch cells.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCell_whenSectionInIndexPathDoesNotExist_raisesException() {
        expect { try self.subject.fetchCell(at: IndexPath(row: 0, section: 1)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section 1.", userInfo: nil, closure: nil)
        )
        expect { try self.subject.fetchCell(at: IndexPath(row: 0, section: -1)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section -1.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCell_whenRowInIndexPathDoesNotExist_raisesException() {
        expect { try self.subject.fetchCell(at: IndexPath(row: 2, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 2 in section 0.", userInfo: nil, closure: nil)
        )
        expect { try self.subject.fetchCell(at: IndexPath(row: -1, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row -1 in section 0.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenTheCellExists_returnsTheCellTypedCorrectly() {
        expect { try self.subject.fetchCell(at: IndexPath(row: 1, section: 0), asType: TestTableViewCell.self) }.toNot(
            raiseException()
        )
    }

    func test_fetchCellAsType_whenNoDataSource_raisesException() {
        subject.dataSource = nil
        expect { try self.subject.fetchCell(at: IndexPath(row: 1, section: 0), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Data source required to fetch cells.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenSectionInIndexPathDoesNotExist_raisesException() {
        expect { try self.subject.fetchCell(at: IndexPath(row: 0, section: 1), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section 1.", userInfo: nil, closure: nil)
        )
        expect { try self.subject.fetchCell(at: IndexPath(row: 0, section: -1), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section -1.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenRowInIndexPathDoesNotExist_raisesException() {
        expect { try self.subject.fetchCell(at: IndexPath(row: 2, section: 0), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 2 in section 0.", userInfo: nil, closure: nil)
        )
        expect { try self.subject.fetchCell(at: IndexPath(row: -1, section: 0), asType: TestTableViewCell.self) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row -1 in section 0.", userInfo: nil, closure: nil)
        )
    }

    func test_fetchCellAsType_whenCellAtIndexPathIsNotOfRequestedType_raisesException() {
        expect { try self.subject.fetchCell(at: IndexPath(row: 0, section: 0), asType: TestTableViewCell.self)  }.to(
            raiseException()
        )
    }
}
