import XCTest
import Testing
import UIKit
import Fleet

private final class FailureSource: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    var allowSelection = true
    var allowDeselection = true
    var events: [String] = []
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 2 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool { allowSelection }
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        events.append("shouldDeselect \(indexPath.item)"); return allowDeselection
    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        events.append("didDeselect \(indexPath.item)")
    }
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
    func test_fetchCellOrThrow_withoutDataSource_throwsInvalidSetup() {
        let view = makeCollectionView(nil)

        XCTAssertThrowsError(try view.fetchCellOrThrow(at: IndexPath(item: 0, section: 0))) { error in
            guard let failure = error as? FleetFailure else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(failure.kind, .invalidSetup)
            XCTAssertEqual(failure.action, "fetch cell")
        }
    }

    func test_fetchCellOrThrow_withMissingSectionOrItem_throwsInvalidInput() {
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }

        for path in [IndexPath(item: 0, section: 3), IndexPath(item: 9, section: 0), IndexPath(item: -1, section: 0), IndexPath(index: 0)] {
            XCTAssertThrowsError(try view.fetchCellOrThrow(at: path)) { error in
                guard let failure = error as? FleetFailure else { return XCTFail("Unexpected error \(error)") }
                XCTAssertEqual(failure.kind, .invalidInput)
            }
        }
    }

    func test_fetchCellOrThrow_withMismatchedType_throwsInvalidInput() {
        final class OtherCell: UICollectionViewCell {}
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }

        XCTAssertThrowsError(try view.fetchCellOrThrow(at: IndexPath(item: 0, section: 0), asType: OtherCell.self)) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
    }

    func test_fetchCellOrThrow_withExistingItem_returnsTheCell() throws {
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }

        let cell = try view.fetchCellOrThrow(at: IndexPath(item: 1, section: 0), asType: UICollectionViewCell.self)
        XCTAssertNotNil(cell)
    }

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

    func test_selectItemOrThrow_withMalformedIndexPath_throwsInvalidInputWithoutTrapping() {
        let view = makeCollectionView(FailureSource())

        for path in [IndexPath(), IndexPath(index: 0)] {
            XCTAssertThrowsError(try view.selectItemOrThrow(at: path)) { error in
                guard let failure = error as? FleetFailure else { return XCTFail("Unexpected error \(error)") }
                XCTAssertEqual(failure.kind, .invalidInput)
                XCTAssertEqual(failure.action, "select item")
                XCTAssertEqual(failure.state, "the index path has \(path.count) component(s)")
            }
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

    func test_deselectItemOrThrow_onSuccess_deselectsAndReportsPerformed() throws {
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }
        _ = try view.selectItemOrThrow(at: IndexPath(item: 1, section: 0))
        XCTAssertEqual(try view.deselectItemOrThrow(at: IndexPath(item: 1, section: 0)), .performed)
        XCTAssertEqual(view.indexPathsForSelectedItems ?? [], [])
    }

    func test_deselectItemOrThrow_whenDelegateRefuses_returnsOutcomeAndKeepsSelection() throws {
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }
        _ = try view.selectItemOrThrow(at: IndexPath(item: 0, section: 0))
        source.allowDeselection = false
        XCTAssertEqual(try view.deselectItemOrThrow(at: IndexPath(item: 0, section: 0)),
                       .refusedByDelegate(method: "collectionView(_:shouldDeselectItemAt:)"))
        XCTAssertEqual(view.indexPathsForSelectedItems, [IndexPath(item: 0, section: 0)])
    }

    func test_deselectItemOrThrow_failures_throwContextWithoutMutatingOrCallingDelegate() throws {
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }
        _ = try view.selectItemOrThrow(at: IndexPath(item: 0, section: 0))
        source.events = []

        for path in [IndexPath(), IndexPath(index: 0), IndexPath(item: 0, section: -1), IndexPath(item: -1, section: 0),
                     IndexPath(item: 9, section: 0), IndexPath(item: 1, section: 0)] {
            XCTAssertThrowsError(try view.deselectItemOrThrow(at: path)) { error in
                guard let failure = error as? FleetFailure else { return XCTFail("Unexpected error \(error)") }
                XCTAssertEqual(failure.action, "deselect item")
                XCTAssertEqual(failure.kind, path == IndexPath(item: 1, section: 0) ? .unavailableInteraction : .invalidInput)
            }
        }
        XCTAssertEqual(view.indexPathsForSelectedItems, [IndexPath(item: 0, section: 0)])
        XCTAssertEqual(source.events, [])
        view.allowsSelection = false  // UIKit itself clears the selection here.
        source.events = []
        XCTAssertThrowsError(try view.deselectItemOrThrow(at: IndexPath(item: 0, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
        }
        XCTAssertEqual(source.events, [])

        let bare = makeCollectionView(nil)
        XCTAssertThrowsError(try bare.deselectItemOrThrow(at: IndexPath(item: 0, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
        }
    }

    func test_displayedCellOrThrow_returnsLiveVisibleCellOrNil() throws {
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }
        view.layoutIfNeeded()
        let live = try XCTUnwrap(view.cellForItem(at: IndexPath(item: 0, section: 0)))
        XCTAssertTrue(try view.displayedCellOrThrow(at: IndexPath(item: 0, section: 0)) === live)
        XCTAssertTrue(try view.displayedCellOrThrow(at: IndexPath(item: 0, section: 0), asType: UICollectionViewCell.self) === live)

        let unlaidOut = makeCollectionView(source)
        unlaidOut.frame = .zero
        XCTAssertNil(try unlaidOut.displayedCellOrThrow(at: IndexPath(item: 1, section: 0)))
    }

    func test_displayedCellOrThrow_failures_throwContext() throws {
        final class OtherCell: UICollectionViewCell {}
        let source = FailureSource()
        let view = makeCollectionView(source)
        defer { withExtendedLifetime(source) {} }
        view.layoutIfNeeded()

        for path in [IndexPath(), IndexPath(index: 0), IndexPath(item: 0, section: 4), IndexPath(item: -1, section: 0), IndexPath(item: 5, section: 0)] {
            XCTAssertThrowsError(try view.displayedCellOrThrow(at: path)) { error in
                guard let failure = error as? FleetFailure else { return XCTFail("Unexpected error \(error)") }
                XCTAssertEqual(failure.kind, .invalidInput)
                XCTAssertEqual(failure.action, "inspect cell")
            }
        }
        XCTAssertThrowsError(try view.displayedCellOrThrow(at: IndexPath(item: 0, section: 0), asType: OtherCell.self)) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        XCTAssertThrowsError(try makeCollectionView(nil).displayedCellOrThrow(at: IndexPath(item: 0, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
        }
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
        #expect(throws: FleetFailure.self) { try view.deselectItemOrThrow(at: IndexPath(item: 9, section: 0)) }
        #expect(throws: FleetFailure.self) { try view.displayedCellOrThrow(at: IndexPath(item: 9, section: 0)) }
        withExtendedLifetime(source) {}
    }
}
