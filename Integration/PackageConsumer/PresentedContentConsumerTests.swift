#if os(iOS)
import SwiftUI
import UIKit
import XCTest
import Fleet

// Maintained examples: observing the NavigationStack destination or sheet that is actually shown, through public
// Fleet APIs only. The screens report what they render with `fleetObservedContent`; the tests never read the
// model's path or presentation flag as proof. `NavigationStack` needs iOS 16, so its examples are availability-gated
// and skip below that without raising the package minimum (iOS 15). tvOS is not covered here.

struct PresentedRecipe: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let image: String
}

let soup = PresentedRecipe(id: "r1", name: "Soup", image: "soup.png")
let salad = PresentedRecipe(id: "r2", name: "Salad", image: "salad.png")

/// Releases application-owned asynchronous work when the test says so (a fake service latency, not a sleep).
@MainActor
final class PresentationGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }
}

@MainActor
final class PresentedRecipeBook: ObservableObject {
    @Published var path: [PresentedRecipe] = []
    @Published var selected: PresentedRecipe?
    @Published var showsSheet = false
    @Published var sheetRecipe = soup
    /// Mutant: the content shows the recipe presented *before* the current one while every flag is true.
    var showsStaleRecipe = false
    private var previous: PresentedRecipe?
    private var current: PresentedRecipe?
    /// Application-owned asynchronous presentations that have not finished.
    private(set) var inFlight = 0

    func displayed(_ recipe: PresentedRecipe) -> PresentedRecipe {
        if current != recipe { previous = current; current = recipe }
        return showsStaleRecipe ? (previous ?? recipe) : recipe
    }

    func pushWhenLoaded(_ recipe: PresentedRecipe, gate: PresentationGate) {
        inFlight += 1
        Task { @MainActor in
            await gate.wait()
            self.path.append(recipe)
            self.inFlight -= 1
        }
    }
}

struct RecipeDetailContent: View {
    let book: PresentedRecipeBook
    let recipe: PresentedRecipe
    let identity: String
    var body: some View {
        let shown = book.displayed(recipe)
        VStack {
            Text(shown.name)
            Text(shown.image)
        }
        .fleetObservedContent(identity, ["recipe": shown.name, "image": shown.image, "id": shown.id])
    }
}

@available(iOS 16.0, *)
struct RecipeStackScreen: View {
    @ObservedObject var book: PresentedRecipeBook
    var body: some View {
        NavigationStack(path: $book.path) {
            Text("Recipe list")
                .fleetObservedContent("recipe-list", ["title": "Recipe list"])
                .navigationDestination(for: PresentedRecipe.self) { recipe in
                    RecipeDetailContent(book: book, recipe: recipe, identity: "recipe-detail")
                }
        }
    }
}

struct RecipeItemSheetScreen: View {
    @ObservedObject var book: PresentedRecipeBook
    var body: some View {
        Text("Recipe list")
            .fleetObservedContent("recipe-list", ["title": "Recipe list"])
            .sheet(item: $book.selected) { recipe in
                RecipeDetailContent(book: book, recipe: recipe, identity: "recipe-sheet")
            }
    }
}

struct RecipeFlagSheetScreen: View {
    @ObservedObject var book: PresentedRecipeBook
    var body: some View {
        Text("Recipe list")
            .fleetObservedContent("recipe-list", ["title": "Recipe list"])
            .sheet(isPresented: $book.showsSheet) {
                RecipeDetailContent(book: book, recipe: book.sheetRecipe, identity: "recipe-sheet")
            }
    }
}

@MainActor
final class PresentedContentConsumerTests: XCTestCase {
    private func window() throws -> UIWindow { try XCTUnwrap(UIApplication.shared.keyWindow) }

