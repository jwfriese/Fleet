import Foundation
import UIKit
import ObjectiveC

private final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}

@MainActor private var storyboardInstanceBindingAssociationKey: UInt8 = 0

/// Where a storyboard's compiled metadata is found: the storyboard's name and, optionally, the bundle holding it.
private struct StoryboardMetadataIdentity: Equatable {
    var name: String?
    var bundle: Bundle?
}

@MainActor private var storyboardMetadataIdentityAssociationKey: UInt8 = 0

extension UIStoryboard {
    // Bindings live on the storyboard instance, so they (and the controllers bound to them) are
    // released with it. Nothing is kept in process-wide storage between tests.
    fileprivate var storyboardInstanceBinding: StoryboardInstanceBinding? {
        get {
            return objc_getAssociatedObject(self, &storyboardInstanceBindingAssociationKey) as? StoryboardInstanceBinding
        }
        set {
            objc_setAssociatedObject(self, &storyboardInstanceBindingAssociationKey,
                                     newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    fileprivate var metadataIdentity: StoryboardMetadataIdentity {
        get {
            return (objc_getAssociatedObject(self, &storyboardMetadataIdentityAssociationKey) as? Box<StoryboardMetadataIdentity>)?.value
                ?? StoryboardMetadataIdentity()
        }
        set {
            objc_setAssociatedObject(self, &storyboardMetadataIdentityAssociationKey,
                                     Box(newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    fileprivate func resolvedStoryboardName() throws -> String {
        if let name = metadataIdentity.name {
            return name
        }

        // UIStoryboard exposes no public accessor for its name; fall back to the KVC key it has always had.
        if responds(to: NSSelectorFromString("name")), let name = value(forKey: "name") as? String {
            return name
        }

        let message = "Could not determine the name of this storyboard. Call useBindingMetadata(forStoryboardNamed:in:) with the storyboard's name before binding."
        throw FleetFailure.storyboard(.invalidSetup, action: "determine storyboard name", target: "UIStoryboard", message: message, reason: "Call useBindingMetadata(forStoryboardNamed:in:) first.")
    }

    fileprivate func initializeStoryboardBindings() throws -> StoryboardInstanceBinding {
        if let existing = storyboardInstanceBinding {
            return existing
        }

        let storyboardName = try resolvedStoryboardName()
        let storyboardReference = try StoryboardDeserializer().deserializeStoryboard(withName: storyboardName, in: metadataIdentity.bundle)
        let binding = StoryboardInstanceBinding(fromStoryboardName: storyboardName, storyboardReferenceMap: storyboardReference)
        storyboardInstanceBinding = binding
        return binding
    }

    /**
     Names the compiled metadata that Fleet uses to validate this storyboard's bindings, instead of
     inferring the storyboard's name and searching every loaded test bundle.

     Call this before the first `bind` or `mockIdentifier` call. Use it when the same storyboard
     name is compiled into more than one test bundle with different contents, or when the storyboard
     lives in a bundle other than the loaded test bundles.

     - parameters:
        - name: The storyboard's name, as passed to `UIStoryboard(name:bundle:)`
        - bundle: The bundle that holds `StoryboardInfo/<name>/Info.plist`, as copied by Fleet's
          storyboard metadata script. Pass `nil` to search the loaded test bundles.

     - throws:
     A `FleetError` if bindings have already been made with different metadata.
     */
    public func useBindingMetadata(forStoryboardNamed name: String, in bundle: Bundle?) throws {
        let identity = StoryboardMetadataIdentity(name: name, bundle: bundle)
        if let existing = storyboardInstanceBinding, existing.isEmpty {
            // Nothing is registered (for example after a context ended), so the metadata can change.
            storyboardInstanceBinding = nil
        }
        if storyboardInstanceBinding != nil && identity != metadataIdentity {
            let message = "Cannot change the binding metadata of storyboard '\(name)' after view controllers have been bound. Call removeBindings() first."
            throw FleetFailure.storyboard(.invalidSetup, action: "change binding metadata", target: "storyboard '\(name)'", message: message, reason: "Call removeBindings() before choosing different metadata.")
        }
        metadataIdentity = identity
    }

    /**
     Removes every binding and mock registration made on this storyboard instance, releasing the
     view controllers bound to it. Bindings belong to the storyboard instance they were made on, so
     this does not affect other storyboards, including other instances with the same name.

     Bindings are also released when the storyboard itself is deallocated. Call this from
     `tearDown` (or `addTeardownBlock`) when the storyboard outlives a single test, for example
     when it is stored in an `XCTestCase` property, since XCTest keeps test case instances alive
     until the whole run finishes.
     */
    public func removeBindings() {
        storyboardInstanceBinding?.clear()
        storyboardInstanceBinding = nil
    }

    /**
     Runs `body`, then removes this storyboard's bindings whether `body` returns or throws.
     */
    public func withBindings<T>(_ body: () throws -> T) rethrows -> T {
        defer { removeBindings() }
        return try body()
    }

    /**
     Runs the asynchronous `body`, then removes this storyboard's bindings whether `body` returns,
     throws, or is cancelled.
     */
    public func withBindings<T>(_ body: () async throws -> T) async rethrows -> T {
        defer { removeBindings() }
        return try await body()
    }

    /**
     Substitutes with a mock the view controller that the storyboard returns when asked for
     the view controller with the given identifier.

     - parameters:
        - identifier: The storyboard identifier of the view controller to mock
        - classToMock: The class for which a mock should be created and returned

     - returns:
     The view controller instance that will be used as the view controller returned
     for the given identifier in all contexts following this function's execution. It
     will be a mock of the view controller type passed into the `classToMock` argument,
     and as such will be usable as if it were a real object of that type. It will not
     execute any view controller lifecycle code such as `viewDidLoad`.

     - throws:
     A `FleetError` in the case that the storyboard
     has no view controller with the given identifier.
     */
    public func mockIdentifier<T>(_ identifier: String, usingMockFor classToMock: T.Type) throws -> T where T: UIViewController {
        let mock = try makeMock(for: classToMock)
        try bind(viewController: mock, toIdentifier: identifier)
        return mock
    }

    /**
     Given the name of an external storyboard reference within this storyboard, and an
     identifier for a view controller on that storyboard, substitutes with a mock the
     view controller it would return when asked for the view controller with that
     identifier.

     - parameters:
        - identifier: The storyboard identifier of the view controller to mock
        - referencedStoryboardName: The name of the storyboard associated with the external reference
        - classToMock: The class for which a mock should be created and returned

     - returns:
     The view controller instance that will be used as the view controller returned
     for the given identifier in all contexts following this function's execution. It
     will be a mock of the view controller type passed into the `classToMock` argument,
     and as such will be usable as if it were a real object of that type. It will not
     execute any view controller lifecycle code such as `viewDidLoad`.

     - throws:
     A `FleetError` in the case that the storyboard with the
     given name has no view controller with the given identifier.
     */
    public func mockIdentifier<T>(_ identifier: String, forReferencedStoryboardWithName referencedStoryboardName: String, usingMockFor classToMock: T.Type) throws -> T where T: UIViewController {
        let mock = try makeMock(for: classToMock)
        try bind(viewController: mock, toIdentifier: identifier, forReferencedStoryboardWithName: referencedStoryboardName)
        return mock
    }

    /**
     Given the name of an external storyboard reference within this storyboard, substitutes
     with a mock the view controller it would return as its initial view controller, and
     returns that mock.

     When this method executes successfully, any code that uses this storyboard to retrieve
     the initial view controller of the named external storyboard will receive the mock instead
     of a real instantiated view controller.

     - parameters:
        - name: The name of the storyboard associated with the external reference
        - classToMock: The class for which a mock should be created and returned

     - returns:
     The view controller instance that will be used as the initial view controller of
     that external storyboard reference in all contexts following this function's execution.
     It will be a mock of the view controller type passed into the `classToMock` argument,
     and as such will be usable as if it were a real object of that type. It will not
     execute any view controller lifecycle code such as `viewDidLoad`.

     - throws:
     A `FleetError` in the case that the storyboard has no external
     reference to a storyboard with the given name.
     */
    public func mockInitialViewController<T>(forReferencedStoryboardWithName name: String, usingMockFor classToMock: T.Type) throws -> T where T: UIViewController {
        let mock = try makeMock(for: classToMock)
        try bind(viewController: mock, asInitialViewControllerForReferencedStoryboardWithName: name)
        return mock
    }

    /**
     Binds the given view controller to the view controller reference associated with the
     given identifier. The bound view controller will then always be returned when the
     bound identifier is used to instantiate a view controller, even in segues.

     - parameters:
        - viewController: The view controller to bind
        - identifier: The identifier whose reference should have the view controller bound to it

     - throws:
     A `FleetError` if there is no
     view controller reference on the storyboard with the given identifier, or
     `StoryboardBindingError.InvalidViewControllerState` if the input view controller has
     already loaded its view.
     */
    public func bind(viewController: UIViewController, toIdentifier identifier: String) throws {
        if viewController.viewDidLoadCallCount > 0 {
            let message = "Attempted to bind a view controller whose view has already been loaded to storyboard identifier '\(identifier)'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code."
            throw FleetFailure.storyboard(.invalidInput, action: "bind view controller", target: "UIStoryboard", message: message, reason: "Bind the view controller before its view loads.")
        }
        let owner = try FleetTestContext.owningContext()
        let storyboardInstanceBinding = try initializeStoryboardBindings()
        try storyboardInstanceBinding.bind(viewController: viewController, toIdentifier: identifier, owner: owner)
    }

    /**
     Binds the given view controller to the view controller reference associated with the
     given identifier on the external storyboard reference with the given name. The bound view
     controller will then always be returned when the bound identifier is used to instantiate a
     view controller, even in segues. Use this to bind view controllers to external storyboard
     references.

     - parameters:
        - viewController: The view controller to bind
        - identifier: The identifier whose reference should have the view controller bound to it
        - referencedStoryboardName: The name of the storyboard to which the external reference is associated

     - throws:
     A `FleetError` if there is no
     external storyboard view controller reference on the storyboard with the given identifier
     and given storyboard name, or
     `StoryboardBindingError.InvalidViewControllerState` if the input view controller has
     already loaded its view.
     */
    public func bind(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName referencedStoryboardName: String) throws {
        if viewController.viewDidLoadCallCount > 0 {
            let message = "Attempted to bind a view controller whose view has already been loaded to view controller identifier '\(identifier)' on storyboard '\(referencedStoryboardName)'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code."
            throw FleetFailure.storyboard(.invalidInput, action: "bind view controller", target: "UIStoryboard", message: message, reason: "Bind the view controller before its view loads.")
        }
        let owner = try FleetTestContext.owningContext()
        let storyboardInstanceBinding = try initializeStoryboardBindings()
        try storyboardInstanceBinding.bind(viewController: viewController, toIdentifier: identifier,
                                           forReferencedStoryboardWithName: referencedStoryboardName, owner: owner)
    }

    /**
     Binds the given view controller to be the initial view controller instantiated from the
     external storyboard associated with the given storyboard name. The bound view controller
     will then always be returned when the external storyboard reference is used to instantiate a
     view controller, even in segues. Use this to bind view controllers to external storyboard
     references that instantiate the external storyboard's initial view controller.

     - parameters:
        - viewController: The view controller to bind
        - referencedStoryboardName: The name of the storyboard to which the external reference is associated

     - throws:
     A `FleetError` if there is no external storyboard view controller
     reference on the storyboard with the given storyboard name, or a `Fleet.StoryboardError.invalidViewControllerState`
     if the input view controller has already loaded its view.
     */
    public func bind(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName referencedStoryboardName: String) throws {
        if viewController.viewDidLoadCallCount > 0 {
            let message = "Attempted to bind a view controller whose view has already been loaded to initial view controller of storyboard '\(referencedStoryboardName)'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code."
            throw FleetFailure.storyboard(.invalidInput, action: "bind view controller", target: "UIStoryboard", message: message, reason: "Bind the view controller before its view loads.")
        }
        let owner = try FleetTestContext.owningContext()
        let storyboardInstanceBinding = try initializeStoryboardBindings()
        try storyboardInstanceBinding.bind(viewController: viewController, asInitialViewControllerForReferencedStoryboardWithName: referencedStoryboardName, owner: owner)
    }

    private func makeMock<T>(for classToMock: T.Type) throws -> T where T: UIViewController {
        do {
            return try Fleet.mockFor(classToMock)
        } catch let error as Fleet.MockError {
            throw FleetFailure.storyboard(.invalidInput, action: "create mock view controller", target: "\(classToMock)", message: error.description, reason: "Mock a supported UIViewController subclass.")
        }
    }

    @objc nonisolated class func swizzleViewControllerInstantiationMethod() {
        Fleet.swizzle(
            originalSelector: #selector(UIStoryboard.instantiateViewController(withIdentifier:)),
            swizzledSelector: #selector(UIStoryboard.fleet_instantiateViewController(withIdentifier:)),
            forClass: self
        )
    }

    @objc func fleet_instantiateViewController(withIdentifier identifier: String) -> UIViewController {
        if let boundInstance = storyboardInstanceBinding?.viewController(forIdentifier: identifier) {
            return boundInstance
        }

        let viewController = fleet_instantiateViewController(withIdentifier: identifier)
        return viewController
    }
}
