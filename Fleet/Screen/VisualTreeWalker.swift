import UIKit

class VisualTreeWalker {
    func findAllSubviews<T: UIView>(ofType subviewType: T.Type, inRootVisual rootVisual: UIView) -> [UIView] {
        var subviews = [UIView]()
        for subview in rootVisual.subviews {
            if let castedSubview = subview as? T {
                subviews.append(castedSubview)
            }

            subviews.append(contentsOf: findAllSubviews(ofType: subviewType, inRootVisual: subview))
        }

        return subviews
    }

    func findAllSubviews<T: UIView>(ofType subviewType: T.Type, inRootVisual rootVisual: UIView, conformingToBlock predicateBlock: (T) -> Bool) -> [UIView] {
        var subviews = [UIView]()
        for subview in rootVisual.subviews {
            if let castedSubview = subview as? T {
                if predicateBlock(castedSubview) {
                    subviews.append(castedSubview)
                }
            }

            subviews.append(contentsOf: findAllSubviews(ofType: subviewType, inRootVisual: subview, conformingToBlock: predicateBlock))
        }

        return subviews
    }
}