    private func requireNavigationStack() throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("NavigationStack requires iOS 16") }
    }

    func test_navigationStack_pushAndPopObserveLiveDestination() async throws {
        try requireNavigationStack()
        guard #available(iOS 16.0, *) else { return }
        let book = PresentedRecipeBook()
        try await Fleet.withHostedView(RecipeStackScreen(book: book), window: try window()) { host in
            try await host.waitForContentPresented("recipe-list")
            XCTAssertNil(host.currentContent("recipe-detail"))
            book.path = [soup]
            try await host.waitForContentPresented("recipe-detail")
            try await host.waitForContent("recipe-detail", values: ["recipe": "Soup", "image": "soup.png", "id": "r1"])
            book.path = [soup, salad]
            try await host.waitForContent("recipe-detail", values: ["recipe": "Salad", "image": "salad.png"])
            XCTAssertEqual(host.presentationCount(of: "recipe-detail"), 2)
            book.path.removeLast()
            try await host.waitForContent("recipe-detail", values: ["recipe": "Soup"])
            book.path = []
            try await host.waitForContentDismissed("recipe-detail")
            // The underlying screen is displayed again, not merely present in the model.
            try await host.waitForContent("recipe-list", values: ["title": "Recipe list"])
            XCTAssertTrue(book.path.isEmpty)
        }
    }

    func test_navigationStack_asynchronousPushIsObservedOnlyOnceItHappens() async throws {
        try requireNavigationStack()
        guard #available(iOS 16.0, *) else { return }
        let book = PresentedRecipeBook()
        let gate = PresentationGate()
        try await Fleet.withHostedView(RecipeStackScreen(book: book), window: try window()) { host in
            book.pushWhenLoaded(salad, gate: gate)
            XCTAssertEqual(book.inFlight, 1)
            do {
                try await host.waitForContentPresented("recipe-detail", timeout: 0.2)
                XCTFail("nothing was presented yet")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .timedOut)
            }
            gate.open()
            try await host.waitForContentPresented("recipe-detail")
            try await host.waitForContent("recipe-detail", values: ["recipe": "Salad", "image": "salad.png"])
            XCTAssertEqual(book.inFlight, 0)
        }
        XCTAssertEqual(book.inFlight, 0, "no presentation task outlived the scope")
    }

    func test_itemSheet_switchingItemDismissingAndRepresenting() async throws {
        let book = PresentedRecipeBook()
        try await Fleet.withHostedView(RecipeItemSheetScreen(book: book), window: try window()) { host in
            book.selected = soup
            try await host.waitForContentPresented("recipe-sheet")
            try await host.waitForContent("recipe-sheet", values: ["recipe": "Soup", "image": "soup.png"])
            book.selected = salad  // switch the triggering item
            try await host.waitForContent("recipe-sheet", values: ["recipe": "Salad", "image": "salad.png", "id": "r2"])
            book.selected = nil
            try await host.waitForContentDismissed("recipe-sheet")
            try await host.waitForModalDismissal()
            try await host.waitForContent("recipe-list", values: ["title": "Recipe list"])
            XCTAssertNotNil(host.currentContent("recipe-list"))
            let before = host.presentationCount(of: "recipe-sheet")
            book.selected = soup  // repeated presentation
            try await host.waitForContentPresented("recipe-sheet", count: before + 1)
            try await host.waitForContent("recipe-sheet", values: ["recipe": "Soup"])
            book.selected = nil
            try await host.waitForContentDismissed("recipe-sheet")
        }
    }

    func test_booleanSheet_presentsDismissesAndRepresents() async throws {
        let book = PresentedRecipeBook()
        try await Fleet.withHostedView(RecipeFlagSheetScreen(book: book), window: try window()) { host in
            book.sheetRecipe = salad
            book.showsSheet = true
            try await host.waitForContentPresented("recipe-sheet")
            try await host.waitForContent("recipe-sheet", values: ["recipe": "Salad", "image": "salad.png"])
            book.showsSheet = false
            try await host.waitForContentDismissed("recipe-sheet")
            try await host.waitForModalDismissal()
            try await host.waitForContent("recipe-list", values: ["title": "Recipe list"])
            book.sheetRecipe = soup
            book.showsSheet = true
            try await host.waitForContentPresented("recipe-sheet", count: 2)
            try await host.waitForContent("recipe-sheet", values: ["recipe": "Soup", "image": "soup.png"])
        }
    }

    func test_staleRecipeMutant_failsContentAssertionWhileFlagIsTrue() async throws {
        let book = PresentedRecipeBook()
        book.showsStaleRecipe = true
        try await Fleet.withHostedView(RecipeItemSheetScreen(book: book), window: try window()) { host in
            book.selected = soup
            try await host.waitForContent("recipe-sheet", values: ["recipe": "Soup"])
            book.selected = nil
            try await host.waitForContentDismissed("recipe-sheet")
            book.selected = salad
            try await host.waitForContentPresented("recipe-sheet", count: 2)
            XCTAssertNotNil(book.selected, "the model still says the Salad sheet is presented")
            do {
                try await host.waitForContent("recipe-sheet", values: ["recipe": "Salad", "image": "salad.png"], timeout: 0.5)
                XCTFail("stale content must not satisfy the current-recipe assertion")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .timedOut)
                XCTAssertTrue(failure.action.contains("recipe=Soup"), "failure names the stale content: \(failure.action)")
                XCTAssertNotNil(failure.source)
            }
        }
    }

    func test_waits_areBoundedAndCancellable() async throws {
        let book = PresentedRecipeBook()
        let hostWindow = try window()
        let waiting = PresentationGate()
        let task = Task { @MainActor in
            try await Fleet.withHostedView(RecipeItemSheetScreen(book: book), window: hostWindow) { host in
                waiting.open()
                try await host.waitForContentPresented("recipe-sheet", timeout: 30)
            }
        }
        await waiting.wait()  // the body is now inside the long wait (or about to enter it)
        task.cancel()
        do { try await task.value; XCTFail("expected cancellation") } catch is CancellationError {}
    }
}
#endif
