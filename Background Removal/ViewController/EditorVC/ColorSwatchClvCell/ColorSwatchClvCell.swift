//
//  ColorSwatchClvCell.swift
//  Background Removal
//
//  Round swatch used for background colours, text colours and background photos.
//

import UIKit

enum SwatchItem {
    case transparent
    case color(UIColor)
    case custom(UIColor?)
    case photo(UIImage)
}

class ColorSwatchClvCell: UICollectionViewCell {

    @IBOutlet weak var vwRing: UIView!
    @IBOutlet weak var vwFill: UIView!
    @IBOutlet weak var imgSwatch: UIImageView!
    @IBOutlet weak var imgIcon: UIImageView!

    private var outlined = false

    override func awakeFromNib() {
        super.awakeFromNib()
        vwRing.layer.borderWidth = 2.5
        vwRing.backgroundColor = .clear
        vwFill.clipsToBounds = true
        imgIcon.tintColor = UIColor(named: "PrimaryText")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        vwRing.layer.cornerRadius = vwRing.bounds.height / 2
        vwFill.layer.cornerRadius = vwFill.bounds.height / 2
    }

    func setData(_ item: SwatchItem, selected: Bool) {
        imgSwatch.image = nil
        imgIcon.isHidden = true
        vwFill.backgroundColor = .clear
        outlined = false
        switch item {
        case .transparent:
            imgSwatch.image = CheckerboardView.pattern(cell: 9.4, traits: traitCollection)
            imgSwatch.contentMode = .scaleAspectFill
            outlined = true
            accessibilityLabel = "Transparent"
        case .color(let color):
            vwFill.backgroundColor = color
            outlined = color.isEqual(UIColor.white)
            accessibilityLabel = "Color"
        case .custom(let color):
            if let color {
                vwFill.backgroundColor = color
            } else {
                vwFill.backgroundColor = UIColor(named: "Surface Color")
                imgIcon.isHidden = false
                imgIcon.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
            }
            outlined = true
            accessibilityLabel = "Custom color"
        case .photo(let image):
            imgSwatch.image = image
            imgSwatch.contentMode = .scaleAspectFill
            accessibilityLabel = "Background photo"
        }
        vwRing.isHidden = !selected
        updateColors()
        isAccessibilityElement = true
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    private func updateColors() {
        vwRing.layer.borderColor = (UIColor(named: "AccentColor") ?? .systemBlue).cgColor
        vwFill.layer.borderWidth = outlined ? 1 : 0
        vwFill.layer.borderColor = EditorSwatches.hex(0xB7C9DE).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }
}
