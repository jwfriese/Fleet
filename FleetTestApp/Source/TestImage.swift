import Foundation
import UIKit.UIImage

func DrawTestImage(color: UIColor) -> UIImage {
    let rect = CGRect(x: 0, y: 0, width: 800, height: 800)
    UIGraphicsBeginImageContextWithOptions(CGSize(width: 800, height: 800), false, 0)
    color.setFill()
    UIRectFill(rect)
    let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return image
}

func DrawTestImageWithRandomColor() -> UIImage {
    let colors = [
        UIColor.black,
        UIColor.blue,
        UIColor.green,
        UIColor.gray,
        UIColor.systemPink,
        UIColor.purple,
        UIColor.red,
    ]
    return DrawTestImage(color: colors.randomElement()!)
}
