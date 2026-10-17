//
//  AppFont.swift
//  Background Removal
//

import UIKit

enum FigtreeWeight: String {
    case black = "Figtree-Black"
    case blackItalic = "Figtree-BlackItalic"
    case bold = "Figtree-Bold"
    case boldItalic = "Figtree-BoldItalic"
    case extraBold = "Figtree-ExtraBold"
    case extraBoldItalic = "Figtree-ExtraBoldItalic"
    case italic = "Figtree-Italic"
    case light = "Figtree-Light"
    case lightItalic = "Figtree-LightItalic"
    case medium = "Figtree-Medium"
    case mediumItalic = "Figtree-MediumItalic"
    case regular = "Figtree-Regular"
    case semiBold = "Figtree-SemiBold"
    case semiBoldItalic = "Figtree-SemiBoldItalic"
}

extension UIFont {
    static func figtree(_ weight: FigtreeWeight, size: CGFloat) -> UIFont {
        guard let font = UIFont(name: weight.rawValue, size: size) else {
            assertionFailure("Figtree font not found: \(weight.rawValue)")
            return UIFont.systemFont(ofSize: size)
        }
        return font
    }
}
