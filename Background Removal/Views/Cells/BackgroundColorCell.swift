//
//  BackgroundColorCell.swift
//  Background Removal
//
//  Round colour swatch with a selection ring ("None" shows a checkerboard, "Custom" a plus).
//

import UIKit

class BackgroundColorCell: UICollectionViewCell {

    @IBOutlet weak var vwRing: UIView!
    @IBOutlet weak var vwSwatch: UIView!
    @IBOutlet weak var imgPattern: UIImageView!
    @IBOutlet weak var imgIcon: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        vwRing.backgroundColor = .clear
        vwRing.layer.borderWidth = 2.5
        vwSwatch.clipsToBounds = true
        vwSwatch.layer.borderWidth = 1
        imgIcon.tintColor = UIColor(named: "PrimaryText")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        vwRing.layer.cornerRadius = vwRing.bounds.height / 2
        vwSwatch.layer.cornerRadius = vwSwatch.bounds.height / 2
    }

    func configure(option: BackgroundColorOption, customColor: UIColor?, selected: Bool) {
        imgPattern.backgroundColor = nil
        imgIcon.isHidden = true
        switch option {
        case .transparent:
            imgPattern.backgroundColor = UIColor(patternImage: CheckerboardView.pattern(cell: 6, dark: false))
            vwSwatch.backgroundColor = .white
        case .custom:
            if let customColor {
                vwSwatch.backgroundColor = customColor
            } else {
                vwSwatch.backgroundColor = UIColor(named: "Surface Color")
                imgIcon.isHidden = false
                imgIcon.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
            }
        default:
            vwSwatch.backgroundColor = UIColor(hexRGB: option.hex ?? "FFFFFF")
        }
        vwSwatch.layer.borderColor = UIColor(red: 0.72, green: 0.79, blue: 0.87, alpha: 1).cgColor
        vwRing.layer.borderColor = (UIColor(named: "AccentColor") ?? .systemBlue).cgColor
        vwRing.isHidden = !selected
        isAccessibilityElement = true
        accessibilityLabel = option.title
        accessibilityTraits = selected ? [.button, .selected] : .button
    }
}
