import UIKit

/// An explicit set of window-scoped settings a test can apply to its hosted context.
///
/// Only settings UIKit exposes per window are offered: window size, appearance, and the Dynamic
/// Type size category. `nil` leaves a setting untouched. Process-wide settings (locale, language,
/// system accessibility switches) are deliberately not offered because they cannot be scoped to a
/// context or restored safely.
public struct FleetEnvironment: Equatable, Sendable {
    /// The window's size in points. The window's origin is preserved.
    public var size: CGSize?
    /// Applied as the window's `overrideUserInterfaceStyle`.
    public var userInterfaceStyle: UIUserInterfaceStyle?
    /// Applied as a trait override on the window. Requires iOS/tvOS 17; earlier runtimes throw
    /// a `FleetFailure` of kind `.invalidSetup` because no public per-window mechanism exists.
    public var contentSizeCategory: UIContentSizeCategory?
    /// Applied as a trait override on the window. Requires iOS/tvOS 17, like `contentSizeCategory`.
    /// `.unspecified` is not a valid override and throws `.invalidInput`.
    public var horizontalSizeClass: UIUserInterfaceSizeClass?
    /// Applied as a trait override on the window. Requires iOS/tvOS 17, like `contentSizeCategory`.
    /// `.unspecified` is not a valid override and throws `.invalidInput`.
    public var verticalSizeClass: UIUserInterfaceSizeClass?

    public init(
        size: CGSize? = nil,
        userInterfaceStyle: UIUserInterfaceStyle? = nil,
        contentSizeCategory: UIContentSizeCategory? = nil,
        horizontalSizeClass: UIUserInterfaceSizeClass? = nil,
        verticalSizeClass: UIUserInterfaceSizeClass? = nil
    ) {
        self.size = size
        self.userInterfaceStyle = userInterfaceStyle
        self.contentSizeCategory = contentSizeCategory
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
    }
}

/// What a context saved before applying an environment, so teardown can restore it.
struct SavedWindowEnvironment {
    var frame: CGRect?
    var style: UIUserInterfaceStyle?
    var categoryWasOverridden = false
    var category: UIContentSizeCategory?
    var touchedCategory = false
    var touchedHorizontal = false
    var horizontalWasOverridden = false
    var horizontal: UIUserInterfaceSizeClass?
    var touchedVertical = false
    var verticalWasOverridden = false
    var vertical: UIUserInterfaceSizeClass?

    @MainActor
    func restore(on window: UIWindow) {
        if let frame { window.frame = frame }
        if let style { window.overrideUserInterfaceStyle = style }
        if touchedCategory, #available(iOS 17, tvOS 17, *) {
            if categoryWasOverridden, let category {
                window.traitOverrides.preferredContentSizeCategory = category
            } else {
                window.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
            }
        }
        if touchedHorizontal, #available(iOS 17, tvOS 17, *) {
            if horizontalWasOverridden, let horizontal {
                window.traitOverrides.horizontalSizeClass = horizontal
            } else {
                window.traitOverrides.remove(UITraitHorizontalSizeClass.self)
            }
        }
        if touchedVertical, #available(iOS 17, tvOS 17, *) {
            if verticalWasOverridden, let vertical {
                window.traitOverrides.verticalSizeClass = vertical
            } else {
                window.traitOverrides.remove(UITraitVerticalSizeClass.self)
            }
        }
    }
}

