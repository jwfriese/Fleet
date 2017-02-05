import Foundation
import UIKit
import ObjectiveC

private var storyboardInstanceBindingMap = [String : StoryboardInstanceBinding]()
private var storyboardBindingIdentifierAssociationKey: UInt8 = 0

fileprivate var didSwizzle = false

extension UIStoryboard {
    var storyboardBindingIdentifier: String? {
        get {
            return objc_getAssociatedObject(self, &storyboardBindingIdentifierAssociationKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &storyboardBindingIdentifierAssociationKey,
                                     newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension UIStoryboard {
    fileprivate func initializeStoryboardBindings() throws {
        let storyboardName = self.value(forKey: "name") as! String
        if storyboardBindingIdentifier == nil {
            storyboardBindingIdentifier = storyboardName + "_" + UUID().uuidString
        }

        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if storyboardInstanceBindingMap[storyboardBindingIdentifier] == nil {
                let deserializer = StoryboardDeserializer()
                let storyboardReference = try deserializer.deserializeStoryboard(withName: storyboardName)
                storyboardInstanceBindingMap[storyboardBindingIdentifier] = StoryboardInstanceBinding(fromStoryboardName: storyboardName, storyboardReferenceMap: storyboardReference)
            }
        }
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
        var mock: T? = nil
        do {
            mock = try Fleet.mockFor(classToMock)
        } catch let error as Fleet.MockError {
            FleetError(Fleet.StoryboardError.invalidMockType(error.description)).raise()
        }

        try bind(viewController: mock!, toIdentifier: identifier)
        return mock!
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
        var mock: T? = nil
        do {
            mock = try Fleet.mockFor(classToMock)
        } catch let error as Fleet.MockError {
            FleetError(Fleet.StoryboardError.invalidMockType(error.description)).raise()
        }

        try bind(viewController: mock!, toIdentifier: identifier, forReferencedStoryboardWithName: referencedStoryboardName)
        return mock!
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
        var mock: T? = nil
        do {
            mock = try Fleet.mockFor(classToMock)
        } catch let error as Fleet.MockError {
            FleetError(Fleet.StoryboardError.invalidMockType(error.description)).raise()
        }

        try bind(viewController: mock!, asInitialViewControllerForReferencedStoryboardWithName: name)
        return mock!
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
            FleetError(Fleet.StoryboardError.invalidViewControllerState(message)).raise()
        }
        try initializeStoryboardBindings()
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bind(viewController: viewController, toIdentifier: identifier)
            }
        }
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
            FleetError(Fleet.StoryboardError.invalidViewControllerState(message)).raise()
        }
        try initializeStoryboardBindings()
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bind(viewController: viewController, toIdentifier: identifier,
                                                   forReferencedStoryboardWithName:referencedStoryboardName)
            }
        }
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
            FleetError(Fleet.StoryboardError.invalidViewControllerState(message)).raise()
        }
        try initializeStoryboardBindings()
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bind(viewController: viewController, asInitialViewControllerForReferencedStoryboardWithName: referencedStoryboardName)
            }
        }
    }

    open override class func initialize() {
        if !didSwizzle {
            swizzleViewControllerInstantiationMethod()
            didSwizzle = true
        }
    }

    class func swizzleViewControllerInstantiationMethod() {
        let originalSelector = #selector(UIStoryboard.instantiateViewController(withIdentifier:))
        let swizzledSelector = #selector(UIStoryboard.fleet_instantiateViewController(withIdentifier:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_instantiateViewController(withIdentifier identifier: String) -> UIViewController {
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                if let boundInstance = storyboardInstanceBinding.viewController(forIdentifier: identifier) {
                    return boundInstance
                }
            }
        }

        let viewController = fleet_instantiateViewController(withIdentifier: identifier)
        return viewController
    }
}
