import XCTest
import Testing
import UIKit
import Fleet

private final class FailureSource: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    var allowSelection = true
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 2 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool { allowSelection }
}

@MainActor
private func makeCollectionView(_ source: FailureSource?) -> UICollectionView {
    let view = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
    view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
    view.dataSource = source
    view.delegate = source
    view.reloadData()
    return view
}

@MainActor
class UICollectionView_RecoverableFailureSpec: XCTestCase {
    func test_selectItemOrThrow_withMissingItem_throwsInvalidInputWithContext() {
        let source = FailureSource()
        let view = makeCollectionView(source)

        XCTAssertThrowsError(try view.selectItemOrThrow(at: IndexPath(item: 5, section: 0))) { error in
            guard let failure = error as? FleetFailure else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(failure.kind, .invalidInput)
            XCTAssertEqual(failure.action, "select item")
            XCTAssertEqual(failure.target, "UICollectionView item 5 in section 0")
            XCTAssertEqual(failure.state, "section 0 has 2 item(s)")
        }
    }

    func test_selectItemOrThrow_withoutDataSource_throwsInvalidSetup() {
        let view = makeCollectionView(nil)
        XCTAssertThrowsError(try view.selectItemOrThrow(at: IndexPath(item: 0, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
        }
    }

    func test_selectItemOrThrow_whenSelectionDisabled_throwsUnavailableInteraction() {
        let source = FailureSource()
        let view = makeCollectionView(source)
        view.allowsSelection = false
        XCTAssertThrowsError(try view.selectItemOrThrow(at: IndexPath(item: 0, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
        }
    }

    func test_selectItemOrThrow_whenDelegateRefuses_returnsOutcomeInsteadOfThrowing() throws {
        let source = FailureSource()
        source.allowSelection = false
        let view = makeCollectionView(source)

        let outcome = try view.selectItemOrThrow(at: IndexPath(item: 0, section: 0))

        XCTAssertEqual(outcome, .refusedByDelegate(method: "collectionView(_:shouldSelectItemAt:)"))
        XCTAssertNil(view.indexPathsForSelectedItems?.first)
    }

    func test_selectItemOrThrow_onSuccess_selectsAndReportsPerformed() throws {
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }
        XCTAssertEqual(try view.selectItemOrThrow(at: IndexPath(item: 1, section: 0)), .performed)
        XCTAssertEqual(view.indexPathsForSelectedItems, [IndexPath(item: 1, section: 0)])
    }
}

@MainActor
struct CollectionViewRecoverableFailureTests {
    @Test func invalidActionIsAssertableWithoutCrashing() {
        let source = FailureSource()
        let view = makeCollectionView(source)
        #expect(throws: FleetFailure.self) {
            try view.selectItemOrThrow(at: IndexPath(item: 9, section: 0))
        }
        withExtendedLifetime(source) {}
    }
}