extension FleetTestContext {
    /// Applies `environment` to this context's window, then waits (bounded) until layout and the
    /// window's trait collection reflect it. The previous values are restored when the scope ends,
    /// on every exit path. Later calls compose: only the fields they set change, and the values
    /// captured by the first call to touch a setting are the ones restored.
    public func configure(_ environment: FleetEnvironment, timeout: TimeInterval = 5) async throws {
        guard isActive else { throw Self.contextEnded }
        if environment.contentSizeCategory != nil
            || environment.horizontalSizeClass != nil || environment.verticalSizeClass != nil {
            guard #available(iOS 17, tvOS 17, *) else {
                throw FleetFailure(
                    kind: .invalidSetup,
                    action: "configure the content size category or size classes",
                    target: "FleetTestContext window",
                    state: "this runtime predates per-window trait overrides (iOS/tvOS 17).",
                    reason: "Run on iOS/tvOS 17 or later, or omit contentSizeCategory and the size classes."
                )
            }
        }
        for sizeClass in [environment.horizontalSizeClass, environment.verticalSizeClass] where sizeClass == .unspecified {
            throw FleetFailure(
                kind: .invalidInput,
                action: "configure a size class",
                target: "FleetTestContext window",
                state: "size class was unspecified.",
                reason: "Pass .compact or .regular, or omit the size class."
            )
        }
        if let size = environment.size {
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                throw FleetFailure(
                    kind: .invalidInput,
                    action: "configure the window size",
                    target: "FleetTestContext window",
                    state: "size was \(size).",
                    reason: "Pass a finite size greater than zero in each dimension."
                )
            }
            if savedEnvironment.frame == nil { savedEnvironment.frame = window.frame }
            window.frame = CGRect(origin: window.frame.origin, size: size)
        }
        if let style = environment.userInterfaceStyle {
            if savedEnvironment.style == nil { savedEnvironment.style = window.overrideUserInterfaceStyle }
            window.overrideUserInterfaceStyle = style
        }
        if let category = environment.contentSizeCategory, #available(iOS 17, tvOS 17, *) {
            if !savedEnvironment.touchedCategory {
                savedEnvironment.touchedCategory = true
                savedEnvironment.categoryWasOverridden = window.traitOverrides.contains(UITraitPreferredContentSizeCategory.self)
                // Reading an override that was never set asserts inside UIKit, so only read a present one.
                if savedEnvironment.categoryWasOverridden {
                    savedEnvironment.category = window.traitOverrides.preferredContentSizeCategory
                }
            }
            window.traitOverrides.preferredContentSizeCategory = category
        }
        if #available(iOS 17, tvOS 17, *) {
            if let horizontal = environment.horizontalSizeClass {
                if !savedEnvironment.touchedHorizontal {
                    savedEnvironment.touchedHorizontal = true
                    savedEnvironment.horizontalWasOverridden = window.traitOverrides.contains(UITraitHorizontalSizeClass.self)
                    if savedEnvironment.horizontalWasOverridden {
                        savedEnvironment.horizontal = window.traitOverrides.horizontalSizeClass
                    }
                }
                window.traitOverrides.horizontalSizeClass = horizontal
            }
            if let vertical = environment.verticalSizeClass {
                if !savedEnvironment.touchedVertical {
                    savedEnvironment.touchedVertical = true
                    savedEnvironment.verticalWasOverridden = window.traitOverrides.contains(UITraitVerticalSizeClass.self)
                    if savedEnvironment.verticalWasOverridden {
                        savedEnvironment.vertical = window.traitOverrides.verticalSizeClass
                    }
                }
                window.traitOverrides.verticalSizeClass = vertical
            }
        }
        window.layoutIfNeeded()
        try await waitUntil("window environment to take effect", timeout: timeout) {
            if let size = environment.size, self.window.bounds.size != size { return false }
            if let style = environment.userInterfaceStyle, style != .unspecified,
               self.window.traitCollection.userInterfaceStyle != style { return false }
            if let category = environment.contentSizeCategory,
               self.window.traitCollection.preferredContentSizeCategory != category { return false }
            if let h = environment.horizontalSizeClass, self.window.traitCollection.horizontalSizeClass != h { return false }
            if let v = environment.verticalSizeClass, self.window.traitCollection.verticalSizeClass != v { return false }
            return true
        }
    }

    /// The window's current size, resolved appearance, Dynamic Type category and size classes.
    public var currentEnvironment: FleetEnvironment {
        FleetEnvironment(
            size: window.bounds.size,
            userInterfaceStyle: window.traitCollection.userInterfaceStyle,
            contentSizeCategory: window.traitCollection.preferredContentSizeCategory,
            horizontalSizeClass: window.traitCollection.horizontalSizeClass,
            verticalSizeClass: window.traitCollection.verticalSizeClass
        )
    }
}
